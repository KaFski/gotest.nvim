local M = {}

table.unpack = table.unpack or unpack -- 5.1 compatibility

M.setup = function(opts)
	print("Options:", opts)
end

local opened = {}

-- TODO: Calculate height of the windows so it's not more than 50% of the screen
local function calculate_window_height(window, data)
	local w_height = vim.api.nvim_win_get_height(window)
	-- TODO handle nil cases, but why  data would be nil at this point?
	local size = #data + 1 or 0
	local half_w_height = math.ceil(w_height / 2)

	if size > half_w_height then
		size = half_w_height
	elseif size < 5 then
		size = 5
	end

	return size
end

local function open_testing_window_and_buf(name, data)
	local curr_window = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_create_buf(true, true)
	local new_window = vim.api.nvim_open_win(
		bufnr, true, { relative = 'win', row = 90, col = 0, width = 250, height = 20, border = 'single' }
	)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test now..." })
	vim.api.nvim_buf_set_name(bufnr, name)

	if data ~= nil then
		local height = calculate_window_height(curr_window, data)
		vim.api.nvim_win_set_height(new_window, height)
	end


	table.insert(opened, bufnr)

	return new_window, bufnr
end

local function print_on_stdout(data, bufnr)
	if #data >= 1 then
		-- TOOD: Maybe would be good to make it easily modifalbe/dragable by w mouse?
		-- local height = calculate_window_height(curr_window, data)
		-- vim.api.nvim_win_set_height(new_window, height)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
	end
end

local function print_on_stderr(data, bufnr)
	if #data >= 1 then
		-- local height = calculate_window_height(curr_window, data)
		-- vim.api.nvim_win_set_height(new_window, height)
		vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, data)
	end
end

local function clean_opened_buffers()
	for idx, buf in ipairs(opened) do
		vim.api.nvim_buf_delete(buf, {})
		table.remove(opened, idx)
	end
end

local function print_test_output(name, curr_window)
	return {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			local window, bufnr = open_testing_window_and_buf(name)
			print("success print output bufnr:" .. bufnr .. "#data" .. #data)
			print_on_stdout(data, bufnr)
		end,
		on_stderr = function(_, data)
			local window, bufnr = open_testing_window_and_buf(name)
			print("error print output bufnr:" .. bufnr .. "#data" .. #data)
			print_on_stderr(data, bufnr)
		end,
	}
end

-- This requires some additional work
M.runTestUnderCursor = function()
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local curr_window = vim.api.nvim_get_current_win()
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local tests = {}
	for _, d in ipairs(lines) do
		-- func TestAnswerServiceUnitSuite(t *testing.T) {
		local _, _, captured = string.find(d, "func (Test.*)%(t %*testing%.T%) {")
		if captured then
			print("found a test function2: ", captured)
			table.insert(tests, captured)
		end
	end

	-- TODO: Need to test it since for some reason we just pick the first test suite.
	if next(tests) == nil then
		print("no tests found")
		return
	end

	-- local window, bufnr = open_testing_window_and_buf("GoTestFunction")

	vim.fn.jobstart(
		{ "go", "test", "-v", curr_package_name, "-run", table.unpack(tests) },
		print_test_output("GoTestFunction", curr_window)
	)
end



-- local curr_window = vim.api.nvim_get_current_win()
-- local window, bufnr = open_testing_window_and_buf("GoTest")
-- local bufnr = vim.api.nvim_create_buf(true, true)
-- local window = vim.api.nvim_open_win(bufnr, true, { relative = 'win', row = 90, col = 0, width = 250, height = 20 })
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test..." })
-- vim.api.nvim_buf_set_name(bufnr, "GoTest")
--
-- table.insert(opened, bufnr)
M.runTest = function()
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)

	print("jobstart: ", "go test" .. curr_buf_name)

	vim.fn.jobstart(
		{ "go", "test", curr_buf_name },
		print_test_output("GoTest", curr_window)
	)
end

M.runTestFile = function()
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local curr_window = vim.api.nvim_get_current_win()

	-- local bufnr = vim.api.nvim_create_buf(true, true)
	-- local window = vim.api.nvim_open_win(bufnr, true,
	-- 	{ relative = 'win', row = 90, col = 0, width = 250, height = 1, border = 'single' })
	-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test..." })
	-- vim.api.nvim_buf_set_name(bufnr, "GoTestFile")
	-- table.insert(opened, bufnr)
	--
	-- print("executing go test now...")
	--
	-- vim.fn.jobstart({ "go", "test", "-v", curr_buf_name }, {
	-- 	stdout_buffered = true,
	-- 	stderr_buffered = true,
	-- 	on_stdout = function(_, data)
	-- 		print_on_stdout(data, curr_window, window, bufnr)
	-- 	end,
	-- 	on_stderr = function(_, data)
	-- 		print_on_stderr(data, curr_window, window, bufnr)
	-- 	end,
	-- })

	-- local window, bufnr = open_testing_window_and_buf("GoTestFile")

	vim.fn.jobstart(
		{ "go", "test", "-v", curr_buf_name },
		print_test_output("GoTestFile", curr_window)
	)
end


M.runTestPackage = function()
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local curr_window = vim.api.nvim_get_current_win()
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")

	-- local bufnr = vim.api.nvim_create_buf(true, true)
	-- local window = vim.api.nvim_open_win(bufnr, true,
	-- 	{ relative = 'win', row = 90, col = 0, width = 250, height = 1, border = 'single' })
	-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test..." })
	-- vim.api.nvim_buf_set_name(bufnr, "GoTestPackage")
	-- table.insert(opened, bufnr)
	--
	-- print("executing go test now...")
	--
	-- vim.fn.jobstart({ "go", "test", "-v", curr_package_name }, {
	-- 	stdout_buffered = true,
	-- 	stderr_buffered = true,
	-- 	on_stdout = function(_, data)
	-- 		print_on_stdout(data, curr_window, window, bufnr)
	-- 	end,
	-- 	on_stderr = function(_, data)
	-- 		print_on_stderr(data, curr_window, window, bufnr)
	-- 	end,
	-- })

	-- local window, bufnr = open_testing_window_and_buf("GoTestPackage")

	vim.fn.jobstart(
		{ "go", "test", "-v", curr_package_name },
		print_test_output("GoTestPackage", curr_window)
	)
end

M.runTestJson = function()
	clean_opened_buffers()

	local curr_buf_name = vim.api.nvim_buf_get_name(0)
	local curr_window = vim.api.nvim_get_current_win()
	local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")

	local bufnr = vim.api.nvim_create_buf(true, true)
	local window = vim.api.nvim_open_win(bufnr, true,
		{ relative = 'win', row = 90, col = 0, width = 250, height = 1, border = 'single' })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "running test..." })
	vim.api.nvim_buf_set_name(bufnr, "GoTestPackageJson")
	table.insert(opened, bufnr)

	print("executing go test now...")

	vim.fn.jobstart({ "go", "test", "-v", "-json", curr_package_name }, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end

			for i, value in ipairs(data) do
				local decoded = vim.json.decode(value)
				print("decoded:", decoded)
				local height = calculate_window_height(curr_window, data)
				vim.api.nvim_win_set_height(window, height)
				-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
			end
		end,
		on_stderr = function(_, data)
			print_on_stderr(data, curr_window, window, bufnr)
		end,
	})
end

M.cleanup = function()
	clean_opened_buffers()
end


-- Probably I need to find go.mod file and extract module name for it, in order to run package test,
-- then I need to also add possiblility to specify which test I want to run with -run test flag.

return M
