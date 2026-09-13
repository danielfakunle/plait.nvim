vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

package.preload.conform = function()
  return {
    setup = function(value) _G.conform_setup = vim.deepcopy(value) end,
    format = function() return true end,
  }
end
package.preload['conform.formatters.stylua'] = function()
  return {
    command = 'stylua',
    args = { '--search-parent-directories', '--stdin-filepath', '$FILENAME', '-' },
    stdin = true,
  }
end
package.preload.mason = function()
  return { setup = function() end }
end

local packages = require('plait.packages')
packages.install_for_apply = function() return true end

local plait = require('plait')
_G.M = plait
local lua_formatting = plait.module({
  name = 'local.formatting.lua',
  provides = { 'local.formatting.lua' },
  requires = { 'formatting', 'tooling' },
  contribute = {
    formatting = {
      formatters = { stylua = { tool = 'stylua' } },
      by_filetype = { lua = { 'stylua' } },
    },
    tooling = {
      tools = {
        stylua = {
          executable = 'stylua',
          version = '=2.5.2',
          ownership = 'project',
          workspace_paths = { 'stylua' },
        },
      },
    },
  },
})
local config = plait.config()
config:select({ 'formatting', 'tooling', lua_formatting })
config:configure({
  formatting = {
    on_save = vim.g.formatting_on_save == true,
    timeout_ms = 1375,
    lsp_fallback = 'if_no_formatter',
    mappings = { format = '<leader>f' },
  },
})
_G.formatting_apply_result = config:apply()
