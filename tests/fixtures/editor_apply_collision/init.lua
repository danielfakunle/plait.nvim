vim.opt.runtimepath:prepend(vim.fn.getcwd())

vim.keymap.set('n', '<leader>p', '<Cmd>echo "external"<CR>')

local M = require('plait')
_G.M = M
local config = M.config()
config:select({ 'editor' })
config:configure({
  editor = {
    mappings = {
      save = '<leader>p',
      clear_search = false,
      focus_left = false,
      focus_down = false,
      focus_up = false,
      focus_right = false,
    },
  },
})
_G.apply_result = config:apply()
