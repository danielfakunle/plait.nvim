-- Generated from lua/plait/schema.lua. Do not edit.

---@class PlaitCompletionConfiguration
---@field automatic? boolean
---@field documentation? "selected"|"automatic"|"off"
---@field mappings? { accept?: string|false, cancel?: string|false, next?: string|false, previous?: string|false, scroll_documentation_down?: string|false, scroll_documentation_up?: string|false, trigger?: string|false }
---@field signature_help? boolean
---@field sources? ("lsp"|"buffer"|"path"|"snippets")[]

---@class PlaitEditorConfiguration
---@field clipboard? "auto"|"system"|"osc52"|"disabled"
---@field indentation? { style?: "spaces"|"tabs", width?: integer }
---@field line_numbers? "absolute"|"relative"|"off"
---@field mappings? { clear_search?: string|false, focus_down?: string|false, focus_left?: string|false, focus_right?: string|false, focus_up?: string|false, save?: string|false }
---@field persistent_undo? boolean
---@field splits? { horizontal?: "below"|"above", vertical?: "right"|"left" }
---@field wrap? boolean
---@field yank_highlight? boolean

---@class PlaitFormattingConfiguration
---@field lsp_fallback? "if_no_formatter"|"never"
---@field mappings? { format?: string|false }
---@field on_save? boolean
---@field timeout_ms? integer

---@class PlaitLanguageConfiguration
---@field diagnostics? { severity_sort?: boolean, signs?: boolean, underline?: boolean, update_in_insert?: boolean, virtual_text?: boolean }
---@field inlay_hints? boolean
---@field mappings? { code_action?: string|false, definition?: string|false, hover?: string|false, next_diagnostic?: string|false, previous_diagnostic?: string|false, references?: string|false, rename?: string|false }

---@class PlaitToolingConfiguration
---@field check_on_startup? boolean

return {
  completion = {
    fields = {
      automatic = {
        default = true,
        type = 'boolean',
      },
      documentation = {
        default = 'selected',
        type = 'enum',
        values = {
          [1] = 'selected',
          [2] = 'automatic',
          [3] = 'off',
        },
      },
      mappings = {
        fields = {
          accept = {
            default = '<C-y>',
            type = 'mapping',
          },
          cancel = {
            default = '<C-e>',
            type = 'mapping',
          },
          next = {
            default = '<C-n>',
            type = 'mapping',
          },
          previous = {
            default = '<C-p>',
            type = 'mapping',
          },
          scroll_documentation_down = {
            default = '<C-f>',
            type = 'mapping',
          },
          scroll_documentation_up = {
            default = '<C-b>',
            type = 'mapping',
          },
          trigger = {
            default = '<C-Space>',
            type = 'mapping',
          },
        },
        type = 'map',
      },
      signature_help = {
        default = true,
        type = 'boolean',
      },
      sources = {
        default = {
          [1] = 'lsp',
          [2] = 'buffer',
          [3] = 'path',
          [4] = 'snippets',
        },
        item = {
          type = 'enum',
          values = {
            [1] = 'lsp',
            [2] = 'buffer',
            [3] = 'path',
            [4] = 'snippets',
          },
        },
        type = 'array',
      },
    },
    type = 'map',
  },
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
  formatting = {
    fields = {
      lsp_fallback = {
        default = 'if_no_formatter',
        type = 'enum',
        values = {
          [1] = 'if_no_formatter',
          [2] = 'never',
        },
      },
      mappings = {
        fields = {
          format = {
            default = '<leader>cf',
            type = 'mapping',
          },
        },
        type = 'map',
      },
      on_save = {
        default = true,
        type = 'boolean',
      },
      timeout_ms = {
        default = 1000,
        maximum = 60000,
        minimum = 1,
        type = 'integer',
      },
    },
    type = 'map',
  },
  language = {
    fields = {
      diagnostics = {
        fields = {
          severity_sort = {
            default = true,
            type = 'boolean',
          },
          signs = {
            default = true,
            type = 'boolean',
          },
          underline = {
            default = true,
            type = 'boolean',
          },
          update_in_insert = {
            default = false,
            type = 'boolean',
          },
          virtual_text = {
            default = true,
            type = 'boolean',
          },
        },
        type = 'map',
      },
      inlay_hints = {
        default = false,
        type = 'boolean',
      },
      mappings = {
        fields = {
          code_action = {
            default = '<leader>ca',
            type = 'mapping',
          },
          definition = {
            default = 'gd',
            type = 'mapping',
          },
          hover = {
            default = 'K',
            type = 'mapping',
          },
          next_diagnostic = {
            default = ']d',
            type = 'mapping',
          },
          previous_diagnostic = {
            default = '[d',
            type = 'mapping',
          },
          references = {
            default = 'gr',
            type = 'mapping',
          },
          rename = {
            default = '<leader>cr',
            type = 'mapping',
          },
        },
        type = 'map',
      },
    },
    type = 'map',
  },
  tooling = {
    fields = {
      check_on_startup = {
        default = true,
        type = 'boolean',
      },
    },
    type = 'map',
  },
}
