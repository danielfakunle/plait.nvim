vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. '/tests/fixtures/editor_apply_plugin/runtime')

local M = require('plait')
_G.M = M
_G.config = M.config()
_G.config:select({ 'editor' })
