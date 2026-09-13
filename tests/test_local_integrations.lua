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
