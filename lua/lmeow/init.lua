local M = {}

M.config = {
  models = {
    -- OpenAI models (2025 latest)
    gpt5 = {
      provider = "openai",
      model = "gpt-5",
      name = "GPT-5"
    },
    gpt5mini = {
      provider = "openai",
      model = "gpt-5-mini",
      name = "GPT-5 Mini"
    },
    gpt5nano = {
      provider = "openai",
      model = "gpt-5-nano",
      name = "GPT-5 Nano"
    },
    gpt41 = {
      provider = "openai",
      model = "gpt-4.1",
      name = "GPT-4.1"
    },
    gpt41mini = {
      provider = "openai",
      model = "gpt-4.1-mini",
      name = "GPT-4.1 Mini"
    },
    gpt45 = {
      provider = "openai",
      model = "gpt-4.5",
      name = "GPT-4.5"
    },

    -- Claude models (2025 latest)
    claude37 = {
      provider = "claude",
      model = "claude-3-7-sonnet-20250219",
      name = "Claude 3.7 Sonnet"
    },
    claude4 = {
      provider = "claude",
      model = "claude-sonnet-4-20250514",
      name = "Claude 4 Sonnet"
    },
    claude4opus = {
      provider = "claude",
      model = "claude-opus-4-20250514",
      name = "Claude 4 Opus"
    },
    claude41opus = {
      provider = "claude",
      model = "claude-opus-4-1-20250805",
      name = "Claude 4.1 Opus"
    },

    -- OpenRouter models (2025 latest)
    gpt5router = {
      provider = "openrouter",
      model = "openai/gpt-5",
      name = "GPT-5 (OpenRouter)"
    },
    llama4 = {
      provider = "openrouter",
      model = "meta-llama/llama-4-maverick-17b",
      name = "Llama 4 Maverick 17B"
    },
    llama4scout = {
      provider = "openrouter",
      model = "meta-llama/llama-4-scout-17b",
      name = "Llama 4 Scout 17B"
    },
    llama31_405b = {
      provider = "openrouter",
      model = "meta-llama/llama-3.1-405b",
      name = "Llama 3.1 405B"
    },

    -- Grok models (2025 latest)
    grok4 = {
      provider = "grok",
      model = "grok-4",
      name = "Grok 4"
    },
    grok4heavy = {
      provider = "grok",
      model = "grok-4-heavy",
      name = "Grok 4 Heavy"
    },
    grokcode = {
      provider = "grok",
      model = "grok-code-fast-1",
      name = "Grok Code Fast"
    },

    -- Gemini models (keeping current as requested)
    gemini = {
      provider = "gemini",
      model = "gemini-2.5-flash",
      name = "Gemini 2.5 Flash"
    },
    geminipro = {
      provider = "gemini",
      model = "gemini-2.5-pro",
      name = "Gemini 2.5 Pro"
    }
  },

  default_model = "claude4",

  providers = {
    openai = {
      base_url = "https://api.openai.com/v1/chat/completions",
      env_var = "OPENAI_API_KEY",
      defaultModelParams = {
        max_completion_tokens = 32000,
        temperature = 1
      }
    },
    claude = {
      base_url = "https://api.anthropic.com/v1/messages",
      env_var = "ANTHROPIC_API_KEY",
      defaultModelParams = {
        max_tokens = 2000,
        temperature = 0.7
      }
    },
    openrouter = {
      base_url = "https://openrouter.ai/api/v1/chat/completions",
      env_var = "OPENROUTER_API_KEY",
      defaultModelParams = {
        max_tokens = 2000,
        temperature = 0.7
      }
    },
    grok = {
      base_url = "https://api.x.ai/v1/chat/completions",
      env_var = "XAI_API_KEY",
      defaultModelParams = {
        max_tokens = 2000,
        temperature = 0.7
      }
    },
    gemini = {
      base_url = "https://generativelanguage.googleapis.com/v1beta/models/",
      env_var = "GEMINI_API_KEY",
      defaultModelParams = {
        max_tokens = 8000,
        temperature = 0.7
      }
    }
  },

  system_prompt =
  "You are an expert programmer and text processor. When asked to modify content, preserve ALL existing structure, text, and formatting that is not directly related to the requested changes. Only modify what's necessary to complete the task. Return ONLY the modified content without any explanations, comments, markdown, or additional formatting.",

  keymaps = {
    edit_selection = "<leader>ac"
  }
}

M.current_model = nil
M.debug_mode = false

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.current_model = M.config.default_model

  -- Resolve API keys from environment variables
  for provider_name, provider_config in pairs(M.config.providers) do
    if provider_config.env_var and not provider_config.api_key then
      provider_config.api_key = os.getenv(provider_config.env_var)
    end
  end

  M.setup_keymaps()
  M.setup_commands()

  vim.api.nvim_set_hl(0, "LmeowPopup", { fg = "#ffffff", bg = "#1e1e1e" })
  vim.api.nvim_set_hl(0, "LmeowBorder", { fg = "#61afef", bg = "#1e1e1e" })
  
  -- Note: vim.tbl_flatten deprecation warnings come from plenary.nvim dependency
  -- This will be fixed when plenary.nvim updates to use vim.iter():flatten()
end

function M.setup_keymaps()
  if M.config.keymaps and M.config.keymaps.edit_selection then
    vim.keymap.set("x", M.config.keymaps.edit_selection, function()
      -- Store the current visual selection before exiting visual mode
      local start_line = vim.fn.line("v")
      local end_line = vim.fn.line(".")

      -- Exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)

      -- Call edit function with the stored selection
      require("lmeow.edit").edit_selection_with_range(start_line, end_line)
    end, { desc = "Edit selection with AI" })
  end
