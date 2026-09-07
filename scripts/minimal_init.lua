-- Make the checkout available to both the test runner and child Neovim processes.
vim.opt.runtimepath:prepend(vim.fn.getcwd())

if #vim.api.nvim_list_uis() == 0 then
  vim.opt.runtimepath:append('deps/mini.nvim')

  require('mini.test').setup({
    collect = {
      find_files = function() return vim.fn.globpath('tests', '**/test_*.lua', true, true) end,
    },
  })
end
