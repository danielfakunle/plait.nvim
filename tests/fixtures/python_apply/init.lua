vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local bin = vim.fn.tempname()
vim.fn.mkdir(bin, 'p')
vim.fn.writefile({ '#!/bin/sh', 'echo "basedpyright 1.31.4"' }, bin .. '/basedpyright-langserver')
vim.fn.writefile({ '#!/bin/sh', 'echo "ruff 0.13.2"' }, bin .. '/ruff')
vim.fn.setfperm(bin .. '/basedpyright-langserver', 'rwxr-xr-x')
vim.fn.setfperm(bin .. '/ruff', 'rwxr-xr-x')
-- luacheck: push ignore 122
vim.env.PATH = bin .. ':' .. vim.env.PATH

package.preload.conform = function()
  return { setup = function(value) _G.conform_setup = vim.deepcopy(value) end }
end
package.preload['conform.formatters.ruff_format'] = function()
  return {
    command = 'ruff',
    args = { 'format', '--force-exclude', '--stdin-filename', '$FILENAME', '-' },
    stdin = true,
  }
end
package.preload.mason = function()
  return { setup = function() end }
end

vim.lsp.config.basedpyright = {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyrightconfig.json', 'pyproject.toml', '.git' },
  settings = { basedpyright = { analysis = { diagnosticMode = 'openFilesOnly' } } },
}
local enable = vim.lsp.enable
vim.lsp.enable = function(name)
  _G.enabled_server = name
  return enable(name, false)
end
-- luacheck: pop

require('plait.packages').install_for_apply = function() return true end

local plait = require('plait')
_G.M = plait
local python = plait.module({
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
local config = plait.config()
config:select({ 'language', 'formatting', 'tooling', python })
config:providers({
  language = {
    ['vim.lsp'] = {
      servers = {
        basedpyright = {
          settings = { basedpyright = { analysis = { typeCheckingMode = 'basic' } } },
        },
      },
    },
  },
  formatting = {
    ['conform.nvim'] = {
      formatters = { ruff = { cwd = bin } },
    },
  },
})
_G.python_apply_result = config:apply()
_G.basedpyright_config = vim.deepcopy(vim.lsp.config.basedpyright)
