-- Example configuration for lazy.nvim
return {
  "0xdilo/lmeow.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("lmeow").setup({
      default_model = "gpt5",

      -- Add custom models here
      models = {
        bestmodel = {
          provider = "openai",
          model = "gpt-5",
          name = "Best Model",
          -- Model-level params (override provider defaults)
          params = {
            temperature = 1, -- only supports 1
            max_completion_tokens = 65536
          }
        },
        fastmodel = {
          provider = "openai",
          model = "gpt-5-nano",
          name = "Fast Model",
          -- Example: override temperature just for this model
          params = { temperature = 0.1 }
        },
        codingassistant = {
          provider = "claude",
          model = "claude-4-sonnet",
          name = "Coding Assistant",
          params = { max_tokens = 32000 }
        },
        fastai = {
          provider = "gemini",
          model = "gemini-2.5-flash",
          name = "Fast AI",
          params = { max_tokens = 32000 }
        },
        -- Example showing per-model base_url override (e.g., gateway or proxy)
        router_llama = {
          provider = "openrouter",
          model = "meta-llama/llama-3.1-70b",
          name = "Router Llama",
          base_url = "https://openrouter.ai/api/v1/chat/completions",
          params = { temperature = 0.3 }
        }
      },

      -- Override default provider settings if needed
      providers = {
        openai = {
          defaultModelParams = {
            max_completion_tokens = 3000,
            temperature = 1
          }
        },
        -- You can also set defaults for other providers
        claude = {
          defaultModelParams = {
            max_tokens = 32000,
            temperature = 0.7
          }
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
