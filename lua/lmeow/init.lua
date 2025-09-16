local M = {}

M.config = {
  models = {
    -- OpenAI models
    gpt4 = {
      provider = "openai",
      model = "gpt-4",
      name = "GPT-4"
    },
    gpt4o = {
      provider = "openai",
      model = "gpt-4o",
      name = "GPT-4o"
    },
    gpt4turbo = {
      provider = "openai",
      model = "gpt-4-turbo",
      name = "GPT-4 Turbo"
    },
    gpt35 = {
      provider = "openai",
      model = "gpt-3.5-turbo",
      name = "GPT-3.5"
    },

    -- Claude models
    claude = {
      provider = "claude",
      model = "claude-3-5-sonnet-20241022",
      name = "Claude 3.5 Sonnet"
    },
    claudeopus = {
      provider = "claude",
      model = "claude-3-opus-20240229",
      name = "Claude 3 Opus"
    },
    claudehaiku = {
      provider = "claude",
      model = "claude-3-haiku-20240307",
      name = "Claude 3 Haiku"
    },

    -- OpenRouter models
    gpt4router = {
      provider = "openrouter",
      model = "openai/gpt-4",
      name = "GPT-4 (OpenRouter)"
    },
    llama = {
      provider = "openrouter",
      model = "meta-llama/llama-3.1-70b",
      name = "Llama 3.1 70B"
    },

    -- Grok models
    grok = {
      provider = "grok",
      model = "grok-beta",
      name = "Grok Beta"
    },

    -- Gemini models
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

  default_model = "gpt4",

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
        max_tokens = 2000,
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
      vim.notify("Lmeow: Usage: :Lmeow model <name> | :Lmeow status", vim.log.levels.WARN)
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
        vim.notify(
          "Lmeow: Model=" ..
          model_info.name ..
          ", Provider=" ..
          model_info.provider ..
          ", API Key=" .. api_key_status .. "\nAvailable models: " .. table.concat(model_names, ", "),
          vim.log.levels.INFO)
      else
        vim.notify("Lmeow: Invalid model configuration", vim.log.levels.ERROR)
      end
    end
  end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local cmd_parts = vim.split(cmd_line, "%s+")

      if #cmd_parts == 2 then
        return vim.tbl_filter(function(cmd)
          return cmd:match("^" .. arg_lead)
        end, { "model", "status" })
      elseif #cmd_parts == 3 and cmd_parts[2] == "model" then
        local models = vim.tbl_keys(M.config.models)
        return vim.tbl_filter(function(m)
          return m:match("^" .. arg_lead)
        end, models)
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
