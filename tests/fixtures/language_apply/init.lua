vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

package.preload.conform = function()
  return { setup = function() end }
end
package.preload['conform.formatters.stylua'] = function()
  return { command = 'stylua', args = { '--stdin-filepath', '$FILENAME', '-' }, stdin = true }
end
package.preload.mason = function()
  return { setup = function() end }
end
package.preload['blink.cmp'] = function()
  return { setup = function() end, is_active = function() return false end, show = function() return false end }
end

-- luacheck: push ignore 122
vim.lsp.config.lua_ls = {
  cmd = { 'lua-language-server' },
  root_markers = { '.luarc.json', '.git' },
  settings = { Lua = { hint = { enable = true } } },
}
local enable = vim.lsp.enable
vim.lsp.enable = function(name)
  _G.enabled_server = name
  return enable(name, false)
end
-- luacheck: pop

local packages = require('plait.packages')
packages.install_for_apply = function() return true end

local plait = require('plait')
_G.M = plait
local config = plait.config()
config:select({ 'language', 'completion', 'formatting', 'tooling', 'lang.lua' })
config:providers({
  language = { ['vim.lsp'] = { servers = { lua_ls = { settings = { Lua = { hint = { setType = true } } } } } } },
})
_G.language_apply_result = config:apply()
_G.lua_ls_config = vim.deepcopy(vim.lsp.config.lua_ls)
