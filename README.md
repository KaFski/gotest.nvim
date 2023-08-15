# gotest.nvim

## Example keymaps
vim.keymap.set('n', '<leader>tt', require 'gotest'.runTest, { desc = "Run [T]est [T]test" })
vim.keymap.set('n', '<leader>tf', require 'gotest'.runTestFile, { desc = 'Run [T]est [F]ile ' })
vim.keymap.set('n', '<leader>tp', require 'gotest'.runTestPackage, { desc = 'Run [T]est [P]ackage ' })
vim.keymap.set('n', '<leader>tc', require 'gotest'.runTestUnderCursor, { desc = 'Run [T]est under [C]ursor ' })
vim.keymap.set('n', '<leader>tj', require 'gotest'.runTestJson, { desc = 'Run [T]est with [J]SON output' })
