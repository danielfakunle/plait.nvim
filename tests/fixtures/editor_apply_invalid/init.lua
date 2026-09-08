vim.opt.runtimepath:prepend(vim.fn.getcwd())

local M = require('plait')
_G.M = M
local config = M.config()
config:select({ 'editor' })
config:configure({ editor = { wrap = 'invalid' } })
_G.apply_result = config:apply()
