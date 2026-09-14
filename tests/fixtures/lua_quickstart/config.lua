vim.pack.add({ {
  src = 'https://github.com/danielfakunle/plait.nvim',
  version = '>=0.1.0,<0.2.0',
} })

local plait = require('plait')
local config = plait.config()

config:select({
  'editor',
  'language',
  'completion',
  'formatting',
  'tooling',
  'lang.lua',
})

local validation = config:validate()
assert(validation.status == 'valid', vim.inspect(validation.diagnostics))

local result = config:apply()
assert(result.status == 'performed', vim.inspect(result))
