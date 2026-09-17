vim.pack.add({ {
  src = 'https://github.com/danielfakunle/plait.nvim',
  version = '>=0.1.0,<0.2.0',
} })

local plait = require('plait')
local python = dofile('tests/fixtures/extension_boundary/python.lua')
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
})

local validation = config:validate()
assert(validation.status == 'valid', vim.inspect(validation.diagnostics))
local result = config:apply()
assert(result.status == 'performed', vim.inspect(result))
-- luacheck: ignore 122
vim.opt.colorcolumn = '88' -- ordinary Lua, intentionally outside Plait

return { config = config, validation = validation, result = result }
