vim.opt.runtimepath:prepend(vim.fn.getcwd())

local M = require('plait')
_G.M = M
local config = M.config()
config:select({ 'editor' })
vim.api.nvim_create_autocmd('User', {
  pattern = 'PlaitApplyTest',
  callback = function()
    _G.callback_apply_ok, _G.callback_apply_error = pcall(function() config:apply() end)
  end,
})
vim.api.nvim_exec_autocmds('User', { pattern = 'PlaitApplyTest' })
