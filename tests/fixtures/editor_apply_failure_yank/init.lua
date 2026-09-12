vim.opt.runtimepath:prepend(vim.fn.getcwd())

local M = require('plait')
_G.M = M
local editor = require('plait.editor')
local apply_effect = editor.apply_effect
editor.apply_effect = function(identity, configuration)
  if identity == 'editor/yank-highlight' then error('token=SECRET yank failure') end
  return apply_effect(identity, configuration)
end

local config = M.config()
config:select({ 'editor' })
config:configure({ editor = { yank_highlight = true } })
_G.apply_result = config:apply()
