# lmeow.nvim

<div align="center">

```
   ∧,,,∧
  (  • ω •)
  / づ💡 
```

**🐱 AI-powered inline code editing for Neovim**

</div>

## ✨ Features

- 🎯 **Inline AI editing** - Select code and get AI-powered modifications
- 🤖 **Multiple LLM providers** - OpenAI, Claude, Gemini, OpenRouter, Grok
- 🚀 **Environment variable support** - No hardcoded API keys needed
- 🎨 **Custom models** - Easy addition of your own AI models
- 📝 **Smart prompts** - Preserves existing content while making requested changes
- 🎹 **Simple interface** - Visual select → press shortcut → enter prompt → done
- 🔧 **No configuration required** - Works out of the box with sensible defaults

## 🚀 Installation

Add to your lazy.nvim config:

```lua
{
  "0xdilo/lmeow.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("lmeow").setup({
      -- Configuration goes here (see below)
    })
  end
}
```

## 🔑 Setup API Keys

Set environment variables in your shell:

```bash
# OpenAI
export OPENAI_API_KEY="your-openai-key"

# Anthropic/Claude  
export ANTHROPIC_API_KEY="your-claude-key"

# Google Gemini
export GEMINI_API_KEY="your-gemini-key"

# OpenRouter
export OPENROUTER_API_KEY="your-openrouter-key"

# X.AI/Grok
export XAI_API_KEY="your-grok-key"
```

## 🎯 Quick Start

1. **Select code** in visual mode (`v`)
2. **Press** `<leader>ac` (default keymap)
3. **Enter your prompt** (e.g., "add error handling", "optimize this function", "translate to Python")
4. **AI replaces** your selection with the improved code

## 📖 Commands

- `:Lmeow model <name>` - Switch to a different model
- `:Lmeow status` - Show current model and available models

## 🤖 Built-in Models

The plugin includes these models by default:

| Model Name | Provider | Description |
|------------|----------|-------------|
| `gpt4` | OpenAI | GPT-4 |
| `gpt4o` | OpenAI | GPT-4o |
| `gpt4turbo` | OpenAI | GPT-4 Turbo |
| `gpt35` | OpenAI | GPT-3.5 Turbo |
| `claude` | Anthropic | Claude 3.5 Sonnet |
| `claudeopus` | Anthropic | Claude 3 Opus |
| `claudehaiku` | Anthropic | Claude 3 Haiku |
| `gemini` | Google | Gemini 2.5 Flash |
| `geminipro` | Google | Gemini 2.5 Pro |
| `gpt4router` | OpenRouter | GPT-4 via OpenRouter |
| `llama` | OpenRouter | Llama 3.1 70B |
| `grok` | X.AI | Grok Beta |

## ⚙️ Configuration

### Basic Setup

```lua
require("lmeow").setup({
  default_model = "gpt4",  -- Your preferred default model
  keymaps = {
    edit_selection = "<leader>ac"  -- Or your preferred keymap
  }
})
```

### Adding Custom Models

```lua
require("lmeow").setup({
  default_model = "gpt4",
  
  models = {
    -- Add your custom models here
    gpt5 = {
      provider = "openai",
      model = "gpt-5",
      name = "GPT-5",
      -- Per-model overrides (override provider defaults)
      temperature = 0.2,
      max_tokens = 4096
    },
    
    myclaude = {
      provider = "claude",
      model = "claude-3-5-sonnet-20241022", 
      name = "My Claude",
      max_tokens = 5000
    },
    
    mixtral = {
      provider = "openrouter",
      model = "mistralai/mixtral-8x7b-instruct",
      name = "Mixtral 8x7B"
    },
    
    coding_assistant = {
      provider = "gemini",
      model = "gemini-2.5-flash",
      name = "Fast Coder"
    }
  },
  
  -- Override provider settings if needed
  providers = {
    openai = {
      max_tokens = 3000,
      temperature = 0.3
    },
    claude = {
      max_tokens = 4000,
      temperature = 0.7
    }
  },
  
  keymaps = {
    edit_selection = "<leader>ac"
  }
})
```

