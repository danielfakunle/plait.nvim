vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

package.preload.mason = function()
  return { setup = function(value) _G.tooling_setup = vim.deepcopy(value) end }
end

local packages = require('plait.packages')
packages.install_for_apply = function() return true end

local plait = require('plait')
local config = plait.config()
config:select({ 'tooling' })
config:providers({
  tooling = { ['mason.nvim'] = { setup = { registries = { 'github:other/latest' }, ui = { border = 'single' } } } },
})
_G.tooling_apply_result = config:apply()
