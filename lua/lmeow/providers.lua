local M = {}
local curl = require("plenary.curl")
local config = require("lmeow")

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

function M.call_provider(provider_name, provider_config, selected_text, prompt, callback)
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
  local full_prompt = combined_system_prompt .. "\n\nTASK: " .. prompt .. "\n\nIMPORTANT: Preserve ALL existing content and structure. Only modify what's necessary to complete the task. Keep all text, HTML tags, and formatting that are not directly related to the requested change.\n\nCONTENT TO MODIFY:\n" .. selected_text .. "\n\nMODIFIED CONTENT:"
  
  if provider_name == "openai" then
    M.call_openai(provider_config, full_prompt, callback)
  elseif provider_name == "claude" then
    M.call_claude(provider_config, full_prompt, callback)
  elseif provider_name == "openrouter" then
    M.call_openrouter(provider_config, full_prompt, callback)
  elseif provider_name == "grok" then
    M.call_grok(provider_config, full_prompt, callback)
  elseif provider_name == "gemini" then
    M.call_gemini(provider_config, full_prompt, callback)
  else
    callback(nil, "Unsupported provider: " .. provider_name)
  end
end

function M.call_openai(config, prompt, callback)
  local payload = vim.json.encode({
    model = config.model,
    messages = {
      { role = "system", content = prompt }
    },
    max_tokens = config.max_tokens,
    temperature = config.temperature
  })
  
  curl.post(config.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. config.api_key
    },
    body = payload,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("OpenAI", response.body))
        return
      end
      
      local success, data = pcall(vim.json.decode, response.body)
      if not success then
        callback(nil, "Failed to parse OpenAI response")
        return
      end
      
      local content = data.choices[1].message.content
      callback(content, nil)
    end
  })
end

function M.call_claude(config, prompt, callback)
  local payload = vim.json.encode({
    model = config.model,
    max_tokens = config.max_tokens,
    temperature = config.temperature,
    messages = {
      { role = "user", content = prompt }
    }
  })
  
  curl.post(config.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = config.api_key,
      ["anthropic-version"] = "2023-06-01"
    },
    body = payload,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Claude", response.body))
        return
      end
      
      local success, data = pcall(vim.json.decode, response.body)
      if not success then
        callback(nil, "Failed to parse Claude response")
        return
      end
      
      local content = data.content[1].text
      callback(content, nil)
    end
  })
end

function M.call_openrouter(config, prompt, callback)
  local payload = vim.json.encode({
    model = config.model,
    messages = {
      { role = "system", content = prompt }
    },
    max_tokens = config.max_tokens,
    temperature = config.temperature
  })
  
  curl.post(config.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. config.api_key,
      ["HTTP-Referer"] = "https://github.com/polizia/lmeow.nvim",
      ["X-Title"] = "lmeow.nvim"
    },
    body = payload,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("OpenRouter", response.body))
        return
      end
      
      local success, data = pcall(vim.json.decode, response.body)
      if not success then
        callback(nil, "Failed to parse OpenRouter response")
        return
      end
      
      local content = data.choices[1].message.content
      callback(content, nil)
    end
  })
end

function M.call_grok(config, prompt, callback)
  local payload = vim.json.encode({
    model = config.model,
    messages = {
      { role = "system", content = prompt }
    },
    max_tokens = config.max_tokens,
    temperature = config.temperature
  })
  
  curl.post(config.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. config.api_key
    },
    body = payload,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Grok", response.body))
        return
      end
      
      local success, data = pcall(vim.json.decode, response.body)
      if not success then
        callback(nil, "Failed to parse Grok response")
        return
      end
      
      local content = data.choices[1].message.content
      callback(content, nil)
    end
  })
end

function M.call_gemini(config, prompt, callback)
  local gemini_url = config.base_url .. config.model .. ":generateContent?key=" .. config.api_key
  
  -- Clean and truncate prompt if it's too long
  local clean_prompt = prompt:gsub("^%s+", ""):gsub("%s+$", "")
  if #clean_prompt > 30000 then
    clean_prompt = clean_prompt:sub(1, 30000) .. "...[truncated]"
  end
  
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
      maxOutputTokens = math.min(config.max_tokens, 8192),
      temperature = config.temperature,
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
  
  curl.post(gemini_url, {
    headers = {
      ["Content-Type"] = "application/json"
    },
    body = payload,
    callback = function(response)
      if response.status ~= 200 then
        callback(nil, M.parse_api_error("Gemini", response.body))
        return
      end
      
      local success, data = pcall(vim.json.decode, response.body)
      if not success then
        callback(nil, "Failed to parse Gemini response: " .. tostring(response.body))
        return
      end
      
      -- Debug: Commented out now that it's working
      -- vim.schedule(function()
      --   vim.notify("Gemini response structure: " .. vim.inspect(data), vim.log.levels.DEBUG)
      -- end)
      
      -- More robust response parsing
      if not data.candidates or not data.candidates[1] then
        callback(nil, "Gemini response: No candidates found")
        return
      end
      
      if not data.candidates[1].content then
        callback(nil, "Gemini response: No content found")
        return
      end
      
      if not data.candidates[1].content.parts or not data.candidates[1].content.parts[1] then
        -- Sometimes Gemini might return blocked content or other issues
        if data.candidates[1].content.parts and #data.candidates[1].content.parts == 0 then
          callback(nil, "Gemini response: Empty parts (possibly blocked content)")
          return
        end
        callback(nil, "Gemini response: No parts found")
        return
      end
      
      local content = data.candidates[1].content.parts[1].text
      if not content then
        callback(nil, "Gemini response: No text content found")
        return
      end
      
      callback(content, nil)
    end
  })
end

return M