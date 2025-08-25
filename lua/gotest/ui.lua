local M = {
  -- Configuration for the floating test result buffer
  test_buffer = {
    id = -1,
    lines = {}
  },

  -- Configuration for the floating test result window
  test_window = {
    id = -1,
    cfg = {}
  },
}

local function clean_opened_buffers()
  if vim.api.nvim_buf_is_valid(M.test_buffer.id) then
    vim.api.nvim_buf_delete(M.test_buffer.id, { force = true })
  end
end

M.clean_opened_buffers = clean_opened_buffers

local function toggle_test_window()
  if vim.api.nvim_win_is_valid(M.test_window.id) and M.test_window.id ~= 0 then
    M.test_window.cfg = vim.api.nvim_win_get_config(M.test_window.id)
    vim.api.nvim_win_close(M.test_window.id, true)
    return
  end

  if vim.api.nvim_buf_is_valid(M.test_buffer.id) then
    M.test_window.id = vim.api.nvim_open_win(M.test_buffer.id, true, M.test_window.cfg)
    return
  end

  print("no test window to toggle")
end

M.toggle_test_window = toggle_test_window

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

M.calculate_window_max_height = calculate_window_max_height

return M
