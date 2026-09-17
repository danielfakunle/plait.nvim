vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local mode = vim.g.extension_mode or 'satisfied'
local bin = vim.fn.tempname()
vim.fn.mkdir(bin, 'p')
vim.fn.writefile({ '#!/bin/sh', 'echo "basedpyright 1.31.4"' }, bin .. '/basedpyright-langserver')
vim.fn.writefile({ '#!/bin/sh', 'echo "ruff ' .. (mode == 'chain' and '0.14.0' or '0.13.2') .. '"' }, bin .. '/ruff')
vim.fn.setfperm(bin .. '/basedpyright-langserver', 'rwxr-xr-x')
vim.fn.setfperm(bin .. '/ruff', 'rwxr-xr-x')
-- luacheck: push ignore 122
vim.env.PATH = bin .. ':' .. vim.env.PATH

package.preload.conform = function()
  return {
    setup = function(value) _G.conform_setup = vim.deepcopy(value) end,
    format = function() _G.format_called = true end,
  }
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

-- Satisfied package checkouts and lock metadata at the native package boundary.
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/config', 'p')
vim.opt.packpath:prepend(root)
local requirements = {}
local lock = { plugins = {} }
for _, provider in ipairs(require('plait.compatibility').providers) do
  if provider.identity ~= 'blink.cmp' then
    requirements[provider.identity] = provider
    vim.fn.mkdir(root .. '/pack/plait/opt/' .. provider.identity, 'p')
    lock.plugins[provider.identity] = { source = provider.source, commit = provider.commit }
  end
end
vim.fn.writefile({ vim.json.encode(lock) }, root .. '/config/nvim-pack-lock.json')
local stdpath, system, exepath = vim.fn.stdpath, vim.system, vim.fn.exepath
-- luacheck: push ignore 122
vim.fn.stdpath = function(kind)
  if kind == 'config' then return root .. '/config' end
  if kind == 'data' then return root .. '/data' end
  return stdpath(kind)
end
vim.opt.packpath:append(root .. '/data/site')
vim.fn.exepath = function(executable)
  if executable == 'oxfmt' then return '' end
  if executable == 'ruff' or executable == 'basedpyright-langserver' then return bin .. '/' .. executable end
  return exepath(executable)
end
package.preload['conform.formatters.oxfmt'] = function()
  return { command = 'oxfmt', args = { '--stdin-filepath', '$FILENAME' }, stdin = true }
end
vim.system = function(args, options)
  local provider = requirements[(args[3] or ''):match('([^/]+)$')]
  if args[1] == 'git' and provider then
    local value = args[4] == 'remote' and provider.source or provider.commit
    return { wait = function() return { code = 0, stdout = value .. '\n', stderr = '' } end }
  end
  return system(args, options)
end
vim.pack.add = function() end
-- luacheck: pop
local M = require('plait')
_G.M = M
local sections = { 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }
local before_lua = {}
-- Capture managed surfaces immediately before the canonical ordinary-Lua assignment.
local source = 'tests/fixtures/extension_boundary/config.lua'
local colorcolumn_line
for line, text in ipairs(vim.fn.readfile(source)) do
  if text:match('^vim.opt.colorcolumn') then colorcolumn_line = line end
end
debug.sethook(function()
  local info = debug.getinfo(2, 'Sl')
  if info.source:sub(-#source) == source and info.currentline == colorcolumn_line then
    for _, section in ipairs(sections) do
      before_lua[section] = M.inspect(section)
    end
    debug.sethook()
  end
end, 'l')
if mode == 'guard' then
  local config = M.config()
  config:select({ 'language', 'formatting', 'tooling', dofile('tests/fixtures/extension_boundary/python.lua') })
  config:providers({
    language = { ['vim.lsp'] = { servers = { basedpyright = { cmd = { 'foreign' } } } } },
    formatting = { ['conform.nvim'] = { formatters = { ruff = { command = 'foreign' } } } },
  })
  _G.extension = { config = config, validation = config:validate(), result = config:apply() }
elseif mode == 'chain' then
  local config = M.config()
  config:select({ 'language', 'formatting', 'tooling', dofile('tests/fixtures/extension_boundary/python.lua') })
  config:select({
    M.module({
      name = 'local.python.chain',
      provides = { 'local.python.chain' },
      requires = { 'formatting', 'tooling' },
      contribute = {
        formatting = { formatters = { oxfmt = { tool = 'oxfmt' } } },
        tooling = {
          tools = {
            ['oxfmt'] = {
              executable = 'oxfmt',
              version = '=1.0.0',
              ownership = 'mason',
              mason = 'oxfmt',
            },
          },
        },
      },
    }),
  })
  config:override({ formatting = { by_filetype = { python = M.replace({ 'ruff', 'oxfmt' }) } } })
  _G.extension = { config = config, validation = config:validate(), result = config:apply() }
  -- luacheck: push ignore 122
  vim.lsp.get_clients = function()
    return { { supports_method = function() return true end, stop = function() end } }
  end
  vim.lsp.buf.format = function() _G.lsp_format_called = true end
  -- luacheck: pop
else
  _G.extension = dofile('tests/fixtures/extension_boundary/config.lua')
end
_G.basedpyright_config = vim.deepcopy(vim.lsp.config.basedpyright)
debug.sethook()
local after_lua = {}
for _, section in ipairs(sections) do
  after_lua[section] = M.inspect(section)
end
_G.extension.ordinary_lua_excluded = vim.deep_equal(before_lua, after_lua)

_G.extension_paths = { bin = bin, root = root }
