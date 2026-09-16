vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/node_modules/.bin', 'p')
vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.66.0"' }, root .. '/node_modules/.bin/oxfmt')
vim.fn.setfperm(root .. '/node_modules/.bin/oxfmt', 'rwxr-xr-x')
vim.cmd.cd(root)
package.preload.conform = function()
  return { setup = function(options) _G.conform_setup = options end }
end
package.preload['conform.formatters.oxfmt'] = function()
  return { command = function() return 'oxfmt' end, args = { '--stdin-filepath', '$FILENAME' }, stdin = true }
end
package.preload.mason = function()
  return { setup = function() end }
end
require('plait.packages').install_for_apply = function() return true end

local plait = require('plait')
local module = plait.module({
  name = 'local.formatting.oxfmt',
  provides = { 'local.formatting.oxfmt' },
  requires = { 'formatting', 'tooling' },
  contribute = {
    formatting = {
      formatters = { oxfmt = { tool = 'oxfmt' } },
      by_filetype = { typescript = { 'oxfmt' } },
    },
    tooling = {
      tools = {
        oxfmt = {
          executable = 'oxfmt',
          version = '=0.66.0',
          ownership = 'project',
          workspace_paths = { 'node_modules/.bin/oxfmt' },
        },
      },
    },
  },
})
local config = plait.config()
config:select({ 'formatting', 'tooling', module })
_G.formatting_apply_result = config:apply()
