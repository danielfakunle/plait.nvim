vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')
require('plait.packages').install_for_apply = function() return true end
package.preload['blink.cmp'] = function()
  return { setup = function() end, is_active = function() return false end }
end
local plait = require('plait')
_G.M = plait
local config = plait.config()
config:select({ 'editor', 'language', 'completion' })
config:configure({
  operation_feedback = vim.g.feedback_policy or 'info',
  editor = {
    wrap = vim.g.feedback_invalid and 'invalid' or false,
    persistent_undo = false,
    yank_highlight = false,
    mappings = { clear_search = '<F4>' },
  },
})
_G.feedback_application = config:apply()
