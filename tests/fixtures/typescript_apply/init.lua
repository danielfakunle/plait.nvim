vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local project = vim.fn.tempname()
_G.typescript_project = project
local bin = project .. '/node_modules/.bin'
local runtime_bin = project .. '/runtime-bin'
vim.fn.mkdir(project .. '/src', 'p')
vim.fn.mkdir(bin, 'p')
vim.fn.mkdir(runtime_bin, 'p')
for name, version in pairs({
  ['lua-language-server'] = '3.19.1',
  stylua = 'stylua 2.5.2',
  tsc = 'Version 7.0.2',
  oxfmt = 'oxfmt 0.66.0',
}) do
  vim.fn.writefile({ '#!/bin/sh', 'echo "' .. version .. '"' }, bin .. '/' .. name)
  vim.fn.setfperm(bin .. '/' .. name, 'rwxr-xr-x')
end
vim.fn.writefile({ '#!/bin/sh', 'echo "v22.12.0"' }, runtime_bin .. '/node')
vim.fn.setfperm(runtime_bin .. '/node', 'rwxr-xr-x')
vim.fn.setenv('PATH', runtime_bin .. ':' .. vim.env.PATH)
vim.cmd.edit(vim.fn.fnameescape(project .. '/src/main.ts'))

package.preload.conform = function()
  return { setup = function(value) _G.conform_setup = vim.deepcopy(value) end }
end
package.preload['conform.formatters.oxfmt'] = function()
  return { command = function() return 'oxfmt' end, args = { '--stdin-filepath', '$FILENAME' }, stdin = true }
end
package.preload['conform.formatters.stylua'] = function()
  return { command = 'stylua', args = { '--stdin-filepath', '$FILENAME', '-' }, stdin = true }
end
package.preload.mason = function()
  return { setup = function() end }
end
package.preload['blink.cmp'] = function()
  return { setup = function() end }
end

-- luacheck: push ignore 122
vim.lsp.config.tsc = { root_markers = { 'tsconfig.json', 'package.json', '.git' } }
vim.lsp.config.lua_ls = { cmd = { 'lua-language-server' }, filetypes = { 'lua' } }
local enable = vim.lsp.enable
vim.lsp.enable = function(name)
  _G.enabled_servers = _G.enabled_servers or {}
  _G.enabled_servers[#_G.enabled_servers + 1] = name
  return enable(name, false)
end
-- luacheck: pop

require('plait.packages').install_for_apply = function() return true end

_G.typescript_resolution_counts = { providers = 0, packages = 0, tools = 0 }
for name, module_name in pairs({ providers = 'plait.providers', packages = 'plait.packages', tools = 'plait.tools' }) do
  local module = require(module_name)
  local resolve = module.resolve
  module.resolve = function(...)
    _G.typescript_resolution_counts[name] = _G.typescript_resolution_counts[name] + 1
    return resolve(...)
  end
end

local system = vim.system
_G.typescript_probe_counts = {}
-- luacheck: push ignore 122
vim.system = function(command, options)
  if command[2] == '--version' then
    local identity = table.concat(command, '\0')
    _G.typescript_probe_counts[identity] = (_G.typescript_probe_counts[identity] or 0) + 1
  end
  return system(command, options)
end
-- luacheck: pop

local plait = require('plait')
_G.M = plait
local config = plait.config()
config:select({ 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' })
config:configure({
  editor = { indentation = { style = 'spaces', width = 4 }, mappings = { save = '<leader>w' } },
  formatting = { on_save = false },
})
config:override({
  formatting = { by_filetype = { javascriptreact = plait.disable() } },
  tooling = {
    tools = {
      oxfmt = plait.replace({
        executable = 'oxfmt',
        version = '=0.66.0',
        ownership = 'project',
        workspace_paths = { 'node_modules/.bin/oxfmt' },
      }),
    },
  },
})
_G.typescript_validation_result = config:validate()
_G.typescript_validation_result.plan.effects[1].identity = 'mutated-public-result'
_G.typescript_apply_result = config:apply()
_G.tsc_config = vim.deepcopy(vim.lsp.config.tsc)
