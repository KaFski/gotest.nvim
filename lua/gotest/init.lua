local M = {}

table.unpack = table.unpack or unpack

M.setup = function(opts)
	print("Options:", opts)
end

-- Define a unique sign name
local pass = "PASS"
local fail = "FAIL"

vim.fn.sign_define(pass, {
	text = "✓", -- The tick symbol
	texthl = "GreenTickHighlight", -- Highlight group for the tick
	numhl = "", -- No number column highlight
})
vim.api.nvim_set_hl(0, "GreenTickHighlight", { fg = "#33CC33" })

vim.fn.sign_define(fail, {
	text = "x",                -- The tick symbol
	texthl = "RedCrossHighlight", -- Highlight group for the tick
	numhl = "",                -- No number column highlight
})
vim.api.nvim_set_hl(0, "RedCrossHighlight", { fg = "#CC3333" })

local outer_buffer = 0
local test_buffer = {
	id = -1
}
local test_window = {
	id = -1,
	cfg = {}
}
local last_run_definiton = ""


local function clean_opened_buffers()
	if vim.api.nvim_buf_is_valid(test_buffer.id) then
		vim.api.nvim_buf_delete(test_buffer.id, { force = true })
	end
end

---@param line string
---@param patterns string[]
---@return string|nil captured test name with result (PASS/FAIL) or nil if not found
local function find_in_patterns(line, patterns)
	for _, pattern in ipairs(patterns) do
		local captured = { line:match(pattern) }
		if #captured > 0 and captured ~= nil then
			return table.unpack(captured)
		end
	end

	return nil
end

local function test_toggle_window()
	if vim.api.nvim_win_is_valid(test_window.id) and test_window.id ~= 0 then
		test_window.cfg = vim.api.nvim_win_get_config(test_window.id)
		vim.api.nvim_win_close(test_window.id, true)
		return
	end

	if vim.api.nvim_buf_is_valid(test_buffer.id) then
		test_window.id = vim.api.nvim_open_win(test_buffer.id, true, test_window.cfg)
		return
	end

	print("no test window to toggle")
end

local function go_to_test()
	-- === RUN   TestSomethinga
	-- === RUN   TestSomethinga/test_1
	-- === RUN   TestSomethinga/test_2
	-- --- PASS: TestSomethinga (0.00s)
	--     --- PASS: TestSomethinga/test_1 (0.00s)
	--     --- PASS: TestSomethinga/test_2 (0.00s)
	-- === RUN   TestAnother
	--     example_test.go:22: expected 'a', but got 's' instead
	-- --- FAIL: TestAnother (0.00s)
	local test = find_in_patterns(vim.api.nvim_get_current_line(), {
		"=== RUN   (Test.*)",
		"--- FAIL: (Test.*) ",
		"--- PASS: (Test.*) "
	})

	if test ~= nil then
		local lines = vim.api.nvim_buf_get_lines(outer_buffer, 0, -1, false)

		for row, content in ipairs(lines) do
			if content:find("func " .. test .. "%(") then
				test_toggle_window()
				vim.api.nvim_win_set_cursor(0, { row, 0 })
				return
			end
		end
	end

	-- === RUN   TestAnother
	--     example_test.go:22: expected 'a', but got 's' instead
	local _, _, _, row = vim.api.nvim_get_current_line():find("(.*_test.go):(%d+):")

	row = tonumber(row)
	if not row then
		print("no valid test line captured")
		return
	end

	test_toggle_window()

	vim.api.nvim_win_set_cursor(0, { row, 0 })
end


---@class Opts
---@field nonverbose boolean

-- Calculate height of the windows so it's not more than 50% of the screen
---@param rows number
local function calculate_window_max_height(rows)
	local height = math.ceil(vim.o.lines / 2)

	if rows > height then
		return height
	elseif rows < 5 then
		return 5
	end

	return rows
end

