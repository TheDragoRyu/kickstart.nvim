# nvim config

Personal Neovim configuration, originally forked from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) and restructured into a modular layout.

## Structure

```
init.lua                  -- Bootstrap: leader keys, lazy.nvim setup
lua/
  config/
    options.lua           -- Editor settings (numbers, search, splits, etc.)
    keymaps.lua           -- Global keymaps (not tied to any plugin)
    autocmds.lua          -- Autocommands (yank highlight, markdown filetype)
  plugins/
    autopairs.lua         -- Auto-close brackets/quotes
    blink-cmp.lua         -- Completion (blink.cmp + LuaSnip)
    colorscheme.lua       -- Tokyonight theme
    conform.lua           -- Autoformatting (stylua, format-on-save)
    debug.lua             -- DAP debugger (Go/delve)
    gitsigns.lua          -- Git gutter signs + hunk operations
    guess-indent.lua      -- Auto-detect indentation
    indent-line.lua       -- Visual indentation guides
    lint.lua              -- Linting (pycodestyle, hadolint)
    lsp.lua               -- LSP config (mason, pyright, gopls, lua_ls)
    mini.lua              -- mini.ai, mini.surround, mini.statusline
    neo-tree.lua          -- File tree browser
    render-markdown.lua   -- Live markdown rendering
    telescope.lua         -- Fuzzy finder + all search keymaps
    todo-comments.lua     -- Highlight TODO/NOTE/FIXME in comments
    treesitter.lua        -- Syntax highlighting + parsing
    which-key.lua         -- Keymap hints popup
  kickstart/
    health.lua            -- :checkhealth kickstart
```

## Adding a plugin

Create a new file in `lua/plugins/`, e.g. `lua/plugins/my-plugin.lua`:

```lua
return {
  'author/my-plugin.nvim',
  opts = {},
}
```

That's it. lazy.nvim auto-discovers all files in `lua/plugins/`.

## Requirements

- Neovim >= 0.10 (0.11+ recommended)
- git, make, gcc, ripgrep
- A [Nerd Font](https://www.nerdfonts.com/) (configured via `vim.g.have_nerd_font` in init.lua)
- Clipboard tool (xclip/xsel)

## Key mappings

Leader key is `<Space>`. Some highlights:

| Key | Mode | Action |
| :-- | :--- | :----- |
| `<leader>sf` | n | Search files (Telescope) |
| `<leader>sg` | n | Search by grep |
| `<leader><leader>` | n | Find open buffers |
| `gd` | n | Go to definition (LSP) |
| `gr` | n | Go to references (LSP) |
| `gn` | n | Rename symbol (LSP) |
| `<leader>r` | n | Format buffer |
| `\` | n | Toggle Neo-tree |
| `<leader>hs` | n | Git stage hunk |
| `]c` / `[c` | n | Next/prev git change |
| `<F5>` | n | Start/continue debugger |
| `jk` | i | Exit insert mode |

Run `<Space>sk` to search all keymaps via Telescope.
