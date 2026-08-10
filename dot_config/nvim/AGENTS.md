# AGENTS.md

## Neovim Config Rules (`/home/isaac/.config/nvim`)

When answering questions about mappings or editor behavior in this project, do not guess. Use local source of truth in this order:

1. Find framework source locally (no internet required).
2. Check framework defaults/core mappings and plugin specs.
3. Check local overrides in this repo.
4. Verify effective runtime mapping/behavior.

## Where Framework Source Lives (Local)

LazyVim and plugin sources are installed under:

- `vim.fn.stdpath("data") .. "/lazy"` (Neovim expression)
- Typical Linux path: `~/.local/share/nvim/lazy`

Key framework locations:

- LazyVim core config: `$LAZY_ROOT/LazyVim/lua/lazyvim/config/`
- LazyVim default keymaps: `$LAZY_ROOT/LazyVim/lua/lazyvim/config/keymaps.lua`
- LazyVim plugin specs: `$LAZY_ROOT/LazyVim/lua/lazyvim/plugins/`
- Installed plugin source: `$LAZY_ROOT/<plugin-name>/`

## No-Guesswork Lookup Workflow

1. Search LazyVim core/spec files for the feature first (for example with `rg` in `$LAZY_ROOT/LazyVim/lua/lazyvim/`).
2. For keybindings, inspect:
   - `$LAZY_ROOT/LazyVim/lua/lazyvim/config/keymaps.lua`
   - `keys = { ... }` entries in `$LAZY_ROOT/LazyVim/lua/lazyvim/plugins/*.lua`
3. Then inspect local config overrides:
   - `/home/isaac/.config/nvim/init.lua`
   - `/home/isaac/.config/nvim/lua/config/`
   - `/home/isaac/.config/nvim/lua/plugins/`
4. Finally verify runtime mapping when needed:
   - `:verbose map <lhs>`
   - `:verbose nmap <lhs>`

## Runtime Verification Notes

- This project uses LazyVim's framework defaults: Space for `<leader>` and backslash for `<localleader>`. The defaults are defined in `lua/lazyvim/config/options.lua`; local `init.lua` does not override them.
- When investigating a configuration with leader overrides, check the effective value after startup with `:lua print(vim.inspect(vim.g.mapleader))`.
- Resolve `<leader>` to the effective character before querying a mapping. For example, when the effective leader is Space, inspect `<Space>cd` (or ` cd` with `vim.fn.maparg`), not a comma-based mapping.
- LazyVim loads its core keymaps on the `User VeryLazy` event. A headless check performed immediately during startup can incorrectly report that a mapping is absent. Wait for startup or explicitly run `:doautocmd User VeryLazy` before inspecting core mappings.
- LSP mappings such as `K` are capability-dependent and buffer-local. Verify them in a real file buffer after the appropriate LSP client attaches; their absence in an empty headless buffer does not prove that the configured mapping is unavailable.
- For scriptable verification, `vim.fn.maparg(lhs, "n", false, true)` returns the effective mapping metadata, including `desc`, `rhs`, `callback`, and whether it is buffer-local.

## Response Requirement

Always state whether a result comes from:

1. LazyVim/framework defaults, or
2. Local project config.