---@param name string
---@param maxHeight number
local function open_testing_window_and_buf(name, maxHeight)
	local height = calculate_window_max_height(maxHeight)

	outer_buffer = vim.api.nvim_get_current_buf()
	local bufnr = vim.api.nvim_create_buf(true, true)
	local new_window = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		row = vim.o.lines,
		col = vim.o.columns * 0.1,
		width = math.floor(vim.o.columns * 0.8),
		height = height,
		border = "single",
		style = "minimal",
	})

	vim.keymap.set('n', 'q', clean_opened_buffers, { buffer = bufnr })
	vim.keymap.set('n', 'x', go_to_test, { buffer = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test now..." })
	vim.api.nvim_buf_set_name(bufnr, name)

	test_buffer.id = bufnr
	test_window.id = new_window

	return new_window, bufnr
end

---@param data string[]
---@param messages string[]
local function append_to_messages(data, messages)
	if #data >= 1 then
		for _, line in ipairs(data) do
			table.insert(messages, line)
		end
	end
end

local function place_sign_column(line, result)
	print("place sign", line, result)
	-- Place the sign on the specified line
	vim.fn.sign_place(0, "TickSignsGroup", result, outer_buffer, {
		lnum = line, -- Line number where the tick should appear
		priority = 10, -- Priority for display (higher = displayed on top)
	})
end

local function clear_all_signs()
	-- Unplace all signs from the group "TickSignsGroup" in all buffers
	vim.fn.sign_unplace("TickSignsGroup")
end

local function place_signs(lines)
	clear_all_signs()

	local test_file_lines = vim.api.nvim_buf_get_lines(outer_buffer, 0, -1, false)

	for _, line in ipairs(lines) do
		local result, test = find_in_patterns(line, { "--- (PASS): (Test.*) ", "--- (FAIL): (Test.*) " })
		print("result: ", result, "test: ", test)
		for row, content in ipairs(test_file_lines) do
			if test then
				if content:find("func " .. test .. "%(") then
					place_sign_column(row, result)
				end
			end
		end
	end
end

---@param name string
local function print_output_opts(name)
	local _, bufnr = open_testing_window_and_buf(name, 10)
	local messages = {}

	return {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			append_to_messages(data, messages)
		end,
		on_stderr = function(_, data)
			append_to_messages(data, messages)
		end,
		on_exit = function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, messages)
			place_signs(messages)

			local height = calculate_window_max_height(#messages)
			vim.api.nvim_win_set_height(0, height)
			vim.bo[bufnr].modifiable = false
		end
	}
end

---@param opts Opts
---@param resource string
---@vararg string
local function assembly_job_definition(opts, resource, ...)
	local job_definition = { "go", "test" }

	if not opts.nonverbose then
		table.insert(job_definition, "-v")
	end

	table.insert(job_definition, resource)

	local vararg = { ... }
	for _, value in ipairs(vararg) do
		table.insert(job_definition, value)
	end

	return job_definition
end

---@param lines string[]
---@return string[]: list of scanned tests
local function scan_tests(lines)
	local tests = {}

	for line, d in ipairs(lines) do
		-- func TestAnswerServiceUnitSuite(t *testing.T) {
		local _, _, captured = string.find(d, "func (Test.*)%(t %*testing%.T%) {")
		if captured then
			table.insert(tests, line, captured)
		end
	end

	return tests
end


---@param opts Opts
M.run_test_package = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local job_definition = assembly_job_definition(opts, curr_package_name)

	print("jobstart: ", table.unpack(job_definition))

	vim.fn.jobstart(
		job_definition,
		print_output_opts("GoTestPackage")
	)
end


-- This requires some additional work
---@param opts Opts
M.run_test_file = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local tests = scan_tests(lines)
	if next(tests) == nil then
		print("no tests found")
		return
	end

	local file_tests = {}
	for _, test in pairs(tests) do
		table.insert(file_tests, test)
	end

	local job_definition = assembly_job_definition(opts, curr_package_name)
	local job = table.concat(job_definition, " ") .. " -run='(" .. table.concat(file_tests, "|") .. ")'"
	print("jobstart", job)

	last_run_definiton = job

	vim.fn.jobstart(
		job,
		print_output_opts("GoTestFile")
	)
end

M.run_test_rerun = function()
	clean_opened_buffers()

	print("jobstart", last_run_definiton)

	vim.fn.jobstart(
		last_run_definiton,
		print_output_opts("GoTestRerun")
	)
end


M.run_test_under_cursor = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local tests = scan_tests(lines)
	if next(tests) == nil then
		print("no tests found")
		return
	end

	local test = { line = 0, name = "" }
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	for test_line, test_name in pairs(tests) do
		if test_line >= test.line and test_line <= cursor_line then
			test = { name = test_name, line = test_line }
		end
	end

	local job_definition = assembly_job_definition(opts, curr_package_name)
	local job = table.concat(job_definition, " ") .. " -run='(" .. test.name .. ")'"
	print("jobstart", job)

	last_run_definiton = job

	vim.fn.jobstart(
		job,
		print_output_opts("GoTestFunction")
	)
end

---@param opts Opts
M.run_test_json = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local job_definition = assembly_job_definition(opts, curr_package_name, "-json")

	print("jobstart: ", table.unpack(job_definition))

	vim.fn.jobstart(
		job_definition,
		print_output_opts("GoTestJson")
	)
end


M.cleanup = function()
	clean_opened_buffers()
end

vim.keymap.set('n', '<leader>tf', M.run_test_file, { desc = "Run [T]est [F]ile" })
vim.keymap.set('n', '<leader>tp', M.run_test_package, { desc = 'Run [T]est [P]ackage ' })
vim.keymap.set('n', '<leader>tc', M.run_test_under_cursor, { desc = 'Run [T]est under [C]ursor ' })
vim.keymap.set('n', '<leader>tj', M.run_test_json, { desc = 'Run [T]est [J]SON' })
vim.keymap.set('n', '<leader>tr', M.run_test_rerun, { desc = 'Run [T]est [R]erun' })
vim.keymap.set('n', '<C-t>', test_toggle_window, { desc = '[T]est [T]oggle Window' })

return M
