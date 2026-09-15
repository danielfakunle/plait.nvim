vim.opt.runtimepath:prepend(vim.fn.getcwd())

local config = require('plait').config()
config:select({ 'editor' })
config:configure({ editor = { mappings = { message_pager = false } } })
_G.apply_result = config:apply()
