local M = {
	group = "ResultSignGroup"
}

-- Define a unique sign name
local pass = "PASS"
local fail = "FAIL"

local hl = vim.api.nvim_get_hl(0, { name = "SignColumn" })

vim.fn.sign_define(pass, {
	text = "✓",
	texthl = "GreenTickHighlight",
	numhl = "",
})
vim.api.nvim_set_hl(0, "GreenTickHighlight", { fg = "#33CC33", bg = hl.bg, bold = true })

vim.fn.sign_define(fail, {
	text = "⨯",
	texthl = "RedCrossHighlight",
	numhl = "",
})
vim.api.nvim_set_hl(0, "RedCrossHighlight", { fg = "#CC3333", bg = hl.bg, bold = true })

return M
