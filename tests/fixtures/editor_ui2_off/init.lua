vim.opt.runtimepath:prepend(vim.fn.getcwd())

local config = require('plait').config()
config:select({ 'editor' })
config:configure({ editor = { ui2 = false } })
_G.apply_result = config:apply()
