vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')
require('plait.packages').install_for_apply = function() return true end
local plait = require('plait')
_G.M = plait
local buffer = vim.api.nvim_get_current_buf()
_G.buffer = buffer
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { '-- hover scenario' })
local hover_client = { id = 1, supports_method = function(_, method) return method == 'textDocument/hover' end }
vim.lsp._set_defaults(hover_client, buffer)
if _G.hover_foreign then vim.keymap.set('n', 'K', function() end, { buffer = buffer, desc = 'vim.lsp.buf.hover()' }) end
_G.native_hover = vim.fn.maparg('K', 'n', false, true).callback
-- luacheck: push ignore 122
vim.lsp.get_clients = function() return { hover_client } end
-- luacheck: pop
local config = plait.config()
config:select({ 'language' })
if _G.hover_explicit then config:configure({ language = { mappings = { hover = 'K' } } }) end
_G.applied = config:apply()
