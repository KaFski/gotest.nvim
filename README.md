# gotest.nvim
Simple plugin that allows to run test either from code file or test file. 
Still in progress...

## Provided keymaps
```lua
vim.keymap.set('n', '<leader>tf', M.runTestFile, { desc = "Run [T]est [F]ile" })
vim.keymap.set('n', '<leader>tp', M.runTestPackage, { desc = 'Run [T]est [P]ackage ' })
vim.keymap.set('n', '<leader>tc', M.runTestUnderCursor, { desc = 'Run [T]est under [C]ursor ' })
vim.keymap.set('n', '<leader>tj', M.runTestJson, { desc = 'Run [T]est [J]SON' })
vim.keymap.set('n', '<leader>tr', M.runTestRerun, { desc = 'Run [T]est [R]erun' })
vim.keymap.set('n', '<C-t>', test_toggle_window, { desc = '[T]est [T]oggle Window' })
```

When test floating widnos is opened, you can use the following keymaps to close floating window navigate to test:
```lua
vim.keymap.set('n', 'q', clean_opened_buffers, { buffer = bufnr })
vim.keymap.set('n', 'x', go_to_test, { buffer = bufnr })
```

