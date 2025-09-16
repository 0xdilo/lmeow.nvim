# Lmeow.nvim

Inline AI code editing for Neovim.

## Features

- Visual mode selection and AI-powered code editing
- Simple model-based configuration (no provider switching needed)
- Built-in models for major providers (OpenAI, Claude, OpenRouter, Grok)
- Easy custom model addition
- Environment variable API key detection
- Lazy.nvim compatible

## Installation

```lua
{
  "polizia/lmeow.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("lmeow").setup({
      default_model = "gpt4",
      
      -- Add your custom models
      models = {
        bestmodel = {
          provider = "openai",
          model = "gpt-5",
          name = "Best Model"
        }
      }
    })
  end
}
```

## Environment Variables

API keys are automatically detected from environment variables:

- `OPENAI_API_KEY` - OpenAI API key
- `ANTHROPIC_API_KEY` - Anthropic/Claude API key  
- `OPENROUTER_API_KEY` - OpenRouter API key
- `XAI_API_KEY` - X.AI/Grok API key
- `GEMINI_API_KEY` - Google Gemini API key

## Built-in Models

The plugin includes these models by default:

- `gpt4` - GPT-4 (OpenAI)
- `gpt4o` - GPT-4o (OpenAI)
- `gpt4turbo` - GPT-4 Turbo (OpenAI)
- `gpt35` - GPT-3.5 (OpenAI)
- `claude` - Claude 3.5 Sonnet (Anthropic)
- `claudeopus` - Claude 3 Opus (Anthropic)
- `claudehaiku` - Claude 3 Haiku (Anthropic)
- `gpt4router` - GPT-4 via OpenRouter
- `llama` - Llama 3.1 70B (OpenRouter)
- `grok` - Grok Beta (X.AI)
- `gemini` - Gemini 2.5 Flash (Google)
- `geminipro` - Gemini 2.5 Pro (Google)

## Usage

1. Select code in visual mode (v)
2. Press `<leader>ac` (default mapping)
3. Enter your prompt
4. AI will edit the code inline

## Commands

- `:Lmeow model <name>` - Switch to a different model
- `:Lmeow models` - List all available models
- `:Lmeow status` - Show current model and API key status

## Configuration

Add custom models easily:

```lua
require("lmeow").setup({
  default_model = "bestmodel",
  models = {
    bestmodel = {
      provider = "openai",
      model = "gpt-5",  -- The actual model name for the API
      name = "Best Model"  -- Display name
    },
    fastmodel = {
      provider = "claude",
      model = "claude-3-haiku-20240307",
      name = "Fast Model"
    }
  }
})
```

Then use: `:Lmeow model bestmodel`