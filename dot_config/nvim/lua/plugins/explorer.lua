return {
	{
		"folke/snacks.nvim",
		opts = {
			picker = {
				actions = {
					explorer_yank_relative = function(picker)
						local paths = {}
						if vim.fn.mode():find("^[vV]") then
							picker.list:select()
						end
						for _, item in ipairs(picker:selected({ fallback = true })) do
							local path = Snacks.picker.util.path(item)
							if path then
								paths[#paths + 1] = vim.fn.fnamemodify(path, ":.")
							end
						end
						picker.list:set_selected()
						vim.fn.setreg(vim.v.register or "+", table.concat(paths, "\n"), "l")
						Snacks.notify.info("Yanked " .. #paths .. " relative paths")
					end,
				},
				sources = {
					explorer = {
						win = {
							list = {
								keys = {
									["Y"] = {
										"explorer_yank_relative",
										mode = { "n", "x" },
										desc = "Yank Relative Path",
									},
								},
							},
						},
					},
				},
			},
		},
	},
}
