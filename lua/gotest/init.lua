local sign = require("gotest.sign")
local ui = require("gotest.ui")
local scanner = require("gotest.scan")
local M = {}

table.unpack = table.unpack or unpack

M.setup = function(opts)
  print("Options:", opts)
end

local outer_buffer = 0
local last_run_definiton = ""

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

local function toggle_summary()
  local bufnr = vim.api.nvim_create_buf(true, true)
  local new_window = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = vim.o.lines,
    col = vim.o.columns * 0.1,
    width = math.floor(vim.o.columns * 0.8),
    height = 8,
    border = "single",
    style = "minimal",
  })

  vim.keymap.set('n', 's', function() vim.api.nvim_win_close(new_window, true) end, { buffer = bufnr })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(new_window, true) end, { buffer = bufnr })

  local test_summary = {
    tests = {},
    passes = {},
    fails = {},
  }

  -- TODO: feels like test_buffer.lines should be moved to some state manager
  for _, line in ipairs(ui.test_buffer.lines) do
    local action, test = find_in_patterns(line, {
      "=== (RUN)   (Test.*)",
      "--- (FAIL): (Test.*) ",
      "--- (PASS): (Test.*) "
    })
    if action == "RUN" then
      table.insert(test_summary.tests, test)
    end
    if action == "FAIL" then
      table.insert(test_summary.fails, test)
    end
    if action == "PASS" then
      table.insert(test_summary.passes, test)
    end
  end

  local output = {
    string.format("Executed %d tests", #test_summary.tests),
    string.format("\t%d / %d passed ", #test_summary.passes, #test_summary.tests),
    string.format("\t%d / %d failed ", #test_summary.fails, #test_summary.tests),
  }

  for _, test in ipairs(test_summary.fails) do
    table.insert(output, string.format("\t ⨯ %s", test))
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
  vim.bo[bufnr].modifiable = false
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
        ui.toggle_test_window()
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

  ui.toggle_test_window()

  vim.api.nvim_win_set_cursor(0, { row, 0 })
end

local function next_failure()
  -- === RUN   TestAnother
  --     example_test.go:22: expected 'a', but got 's' instead
  -- --- FAIL: TestAnother (0.00s)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for i = row + 1, #ui.test_buffer.lines do
    local test = find_in_patterns(ui.test_buffer.lines[i], {
      "--- FAIL: (Test.*) ",
    })

    if test ~= nil then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end

  print("no more failures")
end

local function prev_failure()
  -- === RUN   TestAnother
  --     example_test.go:22: expected 'a', but got 's' instead
  -- --- FAIL: TestAnother (0.00s)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for i = row - 1, 1, -1 do
    local test = find_in_patterns(ui.test_buffer.lines[i], {
      "--- FAIL: (Test.*) ",
    })

    if test ~= nil then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end

  print("no previous failures")
end

---@class Opts
---@field nonverbose boolean


-- UI package state
---@param name string
---@param maxHeight number
local function open_testing_window_and_buf(name, maxHeight)
  local height = ui.calculate_window_max_height(maxHeight)

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

  vim.keymap.set('n', 'q', ui.clean_opened_buffers, { buffer = bufnr })
  vim.keymap.set('n', 'x', go_to_test, { buffer = bufnr })
  vim.keymap.set('n', 's', toggle_summary, { buffer = bufnr })
  vim.keymap.set('n', 'n', next_failure, { buffer = bufnr })
  vim.keymap.set('n', 'p', prev_failure, { buffer = bufnr })

  vim.api.nvim_buf_set_name(bufnr, name)

  ui.test_buffer.id = bufnr
  ui.test_window.id = new_window

  return new_window, bufnr
end

---@param bufnr integer
---@param lines string[]
local function append(bufnr, lines)
  for i, _ in ipairs(lines) do
    if lines[i] == "" or not lines[i]:match("%S") then
      table.remove(lines, i)
    end
  end

  if not lines then return end

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)

  -- optional autoscroll:
  local last = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(0, { last, 0 })

  for _, line in ipairs(lines) do
    table.insert(ui.test_buffer.lines, line)
  end

  local height = ui.calculate_window_max_height(#ui.test_buffer.lines)
  vim.api.nvim_win_set_height(0, height)
end

local function place_sign_column(line, result)
  vim.fn.sign_place(0, sign.group, result, outer_buffer, {
    lnum = line,
    priority = 10,
  })
end

local function clear_all_signs()
  vim.fn.sign_unplace(sign.group)
end

local function place_signs(lines)
  clear_all_signs()

  local test_file_lines = vim.api.nvim_buf_get_lines(outer_buffer, 0, -1, false)

  for _, line in ipairs(lines) do
    local result, test = find_in_patterns(line, { "--- (PASS): (Test.*) ", "--- (FAIL): (Test.*) " })
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

  return {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append(bufnr, data)
    end,
    on_stderr = function(_, data)
      append(bufnr, data)
    end,
    on_exit = function()
      place_signs(ui.test_buffer.lines)

      -- Clear first buffer emplty line
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})

      vim.bo[bufnr].modifiable = false
    end
  }
end

---@param opts Opts
---@param resource string
---@vararg string
local function assembly_job_definition(opts, resource, ...)
  local job_definition = { "go", "test", "-count=1", "-timeout=30s" }

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

---@param opts Opts
M.run_test_all = function(opts)
  opts = opts or {}
  ui.clean_opened_buffers()

  local job_definition = assembly_job_definition(opts, "./...")

  print("jobstart: ", table.unpack(job_definition))

  vim.fn.jobstart(
    job_definition,
    print_output_opts("GoTestAll")
  )
end


---@param opts Opts
M.run_test_package = function(opts)
  opts = opts or {}
  ui.clean_opened_buffers()

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
  ui.clean_opened_buffers()

  local curr_buf_name = vim.api.nvim_buf_get_name(0)
  local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local tests = scanner.scan_tests(lines)
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
  ui.clean_opened_buffers()

  print("jobstart", last_run_definiton)

  vim.fn.jobstart(
    last_run_definiton,
    print_output_opts("GoTestRerun")
  )
end


M.run_test_under_cursor = function(opts)
  opts = opts or {}
  ui.clean_opened_buffers()

  local curr_buf_name = vim.api.nvim_buf_get_name(0)
  local _, _, curr_package_name = string.find(curr_buf_name, "(.*)/.*")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local tests = scanner.scan_tests(lines)
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
  local job = table.concat(job_definition, " ") .. " -run='" .. test.name .. "'"
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
  ui.clean_opened_buffers()

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
  ui.clean_opened_buffers()
end

vim.keymap.set('n', '<leader>tf', M.run_test_file, { desc = "Run [T]est [F]ile" })
vim.keymap.set('n', '<leader>tp', M.run_test_package, { desc = 'Run [T]est [P]ackage ' })
vim.keymap.set('n', '<leader>tc', M.run_test_under_cursor, { desc = 'Run [T]est under [C]ursor ' })
vim.keymap.set('n', '<leader>tj', M.run_test_json, { desc = 'Run [T]est [J]SON' })
vim.keymap.set('n', '<leader>tr', M.run_test_rerun, { desc = 'Run [T]est [R]erun' })
vim.keymap.set('n', '<leader>ta', M.run_test_all, { desc = 'Run [T]est [A]ll' })
vim.keymap.set('n', '<C-t>', ui.toggle_test_window, { desc = '[T]est [T]oggle Window' })

return M
