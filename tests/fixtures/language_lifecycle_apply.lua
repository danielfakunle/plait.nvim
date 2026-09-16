vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')
require('plait.packages').install_for_apply = function() return true end

local plait = require('plait')
_G.M = plait
local initial_buffers = { vim.api.nvim_get_current_buf(), vim.api.nvim_create_buf(true, false) }
_G.initial_buffers = initial_buffers
-- luacheck: push ignore 122
vim.bo[initial_buffers[1]].filetype = 'lua'
vim.bo[initial_buffers[2]].filetype = 'typescript'
vim.lsp.get_clients = function(options)
  if options and vim.list_contains(initial_buffers, options.bufnr) then
    return { { id = 1, supports_method = function(_, method) return method == 'textDocument/references' end } }
  end
  return {}
end
-- luacheck: pop
local config = plait.config()
config:select({ 'language' })
_G.lifecycle_applied = config:apply()
