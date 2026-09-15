vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

package.preload['blink.cmp'] = function()
  return {
    setup = function(value)
      -- blink.cmp 1.10.2 validates this field as a function, not a boolean.
      assert(type(value.enabled) == 'function', 'config.enabled: expected function')
      _G.blink_setup = vim.deepcopy(value)
    end,
    is_active = function() return false end,
    is_documentation_visible = function() return false end,
    show_documentation = function() return false end,
    hide_documentation = function() return false end,
    get_selected_item = function() return nil end,
    show = function() return false end,
    select_next = function() return false end,
    select_prev = function() return false end,
    accept = function() return false end,
    cancel = function() return false end,
    hide = function() return false end,
    select_and_accept = function() return false end,
    scroll_documentation_down = function() return false end,
    scroll_documentation_up = function() return false end,
  }
end

local packages = require('plait.packages')
packages.install_for_apply = function() return true end

local plait = require('plait')
_G.M = plait
local config = plait.config()
config:select({ 'language', 'completion' })
config:configure({
  completion = {
    automatic = false,
    sources = { 'path', 'buffer', 'snippets', 'lsp' },
    documentation = vim.g.completion_documentation or 'automatic',
    signature_help = false,
  },
})
config:providers({
  completion = { ['blink.cmp'] = { setup = { appearance = { nerd_font_variant = 'mono' } } } },
})
_G.completion_apply_result = config:apply()
