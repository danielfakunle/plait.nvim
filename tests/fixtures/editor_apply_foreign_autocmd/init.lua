vim.opt.runtimepath:prepend(vim.fn.getcwd())

local group = vim.api.nvim_create_augroup('external.yank_highlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', { group = group, pattern = '*', callback = function() end })

local M = require('plait')
_G.M = M
local config = M.config()
config:select({ 'editor' })
config:configure({
  editor = {
    yank_highlight = true,
    mappings = {
      save = false,
      clear_search = false,
      focus_left = false,
      focus_down = false,
      focus_up = false,
      focus_right = false,
    },
  },
})
_G.apply_result = config:apply()
