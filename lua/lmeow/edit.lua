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
  
  vim.schedule(function()
    vim.notify("Processing AI request with " .. model_config.name, vim.log.levels.INFO)
  end)
  
  local providers = require("lmeow.providers")
  providers.call_provider(model_config.provider, model_config, selected_text, prompt, function(response, error)
    vim.schedule(function()
      if error then
        vim.notify("AI request failed: " .. error, vim.log.levels.ERROR)
        return
      end
      
      M.replace_code(response, start_line, start_col, end_line, end_col)
    end)
  end)
end

function M.replace_code(ai_response, start_line, start_col, end_line, end_col)
  local response_lines = vim.split(ai_response, "\n")
  
  -- Replace the selected lines
  vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, response_lines)
  
  vim.notify("Code updated successfully", vim.log.levels.INFO)
end

return M