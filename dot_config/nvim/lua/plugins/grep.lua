local function get_selection_bounds()
  local mode = vim.api.nvim_get_mode().mode
  local start_row, start_col, end_row, end_col

  if mode == "v" or mode == "V" or mode == "\22" then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    start_row, start_col = start_pos[2], start_pos[3]
    end_row, end_col = end_pos[2], end_pos[3]

    if start_row > end_row or (start_row == end_row and start_col > end_col) then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end

    if mode == "V" then
      start_col = 0
      local end_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] or ""
      end_col = #end_line
    else
      -- Convert to nvim_buf_get_text coordinates: start is 0-based inclusive, end is 0-based exclusive.
      start_col = start_col - 1
    end
  else
    start_row, start_col = table.unpack(vim.api.nvim_buf_get_mark(0, "<"))
    end_row, end_col = table.unpack(vim.api.nvim_buf_get_mark(0, ">"))
    end_col = end_col + 1
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  return start_row, start_col, end_row, end_col
end

local function start_picker_in_normal_mode()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.defer_fn(function()
    vim.api.nvim_feedkeys(esc, "n", false)
  end, 10)
  vim.defer_fn(function()
    vim.api.nvim_feedkeys(esc, "n", false)
  end, 40)
end

local function search_visual_selection()
  local start_row, start_col, end_row, end_col = get_selection_bounds()

  local selection = table.concat(
    vim.api.nvim_buf_get_text(0, start_row - 1, start_col, end_row - 1, end_col, {}),
    " "
  )
  selection = vim.trim(selection)
  if selection == "" then
    return
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  if _G.Snacks and Snacks.picker and Snacks.picker.grep then
    Snacks.picker.grep({ search = selection })
    start_picker_in_normal_mode()
    return
  end

  local ok, telescope_builtin = pcall(require, "telescope.builtin")
  if ok then
    telescope_builtin.live_grep({ default_text = selection })
    start_picker_in_normal_mode()
  end
end

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        "<leader>sg",
        search_visual_selection,
        mode = "x",
        desc = "Search selection in project",
      },
    },
  },
}
