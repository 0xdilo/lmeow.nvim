local M = {}
local curl = require("plenary.curl")
local config = require("lmeow")

local function debug_log(...)
  if config.debug_mode then
    print(...)
  end
end

local function merge(t1, t2)
  local res = {}
  for k, v in pairs(t1) do res[k] = v end
  for k, v in pairs(t2) do res[k] = v end
  return res
end

function M.parse_api_error(provider_name, response_body)
  local success, data = pcall(vim.json.decode, response_body)
  if not success or not data.error then
    return provider_name .. " API request failed"
  end

  local error_msg = data.error.message or "Unknown error"

  -- Handle specific error types
  if data.error.type == "invalid_request_error" then
    if error_msg:match("API key") then
      local env_var_map = {
        openai = "OPENAI_API_KEY",
        claude = "ANTHROPIC_API_KEY",
        openrouter = "OPENROUTER_API_KEY",
        grok = "XAI_API_KEY",
        gemini = "GEMINI_API_KEY"
      }
      local env_var = env_var_map[provider_name] or "API_KEY"
      return "Invalid API key for " .. provider_name .. ". Please check your " .. env_var .. " environment variable."
    end
  elseif data.error.type == "rate_limit_error" then
    return "Rate limit exceeded for " .. provider_name .. ". Please try again later."
  elseif data.error.type == "insufficient_quota" then
    return "Insufficient quota for " .. provider_name .. ". Please check your billing."
  end

  return provider_name .. " API error: " .. error_msg
end

function M.call_provider(provider_name, provider_config, maybe_model_config, maybe_selected_text, maybe_prompt,
                         maybe_callback)
  -- Support both old and new signatures:
  -- New: call_provider(name, provider_cfg, model_cfg, selected_text, prompt, cb)
  -- Old: call_provider(name, merged_cfg, selected_text, prompt, cb)
  local model_config, selected_text, prompt, callback
  if type(maybe_model_config) == "table" or maybe_model_config == nil then
    model_config = maybe_model_config
    selected_text = maybe_selected_text
    prompt = maybe_prompt
    callback = maybe_callback
  else
    -- Shift args for old signature where third param is actually selected_text
    model_config = nil
    selected_text = maybe_model_config
    prompt = maybe_selected_text
    callback = maybe_prompt
  end

  -- Use the provided configuration; params must be provided separately in config
  local final_config = provider_config or {}

  -- Build the complete system prompt by combining default with user custom prompt
  local system_prompt_parts = {}

  -- Add the base system prompt
  table.insert(system_prompt_parts, config.config.system_prompt)

  -- Add user custom system prompt if provided
  if config.config.custom_system_prompt and config.config.custom_system_prompt ~= "" then
    table.insert(system_prompt_parts, config.config.custom_system_prompt)
  end

  -- Join all system prompt parts
  local combined_system_prompt = table.concat(system_prompt_parts, "\n\n")

  -- Build the full prompt
  local full_prompt = combined_system_prompt ..
      "\n\nTASK: " ..
      prompt ..
      "\n\nIMPORTANT: Preserve ALL existing content and structure. Only modify what's necessary to complete the task. Keep all text, HTML tags, and formatting that are not directly related to the requested change.\n\nCONTENT TO MODIFY:\n" ..
      selected_text .. "\n\nMODIFIED CONTENT:"

  -- Minimal validation to ensure required params exist
  if not final_config or not final_config.base_url then
    callback(nil, (provider_name or "provider") .. " configuration missing base_url")
    return
  end
  if not final_config.api_key and provider_name ~= "gemini" then
    -- Gemini uses key in URL; still required but handled per provider
    callback(nil, (provider_name or "provider") .. " API key not set")
    return
  end
  if provider_name == "gemini" and (not final_config.api_key or not final_config.model) then
    callback(nil, "Gemini configuration requires api_key and model")
    return
  end

  if provider_name == "openai" then
    M.call_openai(final_config, full_prompt, callback)
  elseif provider_name == "claude" then
    M.call_claude(final_config, full_prompt, callback)
  elseif provider_name == "openrouter" then
    M.call_openrouter(final_config, full_prompt, callback)
  elseif provider_name == "grok" then
    M.call_grok(final_config, full_prompt, callback)
  elseif provider_name == "gemini" then
    M.call_gemini(final_config, full_prompt, callback)
  else
    callback(nil, "Unsupported provider: " .. tostring(provider_name))
  end
