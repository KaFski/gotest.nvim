local M = {}

M.setup = function(opts)
	print("Options:", opts)
end

local outer_buffer = 0
local test_buffers = {}
local last_run_definiton = ""

local function clean_opened_buffers()
	for idx, buf in ipairs(test_buffers) do
		vim.api.nvim_buf_delete(buf, {})
		table.remove(test_buffers, idx)
	end
end

local function find_in_patterns(line, patterns)
	for _, pattern in ipairs(patterns) do
		local _, _, captured = line:find(pattern)
		if captured then
			return captured
		end
	end

	return nil
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
	--
	local test = find_in_patterns(vim.api.nvim_get_current_line(), {
		"=== RUN   (Test.*)",
		"--- FAIL: (Test.*) ",
		"--- PASS: (Test.*) "
	})

	if test ~= nil then
		local lines = vim.api.nvim_buf_get_lines(outer_buffer, 0, -1, false)

		for row, content in ipairs(lines) do
			if content:find("func " .. test .. "%(") then
				clean_opened_buffers()
				vim.api.nvim_win_set_cursor(0, { row, 0 })
				return
			end
		end
	end

	-- === RUN   TestAnother
	--     example_test.go:22: expected 'a', but got 's' instead
	local _, _, file, row = vim.api.nvim_get_current_line():find("(.*_test.go):(%d+):")

	row = tonumber(row)
	if not row then
		print("no valid test line captured")
		return
	end

	clean_opened_buffers()

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
	outer_buffer = vim.api.nvim_get_current_buf()
	local bufnr = vim.api.nvim_create_buf(true, true)
	local new_window = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		row = vim.o.lines,
		col = vim.o.columns * 0.1,
		width = math.floor(vim.o.columns * 0.8),
		height = vim.o.lines - 10,
		border = "single",
		style = "minimal",
	})

	vim.keymap.set('n', 'q', clean_opened_buffers, { buffer = bufnr })
	vim.keymap.set('n', 'x', go_to_test, { buffer = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test now..." })
	vim.api.nvim_buf_set_name(bufnr, name)

	local height = calculate_window_max_height(maxHeight)
	vim.api.nvim_win_set_height(new_window, height)

	table.insert(test_buffers, bufnr)

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
M.runTestPackage = function(opts)
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
M.runTestFile = function(opts)
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

M.runTestRerun = function()
	clean_opened_buffers()

	print("jobstart", last_run_definiton)

	vim.fn.jobstart(
		last_run_definiton,
		print_output_opts("GoTestRerun")
	)
end


M.runTestUnderCursor = function(opts)
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
M.runTestJson = function(opts)
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

vim.keymap.set('n', '<leader>tf', M.runTestFile, { desc = "Run [T]est [F]ile" })
vim.keymap.set('n', '<leader>tp', M.runTestPackage, { desc = 'Run [T]est [P]ackage ' })
vim.keymap.set('n', '<leader>tc', M.runTestUnderCursor, { desc = 'Run [T]est under [C]ursor ' })
vim.keymap.set('n', '<leader>tj', M.runTestJson, { desc = 'Run [T]est [J]SON' })
vim.keymap.set('n', '<leader>tr', M.runTestRerun, { desc = 'Run [T]est [R]erun' })

return M
