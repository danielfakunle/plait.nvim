vim.opt.runtimepath:prepend(vim.fn.getcwd())

local M = require('plait')
_G.M = M
local config = M.config()
_G.config = config
config:select({ 'editor' })
local keymap_set = vim.keymap.set
rawset(vim.keymap, 'set', function() error('token=SECRET raw failure') end)
_G.apply_result = config:apply()
rawset(vim.keymap, 'set', keymap_set)
