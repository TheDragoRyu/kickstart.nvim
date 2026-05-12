# AGENTS.md

## Project Overview

This is a personal Neovim configuration. It uses a modular Lua layout and
lazy.nvim for plugin management.

## Structure

- `init.lua` is the entry point. It sets leader keys and
  `vim.g.have_nerd_font`, loads `config.*` modules, bootstraps lazy.nvim, and
  calls `lazy.setup('plugins')`.
- `lua/config/` contains editor options, global keymaps, and autocommands.
  These modules are side-effect modules and do not return values.
- `lua/plugins/` contains plugin specs. Use one file per plugin, or per tightly
  coupled plugin group. Files are auto-discovered by lazy.nvim.
- `lua/kickstart/health.lua` provides `:checkhealth kickstart`. Do not move or
  rename this file.

## Conventions

- Plugin files are named with hyphens matching the plugin, for example
  `blink-cmp.lua` or `neo-tree.lua`.
- Plugin-specific keymaps belong in that plugin's file, either in `keys` or
  `config`.
- `lua/config/keymaps.lua` is only for global keymaps that do not depend on a
  plugin.
- Keep `vim.g.have_nerd_font` and leader key setup in `init.lua`; they must be
  evaluated before `lazy.setup`.
- When a plugin file returns multiple specs, use a list:
  `return { { spec1 }, { spec2 } }`.

## Adding Plugins

Create `lua/plugins/<name>.lua` returning a lazy.nvim spec table. No other files
need to change for lazy.nvim discovery.

## Formatting

Lua files are formatted with stylua using `.stylua.toml`. Format-on-save is
enabled through conform.nvim.

## Testing Changes

Run the relevant checks after changes:

```sh
nvim --headless -c 'lua print("OK")' -c 'qa!'
nvim -c ':Lazy'
nvim -c ':checkhealth kickstart'
```
