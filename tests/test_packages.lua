local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

describe('provider package observation', function()
  it('exposes absent canonical requirements without mutating package state', function()
    child.lua([[
      local data_path = vim.fn.stdpath('data')
      local empty_config = vim.fn.tempname()
      vim.fn.stdpath = function(kind)
        if kind == 'config' then return empty_config end
        return data_path
      end
      vim.fn.globpath = function() return {} end
      local config = M.config()
      config:select({ 'language' })
      result = config:validate()
      packages = M.inspect('packages')
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[packages]]), {
      {
        identity = 'nvim-lspconfig',
        source = 'https://github.com/neovim/nvim-lspconfig',
        required_commit = '615d7b2712efb2f530a83a9d0466acafba6b1d6f',
        active_source = vim.NIL,
        active_commit = vim.NIL,
        state = 'absent',
        inconsistency = vim.NIL,
        responsible_capabilities = { 'language' },
        sources = { { file = '<nvim>', line = 9, path = 'select[1]' } },
        repair = 'Consent to install during legal interactive apply, or sync then restart.',
      },
    })
    expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.code end, result.diagnostics)]]), {
      'package.absent',
    })
  end)

  it('coalesces a shared provider requirement and its provenance', function()
    child.lua([[
      local data_path = vim.fn.stdpath('data')
      local empty_config = vim.fn.tempname()
      vim.fn.stdpath = function(kind)
        if kind == 'config' then return empty_config end
        return data_path
      end
      vim.fn.globpath = function() return {} end
      local config = M.config()
      config:select({ 'language', 'lang.lua', 'formatting', 'tooling' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, result.plan.packages)]]), {
      'conform.nvim',
      'mason.nvim',
      'nvim-lspconfig',
    })
  end)

  it('prioritizes process-local package evidence over static absence', function()
    child.lua([[
      local data_path = vim.fn.stdpath('data')
      local empty_config = vim.fn.tempname()
      vim.fn.stdpath = function(kind)
        if kind == 'config' then return empty_config end
        return data_path
      end
      vim.fn.globpath = function() return {} end
      require('plait.packages').mark_restart_required({ 'nvim-lspconfig' })
      local config = M.config()
      config:select({ 'language' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.plan.packages[1].state]]), 'restart_required')
    expect.equality(child.lua_get([[result.diagnostics[1].code]]), 'package.restart_required')
  end)
end)
