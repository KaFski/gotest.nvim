local M = {}

---@param lines string[]
---@return string[]: list of scanned tests
M.scan_tests = function(lines)
  local tests = {}
  local parent_line = 0

  for line, d in ipairs(lines) do
    -- func TestAnswerServiceUnitSuite(t *testing.T) {
    local _, _, captured = string.find(d, "func (Test.*)%(t %*testing%.T%) {")
    if captured then
      table.insert(tests, line, '^' .. captured .. '$')
      parent_line = line
    end

    -- t.Run("test 1", func(t *testing.T) {
    local _, _, captured_subtest = string.find(d, 't%.Run%("(.*)", func%(t %*testing%.T%) {')
    if captured_subtest then
      local parent_test = tests[parent_line] or ""
      table.insert(tests, line, parent_test .. "/" .. captured_subtest .. '$')
    end
  end

  return tests
end

return M