end

function M.call_openai(modelConfig, prompt, callback)
  local params = modelConfig.params or {}
  local payload = vim.json.encode(merge(params, {
    model = modelConfig.model,
    messages = {
      { role = "system", content = prompt }
    },
    stream = true
  }))

  local accumulated_content = ""
  local chunk_count = 0
  local start_time = vim.uv.hrtime()
  debug_log("OpenAI: Starting streaming request")
  
  curl.post(modelConfig.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. modelConfig.api_key
    },
    body = payload,
    stream = function(err, chunk)
      if err then
        callback(nil, "OpenAI stream error: " .. tostring(err))
        return
      end
      
      if chunk then
        local lines = vim.split(chunk, "\n")
        for _, line in ipairs(lines) do
          if line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: " prefix
            if json_str ~= "[DONE]" then
              local success, data = pcall(vim.json.decode, json_str)
              if success and data.choices and data.choices[1] then
                local choice = data.choices[1]
                
                -- Handle content chunks
                if choice.delta and choice.delta.content then
                  local content_chunk = choice.delta.content
                  accumulated_content = accumulated_content .. content_chunk
                  chunk_count = chunk_count + 1
                  local time_since_start = (vim.uv.hrtime() - start_time) / 1000000
                  debug_log(string.format("OpenAI CHUNK %d: +%d chars, total=%d, api_time=%.1fms", chunk_count, #content_chunk, #accumulated_content, time_since_start))
                  callback(accumulated_content, nil, false) -- false means not finished
                end
                
                -- Handle completion
                if choice.finish_reason and choice.finish_reason ~= vim.NIL then
                  debug_log(string.format("OpenAI DONE: %d chunks, final length=%d, reason=%s", chunk_count, #accumulated_content, choice.finish_reason))
                  callback(accumulated_content, nil, true) -- true means finished
                end
              end
            else
              debug_log(string.format("OpenAI DONE: %d chunks, final length=%d", chunk_count, #accumulated_content))
              callback(accumulated_content, nil, true) -- true means finished
            end
          end
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("OpenAI", response.body))
        return
      end
      -- Stream callback handles the response, so this might not be called
      if accumulated_content == "" then
        callback(nil, "No content received from OpenAI")
      end
    end
  })
end

function M.call_claude(modelConfig, prompt, callback)
  local params = modelConfig.params or {}
  
  -- Ensure max_tokens is set (required by Claude)
  if not params.max_tokens then
    params.max_tokens = 4096
  end
  
  local payload = vim.json.encode(merge(params, {
    model = modelConfig.model,
    messages = {
      { role = "user", content = prompt }
    },
    stream = true
  }))

  local accumulated_content = ""
  local chunk_count = 0
  local start_time = vim.uv.hrtime()
  debug_log("Claude: Starting streaming request with model: " .. (modelConfig.model or "unknown"))
  
  curl.post(modelConfig.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = modelConfig.api_key,
      ["anthropic-version"] = "2023-06-01"
    },
    body = payload,
    stream = function(err, chunk)
      if err then
        callback(nil, "Claude stream error: " .. tostring(err))
        return
      end
      
      if chunk then
        local lines = vim.split(chunk, "\n")
        local current_event = nil
        
        for _, line in ipairs(lines) do
          if line:match("^event: ") then
            current_event = line:sub(8) -- Remove "event: " prefix
          elseif line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: " prefix
            if json_str ~= "" and json_str ~= "[DONE]" then
              local success, data = pcall(vim.json.decode, json_str)
              if success then
                if data.type == "content_block_delta" and data.delta and data.delta.type == "text_delta" and data.delta.text then
                  local content_chunk = data.delta.text
                  accumulated_content = accumulated_content .. content_chunk
                  chunk_count = chunk_count + 1
                  local time_since_start = (vim.uv.hrtime() - start_time) / 1000000
                  debug_log(string.format("Claude CHUNK %d: +%d chars, total=%d, api_time=%.1fms", chunk_count, #content_chunk, #accumulated_content, time_since_start))
                  callback(accumulated_content, nil, false) -- false means not finished
                elseif data.type == "message_stop" then
                  debug_log(string.format("Claude DONE: %d chunks, final length=%d", chunk_count, #accumulated_content))
                  callback(accumulated_content, nil, true) -- true means finished
                end
              end
            end
          end
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Claude", response.body))
        return
      end
      -- Stream callback handles the response, so this might not be called
      if accumulated_content == "" then
        callback(nil, "No content received from Claude")
      end
    end
  })
end

function M.call_openrouter(modelConfig, prompt, callback)
  local params = modelConfig.params or {}
  local payload = vim.json.encode(merge(params, {
    model = modelConfig.model,
    messages = {
      { role = "system", content = prompt }
    },
    stream = true
  }))

  local accumulated_content = ""
  local chunk_count = 0
  local start_time = vim.uv.hrtime()
  debug_log("OpenRouter: Starting streaming request")
  
  curl.post(modelConfig.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. modelConfig.api_key,
      ["HTTP-Referer"] = "https://github.com/polizia/lmeow.nvim",
      ["X-Title"] = "lmeow.nvim"
    },
    body = payload,
    stream = function(err, chunk)
      if err then
        callback(nil, "OpenRouter stream error: " .. tostring(err))
        return
      end
      
      if chunk then
        local lines = vim.split(chunk, "\n")
        for _, line in ipairs(lines) do
          -- Handle OpenRouter SSE comments (ignore them)
          if line:match("^: ") then
            debug_log("OpenRouter: Received SSE comment: " .. line)
          elseif line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: " prefix
            if json_str ~= "[DONE]" then
              local success, data = pcall(vim.json.decode, json_str)
              if success and data.choices and data.choices[1] then
                local choice = data.choices[1]
                
                -- Check for mid-stream errors
                if data.error then
                  debug_log("OpenRouter: Mid-stream error: " .. vim.inspect(data.error))
                  callback(nil, "OpenRouter API error: " .. (data.error.message or "Unknown error"))
                  return
                end
                
                -- Handle content chunks
                if choice.delta and choice.delta.content then
                  local content_chunk = choice.delta.content
                  accumulated_content = accumulated_content .. content_chunk
                  chunk_count = chunk_count + 1
                  local time_since_start = (vim.uv.hrtime() - start_time) / 1000000
                  debug_log(string.format("OpenRouter CHUNK %d: +%d chars, total=%d, api_time=%.1fms", chunk_count, #content_chunk, #accumulated_content, time_since_start))
                  callback(accumulated_content, nil, false) -- false means not finished
                end
                
                -- Handle completion
                if choice.finish_reason and choice.finish_reason ~= vim.NIL then
                  debug_log(string.format("OpenRouter DONE: %d chunks, final length=%d, reason=%s", chunk_count, #accumulated_content, choice.finish_reason))
                  callback(accumulated_content, nil, true) -- true means finished
                  
                  -- Handle error finish reason
                  if choice.finish_reason == "error" then
                    callback(nil, "OpenRouter: Stream terminated due to error")
                    return
                  end
                end
              end
            else
              debug_log(string.format("OpenRouter DONE: %d chunks, final length=%d", chunk_count, #accumulated_content))
              callback(accumulated_content, nil, true) -- true means finished
            end
          end
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("OpenRouter", response.body))
        return
      end
      -- Stream callback handles the response, so this might not be called
      if accumulated_content == "" then
        callback(nil, "No content received from OpenRouter")
      end
    end
  })
end

function M.call_grok(modelConfig, prompt, callback)
  local params = modelConfig.params or {}
  local payload = vim.json.encode(merge(params, {
    model = modelConfig.model,
    messages = {
      { role = "system", content = prompt }
    },
    stream = true
  }))

  local accumulated_content = ""
  local chunk_count = 0
  local start_time = vim.uv.hrtime()
  debug_log("Grok: Starting streaming request")
  
  curl.post(modelConfig.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. modelConfig.api_key
    },
    body = payload,
    stream = function(err, chunk)
      if err then
        callback(nil, "Grok stream error: " .. tostring(err))
        return
      end
      
      if chunk then
        local lines = vim.split(chunk, "\n")
        for _, line in ipairs(lines) do
          if line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: " prefix
            if json_str ~= "[DONE]" then
              local success, data = pcall(vim.json.decode, json_str)
              if success and data.choices and data.choices[1] then
                local choice = data.choices[1]
                
                -- Handle content chunks
                if choice.delta and choice.delta.content then
                  local content_chunk = choice.delta.content
                  accumulated_content = accumulated_content .. content_chunk
                  chunk_count = chunk_count + 1
                  local time_since_start = (vim.uv.hrtime() - start_time) / 1000000
                  debug_log(string.format("Grok CHUNK %d: +%d chars, total=%d, api_time=%.1fms", chunk_count, #content_chunk, #accumulated_content, time_since_start))
                  callback(accumulated_content, nil, false) -- false means not finished
                end
                
                -- Handle completion
                if choice.finish_reason and choice.finish_reason ~= vim.NIL then
                  debug_log(string.format("Grok DONE: %d chunks, final length=%d, reason=%s", chunk_count, #accumulated_content, choice.finish_reason))
                  callback(accumulated_content, nil, true) -- true means finished
                end
              end
            else
              debug_log(string.format("Grok DONE: %d chunks, final length=%d", chunk_count, #accumulated_content))
              callback(accumulated_content, nil, true) -- true means finished
            end
          end
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Grok", response.body))
        return
      end
      -- Stream callback handles the response, so this might not be called
      if accumulated_content == "" then
        callback(nil, "No content received from Grok")
      end
    end
  })
end

function M.call_gemini(modelConfig, prompt, callback)
  local gemini_url = modelConfig.base_url .. modelConfig.model .. ":streamGenerateContent?alt=sse&key=" .. modelConfig.api_key

  -- Clean and truncate prompt if it's too long
  local clean_prompt = prompt:gsub("^%s+", ""):gsub("%s+$", "")
  if #clean_prompt > 30000 then
    clean_prompt = clean_prompt:sub(1, 30000) .. "...[truncated]"
  end

  local p = modelConfig.params or {}
  local payload = vim.json.encode({
    contents = {
      {
        role = "user",
        parts = {
          { text = clean_prompt }
        }
      }
    },
    generationConfig = {
      maxOutputTokens = p.max_tokens or 2000,
      temperature = p.temperature,
      topK = 40,
      topP = 0.95
    },
    safetySettings = {
      {
        category = "HARM_CATEGORY_HARASSMENT",
        threshold = "BLOCK_NONE"
      },
      {
        category = "HARM_CATEGORY_HATE_SPEECH",
        threshold = "BLOCK_NONE"
      },
      {
        category = "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        threshold = "BLOCK_NONE"
      },
      {
        category = "HARM_CATEGORY_DANGEROUS_CONTENT",
        threshold = "BLOCK_NONE"
      }
    }
  })

  local accumulated_content = ""
  local chunk_count = 0
  local start_time = vim.uv.hrtime()
  debug_log("Gemini: Starting streaming request")
  
  curl.post(gemini_url, {
    headers = {
      ["Content-Type"] = "application/json"
    },
    body = payload,
    stream = function(err, chunk)
      if err then
        callback(nil, "Gemini stream error: " .. tostring(err))
        return
      end
      
      if chunk then
        local lines = vim.split(chunk, "\n")
        for _, line in ipairs(lines) do
          if line:match("^data: ") then
            local json_str = line:sub(7) -- Remove "data: " prefix
            if json_str ~= "" and json_str ~= "[DONE]" then
              local success, data = pcall(vim.json.decode, json_str)
              if success and data.candidates and data.candidates[1] then
                if data.candidates[1].content and data.candidates[1].content.parts and data.candidates[1].content.parts[1] then
                  local chunk_content = data.candidates[1].content.parts[1].text
                  if chunk_content then
                    -- Gemini sends delta chunks, we need to accumulate them
                    accumulated_content = accumulated_content .. chunk_content
                    chunk_count = chunk_count + 1
                    local time_since_start = (vim.uv.hrtime() - start_time) / 1000000
                    debug_log(string.format("Gemini CHUNK %d: +%d chars, total=%d, api_time=%.1fms", chunk_count, #chunk_content, #accumulated_content, time_since_start))
                    callback(accumulated_content, nil, false) -- false means not finished
                  end
                end
                
                -- Check if this is the final chunk (Gemini typically has finishReason)
                if data.candidates[1].finishReason then
                  debug_log(string.format("Gemini DONE: %d chunks, final length=%d, reason=%s", chunk_count, #accumulated_content, data.candidates[1].finishReason))
                  callback(accumulated_content, nil, true) -- true means finished
                end
              end
            end
          end
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Gemini", response.body))
        return
      end
      -- Stream callback handles the response, so this might not be called for successful streaming
    end
  })
end

return M
