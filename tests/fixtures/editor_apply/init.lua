vim.opt.runtimepath:prepend(vim.fn.getcwd())

local M = require('plait')
_G.M = M
_G.enter_mapping_before = vim.inspect(vim.fn.maparg('<CR>', 'i', false, true))
_G.tab_mapping_before = vim.inspect(vim.fn.maparg('<Tab>', 'i', false, true))
local config = M.config()
config:select({ 'editor' })
_G.validation = config:validate()
config:configure({
  editor = {
    line_numbers = 'relative',
    persistent_undo = false,
    yank_highlight = false,
    splits = { horizontal = 'above', vertical = 'left' },
    indentation = { style = 'tabs', width = 4 },
    wrap = true,
    clipboard = 'osc52',
    mappings = {
      save = '<leader>w',
      clear_search = false,
      focus_left = false,
    },
  },
})
_G.apply_result = config:apply()
