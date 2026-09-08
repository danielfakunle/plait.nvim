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

M.language = {
  type = 'map',
  fields = {
    diagnostics = {
      type = 'map',
      fields = {
        signs = { type = 'boolean', default = true },
        underline = { type = 'boolean', default = true },
        virtual_text = { type = 'boolean', default = true },
        severity_sort = { type = 'boolean', default = true },
        update_in_insert = { type = 'boolean', default = false },
      },
    },
    inlay_hints = { type = 'boolean', default = false },
    mappings = {
      type = 'map',
      fields = {
        definition = { type = 'mapping', default = 'gd' },
        references = { type = 'mapping', default = 'gr' },
        hover = { type = 'mapping', default = 'K' },
        rename = { type = 'mapping', default = '<leader>cr' },
        code_action = { type = 'mapping', default = '<leader>ca' },
        previous_diagnostic = { type = 'mapping', default = '[d' },
        next_diagnostic = { type = 'mapping', default = ']d' },
      },
    },
  },
}

M.completion = {
  type = 'map',
  fields = {
    automatic = { type = 'boolean', default = true },
    sources = {
      type = 'array',
      item = { type = 'enum', values = { 'lsp', 'buffer', 'path', 'snippets' } },
      default = { 'lsp', 'buffer', 'path', 'snippets' },
    },
    documentation = { type = 'enum', values = { 'selected', 'automatic', 'off' }, default = 'selected' },
    signature_help = { type = 'boolean', default = true },
    mappings = {
      type = 'map',
      fields = {
        trigger = { type = 'mapping', default = '<C-Space>' },
        next = { type = 'mapping', default = '<C-n>' },
        previous = { type = 'mapping', default = '<C-p>' },
        accept = { type = 'mapping', default = '<C-y>' },
        cancel = { type = 'mapping', default = '<C-e>' },
        scroll_documentation_down = { type = 'mapping', default = '<C-f>' },
        scroll_documentation_up = { type = 'mapping', default = '<C-b>' },
      },
    },
  },
}

M.formatting = {
  type = 'map',
  fields = {
    on_save = { type = 'boolean', default = true },
    timeout_ms = { type = 'integer', minimum = 1, maximum = 60000, default = 1000 },
    lsp_fallback = { type = 'enum', values = { 'if_no_formatter', 'never' }, default = 'if_no_formatter' },
    mappings = {
      type = 'map',
      fields = {
        format = { type = 'mapping', default = '<leader>cf' },
      },
    },
  },
}

M.tooling = {
  type = 'map',
  fields = {
    check_on_startup = { type = 'boolean', default = true },
  },
}

return M
