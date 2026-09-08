-- Generated from lua/plait/schema.lua. Do not edit.

---@class PlaitEditorConfiguration
---@field clipboard? "auto"|"system"|"osc52"|"disabled"
---@field indentation? { style?: "spaces"|"tabs", width?: integer }
---@field line_numbers? "absolute"|"relative"|"off"
---@field mappings? { clear_search?: string|false, focus_down?: string|false, focus_left?: string|false, focus_right?: string|false, focus_up?: string|false, save?: string|false }
---@field persistent_undo? boolean
---@field splits? { horizontal?: "below"|"above", vertical?: "right"|"left" }
---@field wrap? boolean
---@field yank_highlight? boolean

return {
  editor = {
    fields = {
      clipboard = {
        default = 'auto',
        type = 'enum',
        values = {
          [1] = 'auto',
          [2] = 'system',
          [3] = 'osc52',
          [4] = 'disabled',
        },
      },
      indentation = {
        fields = {
          style = {
            default = 'spaces',
            type = 'enum',
            values = {
              [1] = 'spaces',
              [2] = 'tabs',
            },
          },
          width = {
            default = 2,
            maximum = 16,
            minimum = 1,
            type = 'integer',
          },
        },
        type = 'map',
      },
      line_numbers = {
        default = 'absolute',
        type = 'enum',
        values = {
          [1] = 'absolute',
          [2] = 'relative',
          [3] = 'off',
        },
      },
      mappings = {
        fields = {
          clear_search = {
            default = '<Esc>',
            type = 'mapping',
          },
          focus_down = {
            default = '<C-j>',
            type = 'mapping',
          },
          focus_left = {
            default = '<C-h>',
            type = 'mapping',
          },
          focus_right = {
            default = '<C-l>',
            type = 'mapping',
          },
          focus_up = {
            default = '<C-k>',
            type = 'mapping',
          },
          save = {
            default = '<C-s>',
            type = 'mapping',
          },
        },
        type = 'map',
      },
      persistent_undo = {
        default = true,
        type = 'boolean',
      },
      splits = {
        fields = {
          horizontal = {
            default = 'below',
            type = 'enum',
            values = {
              [1] = 'below',
              [2] = 'above',
            },
          },
          vertical = {
            default = 'right',
            type = 'enum',
            values = {
              [1] = 'right',
              [2] = 'left',
            },
          },
        },
        type = 'map',
      },
      wrap = {
        default = false,
        type = 'boolean',
      },
      yank_highlight = {
        default = true,
        type = 'boolean',
      },
    },
    type = 'map',
  },
}
