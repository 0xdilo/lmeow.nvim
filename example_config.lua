-- Example configuration for lazy.nvim
return {
  "0xdilo/lmeow.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("lmeow").setup({
      default_model = "gpt4",

      -- Add custom models here
      models = {
        bestmodel = {
          provider = "openai",
          model = "gpt-5",
          name = "Best Model",
          -- Model-level overrides (override provider defaults)
          temperature = 1, -- only supports 1
          max_completion_tokens = 65536
        },
        fastmodel = {
          provider = "openai",
          model = "gpt-3.5-turbo",
          name = "Fast Model",
          -- Example: override temperature just for this model
          temperature = 0.1
        },
        codingassistant = {
          provider = "claude",
          model = "claude-3-5-sonnet-20241022",
          name = "Coding Assistant",
          max_tokens = 6000
        },
        fastai = {
          provider = "gemini",
          model = "gemini-2.5-flash",
          name = "Fast AI"
        },
        -- Example showing per-model base_url override (e.g., gateway or proxy)
        router_llama = {
          provider = "openrouter",
          model = "meta-llama/llama-3.1-70b",
          name = "Router Llama",
          base_url = "https://openrouter.ai/api/v1/chat/completions",
          temperature = 0.3
        }
      },

      -- Override default provider settings if needed
      providers = {
        openai = {
          max_tokens = 3000,
          temperature = 0.3
        },
        -- You can also set defaults for other providers
        claude = {
          max_tokens = 4000,
          temperature = 0.6
        }
      },

      system_prompt =
      [[You are an expert programmer and text processor. When asked to modify content, preserve ALL existing structure, text, and formatting that is not directly related to the requested changes. Only modify what's necessary to complete the task. Return ONLY the modified content without any explanations, comments, markdown, or additional formatting.]],

      keymaps = {
        edit_selection = "<leader>ac" -- AI Code edit
      }
    })
  end
}
