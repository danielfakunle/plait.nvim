local plait = require('plait')

return plait.module({
  name = 'local.lang.python',
  provides = { 'local.lang.python' },
  requires = { 'language', 'formatting', 'tooling' },
  contribute = {
    language = {
      servers = { basedpyright = { filetypes = { 'python' }, tool = 'basedpyright' } },
    },
    formatting = {
      formatters = { ruff = { tool = 'ruff' } },
      by_filetype = { python = { 'ruff' } },
    },
    tooling = {
      tools = {
        basedpyright = {
          executable = 'basedpyright-langserver',
          version = '>=1.0.0,<2.0.0',
          ownership = 'mason',
          mason = 'basedpyright',
        },
        ruff = {
          executable = 'ruff',
          version = '>=0.13.0,<0.14.0',
          ownership = 'mason',
          mason = 'ruff',
        },
      },
    },
  },
})