### Advanced Configuration

```lua
require("lmeow").setup({
  default_model = "gpt4",
  
  -- Add your own custom system prompt that gets combined with the default one
  custom_system_prompt = "Speak with enthusiasm and use emojis when appropriate 🚀",
  
  models = {
    -- Your custom models
  },
  
  providers = {
    openai = {
      max_tokens = 2000,
      temperature = 0.7,
      -- Override base URL for custom endpoints
      base_url = "https://api.openai.com/v1/chat/completions"
    }
  },
  
  keymaps = {
    edit_selection = "<leader>ac"
  }
})
```

### Provider vs Model Overrides

- Provider config sets defaults for all models under that provider (e.g., `temperature`, `max_tokens`, `base_url`).
- Model config can override any of those fields for that specific model.
- API keys resolve from `providers.<name>.env_var` environment variable by default; a model-level `api_key` can override if needed.

Example:

```lua
require("lmeow").setup({
  models = {
    precise_gpt4 = {
      provider = "openai",
      model = "gpt-4o",
      name = "Precise GPT-4o",
      temperature = 0.1,   -- override provider default
      max_tokens = 4096    -- override provider default
    }
  },
  providers = {
    openai = {
      temperature = 0.7,   -- default for all OpenAI models
      max_tokens = 2000
    }
  }
})
```

### Custom System Prompt

You can add your own custom system prompt that will be combined with the default system prompt. This is perfect for:

- Setting a specific tone or style (e.g., "Always speak with emojis 😊")
- Adding domain-specific knowledge or requirements
- Customizing the AI's behavior for your specific needs

```lua
require("lmeow").setup({
  default_model = "gpt4",
  
  -- Examples of custom system prompts:
  custom_system_prompt = "Speak without using any emojis",  -- Disable emojis
  -- OR
  custom_system_prompt = "Always respond with a helpful tone and include relevant code examples",
  -- OR  
  custom_system_prompt = "You are a senior Python developer. Focus on clean, idiomatic Python code.",
  
  keymaps = {
    edit_selection = "<leader>ac"
  }
})
```

## 🎨 Usage Examples

### Code Refactoring
```lua
-- Select this function and prompt: "add error handling"
function getData()
  return fetch("/api/data")
end

-- AI might return:
async function getData() {
  try {
    const response = await fetch("/api/data");
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error("Failed to fetch data:", error);
    throw error;
  }
}
```

### Text Processing
```
Hello, how are you?
```

**Prompt:** "translate to spanish"

**Result:**
```
Hola, ¿cómo estás?
```

### HTML Enhancement
```html
<head>
  <meta charset="utf-8" />
</head>
```

**Prompt:** "add meta tags for SEO"

**Result:**
```html
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="Your page description" />
  <meta name="keywords" content="keyword1, keyword2, keyword3" />
  <meta name="author" content="Your Name" />
</head>
```

## 🛠️ How It Works

1. **Visual Selection** - Select code/text in visual mode
2. **Smart Prompting** - Plugin creates context-aware prompts that preserve existing content
3. **API Integration** - Sends request to your chosen AI provider
4. **Inline Replacement** - Replaces selection with AI's response
5. **Content Preservation** - AI is instructed to keep unrelated content intact

## 🔍 Troubleshooting

### Common Issues

**"No text selected" error**
- Make sure you've actually selected text in visual mode
- Try selecting again - sometimes visual marks need to be reset

**"API key not set" error**
- Check your environment variables are set correctly
- Restart Neovim after setting environment variables

**Model not found**
- Check the model name in your config
- Use `:Lmeow status` to see available models

### Debug Mode

Enable debug logging:

```lua
require("lmeow").setup({
  -- Your config
})
```

## 🤝 Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

## 📄 License

MIT License - see LICENSE file for details.

---

<div align="center">

Made with 🐱💡 by [0xdilo](https://github.com/0xdilo)

```
   ∧,,,∧
  (  • ω •)
  / ❤️ づ 
```

</div>
