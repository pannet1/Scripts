local bufnr = 285
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "hello", "world" })
vim.api.nvim_create_autocmd("BufWritePost", {
	group = vim.api.nvim_create_augroup("TjsCool", { clear = true }),
	pattern = "main.py",
	callback = function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "output of:main.py" })
		vim.fn.jobstart({ "python", "main.py" }, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
				end
			end,
		})
	end,
})
