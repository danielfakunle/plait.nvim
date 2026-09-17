vim.pack.add({ { src = 'https://github.com/danielfakunle/plait.nvim', version = '>=0.1.0,<0.2.0' } })

local plait = require('plait')
local config = plait.config()
config:select({ 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' })
config:configure({
  editor = { mappings = { save = '<leader>w' } },
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
local validation = config:validate()
assert(validation.status == 'valid', vim.inspect(validation.diagnostics))
local result = config:apply()
assert(result.status == 'performed', vim.inspect(result))
return { config = config, validation = validation, result = result }
