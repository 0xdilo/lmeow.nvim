-- Example configuration for lazy.nvim
return {
  "polizia/lmeow.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("lmeow").setup({
      default_model = "gpt4",
      
      -- Add custom models here
      models = {
        bestmodel = {
          provider = "openai",
          model = "gpt-5",
          name = "Best Model"
        },
        fastmodel = {
          provider = "openai", 
          model = "gpt-3.5-turbo",
          name = "Fast Model"
        },
        codingassistant = {
          provider = "claude",
          model = "claude-3-5-sonnet-20241022",
          name = "Coding Assistant"
        },
        fastai = {
          provider = "gemini",
          model = "gemini-2.5-flash",
          name = "Fast AI"
        }
      },
      
      -- Override default provider settings if needed
      providers = {
        openai = {
          max_tokens = 3000,
          temperature = 0.3
        }
      },
      
      system_prompt = [[You are an expert programmer and text processor. When asked to modify content, preserve ALL existing structure, text, and formatting that is not directly related to the requested changes. Only modify what's necessary to complete the task. Return ONLY the modified content without any explanations, comments, markdown, or additional formatting.]],
      
      keymaps = {
        edit_selection = "<leader>ac"  -- AI Code edit
      }
    })
  end
}