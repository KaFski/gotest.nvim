local M = {}

table.unpack = table.unpack or unpack -- 5.1 compatibility

M.setup = function(opts)
	print("Options:", opts)
end

local opened = {}
local last_window = 0

-- Calculate height of the windows so it's not more than 50% of the screen
local function calculate_window_max_height(window, size)
	local w_height = vim.api.nvim_win_get_height(window)
	local half_w_height = math.ceil(w_height / 2)

	if size > half_w_height then
		size = half_w_height
	elseif size < 5 then
		size = 5
	end

	return size
end

local function open_testing_window_and_buf(name, maxHeight)
	local curr_window = vim.api.nvim_get_current_win()
	last_window = curr_window
	local bufnr = vim.api.nvim_create_buf(true, true)
	vim.cmd('botright split')
	local new_window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(new_window, bufnr)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test now..." })
	vim.api.nvim_buf_set_name(bufnr, name)

	local height = calculate_window_max_height(curr_window, maxHeight)
	vim.api.nvim_win_set_height(new_window, height)

	table.insert(opened, bufnr)

	return new_window, bufnr
end

local function print_on_stdout(data, bufnr, messages)
	if #data >= 1 then
		for _, line in ipairs(data) do
			table.insert(messages, line)
		end
	end
end

local function print_on_stderr(data, bufnr, messages)
	if #data >= 1 then
		for _, line in ipairs(data) do
			table.insert(messages, line)
		end
	end
end

local function clean_opened_buffers()
	for idx, buf in ipairs(opened) do
		vim.api.nvim_buf_delete(buf, {})
		table.remove(opened, idx)
	end
end

local function print_output_opts(name)
	local _, bufnr = open_testing_window_and_buf(name, 10)
	local messages = {}

	return {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			print_on_stdout(data, bufnr, messages)
		end,
		on_stderr = function(_, data)
			print_on_stderr(data, bufnr, messages)
		end,
		on_exit = function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, messages)
			local height = calculate_window_max_height(last_window, #messages)
			vim.api.nvim_win_set_height(0, height)
		end
	}
end


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

M.runTestFile = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local job_definition = assembly_job_definition(opts, curr_buf_name)

	print("jobstart: ", table.unpack(job_definition))

	vim.fn.jobstart(
		job_definition,
		print_output_opts("GoTestFile")
	)
end


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
M.runTestUnderCursor = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local tests = {}
	for _, d in ipairs(lines) do
		-- func TestAnswerServiceUnitSuite(t *testing.T) {
		local _, _, captured = string.find(d, "func (Test.*)%(t %*testing%.T%) {")
		if captured then
			print("found a test function: ", captured)
			table.insert(tests, captured)
		end
	end

	if next(tests) == nil then
		print("no tests found")
		return
	end

	local job_definition = assembly_job_definition(opts, curr_package_name)
	local job_definition_concat = table.concat(job_definition, " ") .. " -run='(" .. table.concat(tests, "|") .. ")'"
	print("jobstart", job_definition_concat)

	vim.fn.jobstart(
		job_definition_concat,
		print_output_opts("GoTestFunction")
	)
end

M.runTestJson = function(opts)
	opts = opts or {}
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local job_definition = assembly_job_definition(opts, curr_package_name, "-json")

	print("jobstart: ", table.unpack(job_definition))

	vim.fn.jobstart(
		job_definition,
		print_output_opts("GoTestPackageJson")
	)
end

M.cleanup = function()
	clean_opened_buffers()
end

return M
