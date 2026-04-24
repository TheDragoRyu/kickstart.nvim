# CLAUDE.md

## Project overview

Personal Neovim config. Modular layout using lazy.nvim for plugin management.

## Structure

- `init.lua` — Entry point. Sets leader keys, `have_nerd_font`, loads `config.*` modules, bootstraps lazy.nvim, calls `lazy.setup('plugins')`.
- `lua/config/` — Editor options, global keymaps, autocommands. Side-effect modules (no return values).
- `lua/plugins/` — One file per plugin (or tightly coupled group). Each returns a lazy.nvim spec table. Auto-discovered by lazy.nvim.
- `lua/kickstart/health.lua` — `:checkhealth kickstart` module. Do not move or rename.

## Conventions

- Plugin files are named with hyphens matching the plugin (e.g. `blink-cmp.lua`, `neo-tree.lua`).
- Plugin-specific keymaps belong in their plugin file (in `keys` or `config`), not in `config/keymaps.lua`.
- `config/keymaps.lua` is only for global keymaps that don't depend on any plugin.
- `vim.g.have_nerd_font` and leader keys must stay in `init.lua` (evaluated before lazy.setup).
- When a plugin file returns multiple specs (e.g. `lsp.lua` returns lazydev + lspconfig), use a list: `return { {spec1}, {spec2} }`.

## Adding a plugin

Create `lua/plugins/<name>.lua` returning a spec table. No other files need to change.

## Formatting

Lua files are formatted with stylua (configured in `.stylua.toml`). Format-on-save is enabled via conform.nvim.

## Testing changes

```sh
nvim --headless -c 'lua print("OK")' -c 'qa!'   # startup check
nvim -c ':Lazy'                                    # verify all plugins load
nvim -c ':checkhealth kickstart'                   # health check
```
