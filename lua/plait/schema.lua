local M = {}

M.editor = {
  type = 'map',
  fields = {
    line_numbers = { type = 'enum', values = { 'absolute', 'relative', 'off' }, default = 'absolute' },
    persistent_undo = { type = 'boolean', default = true },
    yank_highlight = { type = 'boolean', default = true },
    splits = {
      type = 'map',
      fields = {
        horizontal = { type = 'enum', values = { 'below', 'above' }, default = 'below' },
        vertical = { type = 'enum', values = { 'right', 'left' }, default = 'right' },
      },
    },
    indentation = {
      type = 'map',
      fields = {
        style = { type = 'enum', values = { 'spaces', 'tabs' }, default = 'spaces' },
        width = { type = 'integer', minimum = 1, maximum = 16, default = 2 },
      },
    },
    wrap = { type = 'boolean', default = false },
    clipboard = { type = 'enum', values = { 'auto', 'system', 'osc52', 'disabled' }, default = 'auto' },
    mappings = {
      type = 'map',
      fields = {
        save = { type = 'mapping', default = '<C-s>' },
        clear_search = { type = 'mapping', default = '<Esc>' },
        focus_left = { type = 'mapping', default = '<C-h>' },
        focus_down = { type = 'mapping', default = '<C-j>' },
        focus_up = { type = 'mapping', default = '<C-k>' },
        focus_right = { type = 'mapping', default = '<C-l>' },
      },
    },
  },
}

return M
