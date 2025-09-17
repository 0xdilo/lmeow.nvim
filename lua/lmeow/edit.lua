local M = {}
local config = require("lmeow")

function M.edit_selection_with_range(start_line, end_line)
  -- Normalize line range (ensure start_line <= end_line)
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  
  -- Validate selection
  if start_line == 0 or end_line == 0 then
    vim.notify("No valid selection found. Please select text first.", vim.log.levels.WARN)
    return
  end
  
  -- Get the actual selected text
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  -- Handle case where buffer might be empty or new
  if not lines or #lines == 0 then
    vim.notify("No content selected. Please select text first.", vim.log.levels.WARN)
    return
  end
  
  local selected_text = table.concat(lines, "\n")
  
  -- Final validation
  if selected_text == "" or #selected_text:gsub("%s", "") == 0 then
    vim.notify("No text selected. Please select some text to edit.", vim.log.levels.WARN)
    return
  end
  
  M.show_prompt_popup(selected_text, start_line - 1, 0, end_line - 1, -1)
end

function M.edit_selection()
  -- Force update of visual marks (fix for new/unsaved files)
  vim.cmd('normal! `<')
  vim.cmd('normal! `>')
  
  -- Get visual selection ranges
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  
  -- Validate selection
  if start_line == 0 or end_line == 0 then
    vim.notify("No valid selection found. Please select text first.", vim.log.levels.WARN)
    return
  end
  
  -- Get the actual selected text
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  -- Handle case where buffer might be empty or new
  if not lines or #lines == 0 then
    vim.notify("No content selected. Please select text first.", vim.log.levels.WARN)
    return
  end
  
  local selected_text = table.concat(lines, "\n")
  
  -- If we get the last line, we need to handle partial selection
  if end_line > start_line then
    local last_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
    if last_line_content then
      local end_col = vim.fn.col("'>")
      if end_col < #last_line_content then
        lines[#lines] = last_line_content:sub(1, end_col)
      end
    end
  end
  
  selected_text = table.concat(lines, "\n")
  
  -- Final validation
  if selected_text == "" or #selected_text:gsub("%s", "") == 0 then
    vim.notify("No text selected. Please select some text to edit.", vim.log.levels.WARN)
    return
  end
  
  M.show_prompt_popup(selected_text, start_line - 1, 0, end_line - 1, -1)
end

function M.show_prompt_popup(selected_text, start_line, start_col, end_line, end_col)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "lmeow")
  
  local width = 60
  local height = 3
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " AI Prompt ",
    title_pos = "center",
  })
  
  vim.api.nvim_win_set_option(win, "winhl", "Normal:LmeowPopup,FloatBorder:LmeowBorder")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Enter your prompt:", "" })
  
  vim.keymap.set("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local prompt = lines[2] or ""
    
    vim.api.nvim_win_close(win, true)
    
    if prompt ~= "" then
      M.process_ai_request(selected_text, prompt, start_line, start_col, end_line, end_col)
    end
  end, { buffer = buf })
  
  vim.keymap.set("i", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
  vim.cmd("startinsert")
end

function M.process_ai_request(selected_text, prompt, start_line, start_col, end_line, end_col)
  local current_model_name = config.get_current_model()
  local model_config = config.get_model_config(current_model_name)
  
  if not model_config then
    vim.schedule(function()
      vim.notify("Invalid model configuration", vim.log.levels.ERROR)
    end)
    return
  end
  
  if not model_config.api_key then
    vim.schedule(function()
      local env_var = model_config.env_var or "API_KEY"
      local provider_name = model_config.provider:gsub("^%l", string.upper)
      vim.notify("API key not set for " .. model_config.name .. ". Please set the " .. env_var .. " environment variable.", vim.log.levels.ERROR)
    end)
    return
  end
  
  -- Start animated loading indicator
  local loading_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local loading_frame_index = 1
  local loading_active = true
  local loading_timer = nil
  
  local function update_loading()
    if loading_active then
      vim.schedule(function()
        local frame = loading_frames[loading_frame_index]
        vim.notify(frame .. " Processing AI request with " .. model_config.name, vim.log.levels.INFO)
        loading_frame_index = loading_frame_index + 1
        if loading_frame_index > #loading_frames then
          loading_frame_index = 1
        end
      end)
    end
  end
  
  -- Start the loading animation (update every 100ms)
  loading_timer = vim.loop.new_timer()
  loading_timer:start(0, 100, update_loading)
  
  local first_chunk = true
  local chunk_count = 0
  local current_end_line = end_line  -- Track the dynamic end line
  local start_time = vim.uv.hrtime()  -- High resolution timer
  local first_chunk_time = nil
  local last_chunk_time = start_time
  
  if config.debug_mode then
    print(string.format("REQUEST START: %s at %.3fms", model_config.name, 0))
  end
  
  local providers = require("lmeow.providers")
  providers.call_provider(model_config.provider, model_config, selected_text, prompt, function(response, error, is_finished)
    vim.schedule(function()
      if error then
        -- Stop loading animation on error
        loading_active = false
        if loading_timer and not loading_timer:is_closing() then
          loading_timer:stop()
          loading_timer:close()
          loading_timer = nil
        end
        vim.notify("AI request failed: " .. error, vim.log.levels.ERROR)
        return
      end
      
      chunk_count = chunk_count + 1
      local current_time = vim.uv.hrtime()
      local time_since_start = (current_time - start_time) / 1000000  -- Convert to milliseconds
      
      -- Track timing for first chunk (time to first byte)
      if first_chunk then
        first_chunk_time = current_time
        -- Stop loading animation and show streaming message
        loading_active = false
        if loading_timer and not loading_timer:is_closing() then
          loading_timer:stop()
          loading_timer:close()
          loading_timer = nil
        end
        if not is_finished then
          vim.notify("AI streaming response...", vim.log.levels.INFO)
        end
        first_chunk = false
      end
      
      -- Calculate time since last chunk
      local time_since_last = (current_time - last_chunk_time) / 1000000
      last_chunk_time = current_time
      
      -- Debug: Print chunk info with timing
      if config.debug_mode then
        print(string.format("CHUNK %d: length=%d, finished=%s, range=%d-%d, time=%.1fms (+%.1fms)", 
          chunk_count, response and #response or 0, tostring(is_finished), start_line, current_end_line, time_since_start, time_since_last))
      end
      
      -- Update the text in real-time for all chunks (streaming and final)
      current_end_line = M.replace_code_dynamic(response, start_line, start_col, current_end_line, end_col)
      
      -- Show completion message when streaming is finished
      if is_finished then
        -- Make sure loading animation is stopped
        loading_active = false
        if loading_timer and not loading_timer:is_closing() then
          loading_timer:stop()
          loading_timer:close()
          loading_timer = nil
        end
        vim.notify("Code updated successfully", vim.log.levels.INFO)
        if config.debug_mode then
          local total_time = time_since_start
          local time_to_first_chunk = first_chunk_time and (first_chunk_time - start_time) / 1000000 or 0
          print(string.format("FINAL: Total chunks=%d, total_time=%.1fms, time_to_first=%.1fms", 
            chunk_count, total_time, time_to_first_chunk))
        end
      end
    end)
  end)
end

function M.replace_code_dynamic(ai_response, start_line, start_col, end_line, end_col)
  local response_lines = vim.split(ai_response, "\n")
  
  -- Debug: Show what we're replacing
  if config.debug_mode then
    print(string.format("REPLACE: %d lines, range %d-%d, first='%s', last='%s'", 
      #response_lines, start_line, end_line + 1, 
      response_lines[1] or "", response_lines[#response_lines] or ""))
  end
  
  -- Replace all lines from start_line to the end of what was previously inserted
  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, response_lines)
  
  -- Calculate the new end line based on how many lines we just inserted
  local new_end_line = start_line + #response_lines - 1
  
  -- Debug: Check what's actually in the buffer now
  if config.debug_mode then
    local actual_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local twitter_count = 0
    local full_content = table.concat(actual_lines, "\n")
    for match in full_content:gmatch("twitter:title") do
      twitter_count = twitter_count + 1
    end
    print(string.format("BUFFER: %d total lines, %d 'twitter:title' occurrences, new_end=%d", #actual_lines, twitter_count, new_end_line))
  end
  
  -- Return the new end line for the next iteration
  return new_end_line
end

function M.replace_code(ai_response, start_line, start_col, end_line, end_col)
  local response_lines = vim.split(ai_response, "\n")
  
  -- Replace the selected lines
  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, response_lines)
end

return M