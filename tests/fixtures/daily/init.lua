vim.api.nvim_set_option_value('swapfile', false, {})
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local project = assert(vim.uv.fs_mkdtemp('/tmp/plait-daily-XXXXXX'))
_G.daily_project = project
vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() vim.fn.delete(project, 'rf') end })
local bin = project .. '/node_modules/.bin'
local runtime_bin = project .. '/runtime-bin'
vim.fn.mkdir(project .. '/src', 'p')
vim.fn.mkdir(bin, 'p')
vim.fn.mkdir(runtime_bin, 'p')
local git = vim.fn.exepath('git')
local versions = {
  ['lua-language-server'] = '3.19.1',
  stylua = 'stylua 2.5.2',
  tsc = 'Version 7.0.2',
  oxfmt = 'oxfmt 0.66.0',
  node = 'v22.12.0',
}
for name, version in pairs(versions) do
  local directory = name == 'node' and runtime_bin or bin
  local state = vim.g.daily_tool == name and vim.g.daily_tool_state or 'satisfied'
  if state ~= 'absent' then
    local output = state == 'unprobeable' and 'not a version' or state == 'incompatible' and '1.0.0' or version
    vim.fn.writefile({ '#!/bin/sh', 'echo "' .. output .. '"' }, directory .. '/' .. name)
    vim.fn.setfperm(directory .. '/' .. name, 'rwxr-xr-x')
  end
end
-- Keep executable discovery independent of tools installed on the developer's machine.
vim.fn.setenv('PATH', runtime_bin .. ':' .. bin)
local exepath = vim.fn.exepath
-- luacheck: push ignore 122
vim.fn.exepath = function(name)
  if name == 'git' then return git end
  if versions[name] then
    local path = (name == 'node' and runtime_bin or bin) .. '/' .. name
    return vim.fn.executable(path) == 1 and path or ''
  end
  return exepath(name)
end
-- luacheck: pop
vim.cmd.edit(vim.fn.fnameescape(project .. '/src/main.ts'))
vim.api.nvim_set_option_value('filetype', 'typescript', { buf = 0 })

package.preload.conform = function()
  return {
    setup = function(value) _G.conform_setup = vim.deepcopy(value) end,
    format = function(options, done)
      _G.daily_format_options = vim.deepcopy(options)
      done(nil)
    end,
  }
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
  return {
    setup = function(options) _G.daily_completion = vim.deepcopy(options) end,
    is_active = function() return false end,
    show = function() return true end,
  }
end

-- luacheck: push ignore 122
vim.lsp.config.tsc = { root_markers = { 'tsconfig.json', 'package.json', '.git' } }
vim.lsp.config.lua_ls = { cmd = { 'lua-language-server' }, filetypes = { 'lua' } }
local enable = vim.lsp.enable
vim.lsp.enable = function(name)
  _G.daily_enabled_servers = _G.daily_enabled_servers or {}
  _G.daily_enabled_servers[#_G.daily_enabled_servers + 1] = name
  return enable(name, false)
end
-- luacheck: pop

local compatibility = require('plait.compatibility')
local package_root = project .. '/pack/plait/opt'
local config_root = project .. '/config'
vim.fn.mkdir(config_root, 'p')
vim.opt.packpath:prepend(project)
vim.opt.packpath:append(project .. '/data/site')
local packages, lock = {}, { plugins = {} }
for _, requirement in ipairs(compatibility.providers) do
  packages[requirement.identity] = requirement
  vim.fn.mkdir(package_root .. '/' .. requirement.identity, 'p')
  lock.plugins[requirement.identity] = { source = requirement.source, commit = requirement.commit }
end
vim.fn.writefile({ vim.json.encode(lock) }, config_root .. '/nvim-pack-lock.json')
local stdpath, system = vim.fn.stdpath, vim.system
-- luacheck: push ignore 122
vim.fn.stdpath = function(kind)
  if kind == 'config' then return config_root end
  if kind == 'data' then return project .. '/data' end
  return stdpath(kind)
end
vim.system = function(command, options)
  if command[1] == 'git' and (command[4] == 'remote' or command[4] == 'rev-parse') then
    local record = packages[vim.fs.basename(command[3])]
    return {
      wait = function()
        return { code = 0, stdout = (command[4] == 'remote' and record.source or record.commit) .. '\n', stderr = '' }
      end,
    }
  end
  if command[1] == 'git' then
    command = vim.deepcopy(command)
    command[1] = git
  end
  return system(command, options)
end
vim.pack.add = function() end
-- luacheck: pop
_G.M = require('plait')
_G.daily = dofile('tests/fixtures/daily/config.lua')
