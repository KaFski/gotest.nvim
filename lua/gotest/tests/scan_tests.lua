local scanner = require("gotest.scan")

-- tests/my_spec.lua
local eq = assert.are.equal

describe("gotest basics", function()
  it("scan tests", function()
    local test_content = [[
package gotestnvim

import (
	"testing"
	"time"
)

func TestSomethinga(t *testing.T) {
	time.Sleep(time.Millisecond * 100)
	a := "asdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}

	t.Run("test 1", func(t *testing.T) {

	})

	t.Run("test 2", func(t *testing.T) {

	})
}
]]



    local lines = {}
    for line in test_content:gmatch("([^\n]+)") do
      table.insert(lines, line)
    end

    local tests = scanner.scan_tests(lines)
    print("tests:", vim.inspect(tests))
    eq("^TestSomethinga$", tests[6])
    eq("^TestSomethinga$/test 1$", tests[12])
    eq("^TestSomethinga$/test 2$", tests[14])
  end)
end)