end

function M.setup_commands()
  vim.api.nvim_create_user_command("Lmeow", function(opts)
    local args = opts.fargs
    if #args == 0 then
      vim.notify("Lmeow: Usage: :Lmeow model <name> | :Lmeow status | :Lmeow debug [on|off]", vim.log.levels.WARN)
      return
    end

    local subcommand = args[1]

    if subcommand == "model" and #args >= 2 then
      local model_name = args[2]
      if M.config.models[model_name] then
        M.current_model = model_name
        local model_info = M.config.models[model_name]
        vim.notify("Lmeow: Model switched to " .. model_info.name, vim.log.levels.INFO)
      else
        vim.notify("Lmeow: Model '" .. model_name .. "' not found", vim.log.levels.ERROR)
      end
    elseif subcommand == "status" then
      local model_info = M.config.models[M.current_model]
      if model_info then
        local provider_config = M.config.providers[model_info.provider]
        local api_key_status = provider_config and provider_config.api_key and "set" or "not set"
        local model_names = vim.tbl_keys(M.config.models)
        local debug_status = M.debug_mode and "enabled" or "disabled"
        vim.notify(
          "Lmeow: Model=" ..
          model_info.name ..
          ", Provider=" ..
          model_info.provider ..
          ", API Key=" .. api_key_status .. 
          ", Debug=" .. debug_status .. "\nAvailable models: " .. table.concat(model_names, ", "),
          vim.log.levels.INFO)
      else
        vim.notify("Lmeow: Invalid model configuration", vim.log.levels.ERROR)
      end
    elseif subcommand == "debug" then
      if #args >= 2 then
        local debug_arg = args[2]:lower()
        if debug_arg == "on" or debug_arg == "true" or debug_arg == "1" then
          M.debug_mode = true
          vim.notify("Lmeow: Debug mode enabled", vim.log.levels.INFO)
        elseif debug_arg == "off" or debug_arg == "false" or debug_arg == "0" then
          M.debug_mode = false
          vim.notify("Lmeow: Debug mode disabled", vim.log.levels.INFO)
        else
          vim.notify("Lmeow: Invalid debug argument. Use 'on' or 'off'", vim.log.levels.ERROR)
        end
      else
        -- Toggle debug mode
        M.debug_mode = not M.debug_mode
        local status = M.debug_mode and "enabled" or "disabled"
        vim.notify("Lmeow: Debug mode " .. status, vim.log.levels.INFO)
      end
    end
  end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local cmd_parts = vim.split(cmd_line, "%s+")

      if #cmd_parts == 2 then
        return vim.tbl_filter(function(cmd)
          return cmd:match("^" .. arg_lead)
        end, { "model", "status", "debug" })
      elseif #cmd_parts == 3 and cmd_parts[2] == "model" then
        local models = vim.tbl_keys(M.config.models)
        return vim.tbl_filter(function(m)
          return m:match("^" .. arg_lead)
        end, models)
      elseif #cmd_parts == 3 and cmd_parts[2] == "debug" then
        return vim.tbl_filter(function(cmd)
          return cmd:match("^" .. arg_lead)
        end, { "on", "off" })
      end
      return {}
    end
  })
end

function M.get_current_model()
  return M.current_model or M.config.default_model
end

function M.get_model_config(model_name)
  local model_config = M.config.models[model_name] or M.config.models[M.config.default_model]
  if not model_config then
    return nil
  end

  local provider_config = M.config.providers[model_config.provider]
  if not provider_config then
    return nil
  end

  -- Create a copy of the provider config (provider-level data only)
  local full_config = vim.tbl_deep_extend("force", {}, provider_config)

  -- Always check environment variables for API key
  if not full_config.api_key and full_config.env_var then
    full_config.api_key = os.getenv(full_config.env_var)
  end

  -- Attach model identity info (but don't mix with payload params)
  full_config.provider = model_config.provider
  full_config.model = model_config.model
  full_config.name = model_config.name or full_config.model
  -- Allow model-level override of provider connection settings
  if model_config.base_url then full_config.base_url = model_config.base_url end
  if model_config.api_key then full_config.api_key = model_config.api_key end
  if model_config.env_var then full_config.env_var = model_config.env_var end

  -- Build params separately: provider defaults -> model params -> legacy fallbacks
  local params = {}
  -- Provider defaults (new key)
  if provider_config.defaultModelParams then
    params = vim.tbl_deep_extend("force", params, provider_config.defaultModelParams)
  end
  -- Provider legacy fallbacks
  if provider_config.max_tokens or provider_config.temperature then
    params = vim.tbl_deep_extend("force", params, {
      max_tokens = provider_config.max_tokens,
      temperature = provider_config.temperature,
    })
  end
  -- Model-specific params (new key)
  if model_config.params then
    params = vim.tbl_deep_extend("force", params, model_config.params)
  end
  -- Model legacy fallbacks
  if model_config.max_tokens or model_config.temperature then
    params = vim.tbl_deep_extend("force", params, {
      max_tokens = model_config.max_tokens,
      temperature = model_config.temperature,
    })
  end

  -- Ensure model is present in params for providers that require it in the payload
  if model_config.model and params.model == nil then
    params.model = model_config.model
  end

  full_config.params = params

  return full_config
end

return M
