-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- With no graphical session (Rex, SSH) there is no local clipboard tool, so
-- yanks go to the terminal's clipboard with OSC 52. Neovim won't pick OSC 52
-- by itself while 'clipboard' is set, so name it here.
-- Pastes come from Neovim's own register: reading the clipboard over OSC 52
-- is slow, and many terminals block it.
if not vim.env.DISPLAY and not vim.env.WAYLAND_DISPLAY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
  vim.opt.clipboard = "unnamedplus"
end
