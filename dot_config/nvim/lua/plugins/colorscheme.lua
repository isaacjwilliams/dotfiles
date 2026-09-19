return {
  -- Noctalia drives the palette via lua/matugen.lua (see plugins/base16.lua).
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local ok, matugen = pcall(require, "matugen")
        if ok then matugen.setup() end
      end,
    },
  },
}
