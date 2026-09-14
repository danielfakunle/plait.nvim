local MiniTest = require('mini.test')
local helpers = dofile('tests/helpers.lua')

local child = helpers.new_clean_neovim()
local expect = MiniTest.expect

local T = MiniTest.new_set({
  hooks = {
    pre_case = child.setup,
    post_once = child.stop,
  },
})

T['qualified local integrations'] = MiniTest.new_set()

T['qualified local integrations']['run the canonical TypeScript author journey'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/typescript_apply/init.lua' })

  expect.equality(child.lua_get([[typescript_validation_result.status]]), 'valid')
  expect.equality(child.lua_get([[typescript_apply_result.status]]), 'performed')
  expect.equality(child.lua_get([[enabled_servers]]), { 'lua_ls', 'tsc' })
  expect.equality(child.lua_get([[tsc_config.filetypes]]), {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  })
  expect.equality(child.lua_get([[tsc_config.cmd]]), {
    child.lua_get([[vim.uv.fs_realpath(typescript_project .. '/node_modules/.bin/tsc')]]),
    '--lsp',
    '--stdio',
  })
  expect.equality(child.lua_get([[conform_setup.formatters_by_ft]]), {
    javascript = { 'oxfmt' },
    lua = { 'stylua' },
    typescript = { 'oxfmt' },
    typescriptreact = { 'oxfmt' },
  })
  expect.equality(
    child.lua_get([[conform_setup.formatters.oxfmt.command]]),
    child.lua_get([[vim.uv.fs_realpath(typescript_project .. '/node_modules/.bin/oxfmt')]])
  )
  expect.equality(child.lua_get([[vim.bo.shiftwidth]]), 4)
  expect.equality(child.lua_get([[vim.bo.tabstop]]), 4)
  expect.equality(child.lua_get([[vim.bo.softtabstop]]), -1)
  for _, mode in ipairs({ 'n', 'i', 'x', 's' }) do
    expect.equality(child.lua_get(([[vim.fn.maparg('<leader>w', %q, false, true).callback ~= nil]]):format(mode)), true)
  end
  expect.equality(child.lua_get([[conform_setup.format_on_save]]), vim.NIL)
  expect.equality(child.lua_get([[M.actions.formatting.format ~= nil]]), true)
  expect.equality(child.lua_get([[M.inspect('tools', 'oxfmt').ownership]]), 'project')
  expect.equality(child.lua_get([[M.inspect('tools', 'tsc').constraint]]), '>=7.0.0,<8.0.0')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('tools'))]]), {
    'lua-language-server',
    'oxfmt',
    'stylua',
    'tsc',
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('packages'))]]), {
    'blink.cmp',
    'conform.nvim',
    'mason.nvim',
    'nvim-lspconfig',
  })
  expect.equality(
    child.lua_get([[
    vim.iter(M.inspect('effects')):all(function(item) return item.state == 'completed' end)
  ]]),
    true
  )
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('effects'))]]), {
    'completion/package/blink.cmp',
    'formatting/package/conform.nvim',
    'language/package/nvim-lspconfig',
    'tooling/package/mason.nvim',
    'completion/provider-setup',
    'editor/native-options',
    'language/native-diagnostics',
    'tooling/provider-setup',
    'tooling/tool-resolution',
    'formatting/provider-setup',
    'language/server-definition/lua_ls',
    'language/server-definition/tsc',
    'completion/actions-and-mappings',
    'editor/actions',
    'editor/mappings',
    'editor/yank-highlight',
    'formatting/actions-and-mapping',
    'language/actions-and-mappings',
    'tooling/actions',
    'tooling/startup-check',
    'language/service/lua_ls',
    'language/service/tsc',
  })
  expect.equality(child.lua_get([[M.inspect('operations')]]), {})
end

T['qualified local integrations']['run the canonical Python server and formatter journey'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/python_apply/init.lua' })

  expect.equality(child.lua_get([[python_apply_result.status]]), 'performed')
  expect.equality(child.lua_get([[enabled_server]]), 'basedpyright')
  expect.equality(child.lua_get([[basedpyright_config.cmd]]), {
    vim.uv.fs_realpath(child.lua_get([[vim.fn.exepath('basedpyright-langserver')]])),
    '--stdio',
  })
  expect.equality(child.lua_get([[basedpyright_config.settings.basedpyright.analysis]]), {
    diagnosticMode = 'openFilesOnly',
    typeCheckingMode = 'basic',
  })
  expect.equality(child.lua_get([[conform_setup.formatters_by_ft]]), { python = { 'ruff' } })
  expect.equality(
    child.lua_get([[conform_setup.formatters.ruff.command]]),
    vim.uv.fs_realpath(child.lua_get([[vim.fn.exepath('ruff')]]))
  )
  expect.equality(child.lua_get([[conform_setup.formatters.ruff.args]]), {
    'format',
    '--force-exclude',
    '--stdin-filename',
    '$FILENAME',
    '-',
  })
  expect.equality(child.lua_get([[conform_setup.formatters.ruff.stdin]]), true)
  expect.equality(child.lua_get([[type(conform_setup.formatters.ruff.cwd)]]), 'string')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('packages'))]]), {
    'conform.nvim',
    'mason.nvim',
    'nvim-lspconfig',
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('tools'))]]), {
    'basedpyright',
    'ruff',
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('effects'))]]), {
    'formatting/package/conform.nvim',
    'language/package/nvim-lspconfig',
    'tooling/package/mason.nvim',
    'language/native-diagnostics',
    'tooling/provider-setup',
    'tooling/tool-resolution',
    'formatting/provider-setup',
    'language/server-definition/basedpyright',
    'formatting/actions-and-mapping',
    'language/actions-and-mappings',
    'tooling/actions',
    'tooling/startup-check',
    'language/service/basedpyright',
  })
end

return T
