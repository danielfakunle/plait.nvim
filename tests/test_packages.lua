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

describe('provider package synchronization', function()
  for _, invocation in ipairs({ 'lua', 'command' }) do
    it('starts one exact activation and publishes a terminal operation via ' .. invocation, function()
      child.lua([[
      local data_path = vim.fn.stdpath('data')
      local config_path = vim.fn.tempname()
      local checkout_path = config_path .. '/pack/plait/opt/nvim-lspconfig'
      vim.fn.mkdir(checkout_path, 'p')
      vim.fn.stdpath = function(kind)
        if kind == 'config' then return config_path end
        return data_path
      end
      local installed = false
      local checkout_returned = false
      vim.fn.globpath = function(_, pattern)
        if installed and not checkout_returned and pattern:find('nvim%-lspconfig$') then
          checkout_returned = true
          return { checkout_path }
        end
        return {}
      end
      local original_system = vim.system
      vim.system = function(arguments)
        if arguments[1] == 'git' and arguments[4] == 'remote' then
          return { wait = function() return { code = 0, stdout = 'https://github.com/neovim/nvim-lspconfig\n' } end }
        end
        if arguments[1] == 'git' and arguments[4] == 'rev-parse' then
          return { wait = function() return { code = 0, stdout = '615d7b2712efb2f530a83a9d0466acafba6b1d6f\n' } end }
        end
        return original_system(arguments)
      end
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      pack_calls = {}
      vim.pack.add = function(specs, options)
        pack_calls[#pack_calls + 1] = { specs = vim.deepcopy(specs), options = vim.deepcopy(options) }
        installed = true
        vim.fn.writefile({ vim.json.encode({ plugins = { ['nvim-lspconfig'] = {
          source = 'https://github.com/neovim/nvim-lspconfig',
          commit = '615d7b2712efb2f530a83a9d0466acafba6b1d6f',
        } } }) }, config_path .. '/nvim-pack-lock.json')
      end
      local config = M.config()
      config:select({ 'language' })
      config:validate()
    ]])
      if invocation == 'lua' then
        child.lua([[sync_result = M.actions.packages.sync(true)]])
      else
        child.cmd('Plait packages sync!')
      end

      if invocation == 'lua' then
        expect.equality(child.lua_get([[sync_result]]), {
          status = 'started',
          operation = 'packages.sync',
          operation_id = 'op-00000001',
          details = { packages = { 'nvim-lspconfig' } },
        })
      end
      expect.equality(child.lua_get([[pack_calls]]), {
        {
          specs = {
            {
              name = 'nvim-lspconfig',
              src = 'https://github.com/neovim/nvim-lspconfig',
              version = '615d7b2712efb2f530a83a9d0466acafba6b1d6f',
            },
          },
          options = { load = false, confirm = false },
        },
      })
      child.lua([[vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)]])
      expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'succeeded')
      expect.equality(child.lua_get([[M.inspect('packages')[1].state]]), 'restart_required')
      expect.equality(child.lua_get([[#notifications]]), invocation == 'command' and 2 or 0)
      if invocation == 'command' then
        expect.equality(
          child.lua_get([=[notifications[2]]=]),
          'Plait: Synchronized nvim-lspconfig. Restart Neovim to use the package changes.'
        )
      end
    end)
  end

  it('publishes one sanitized failure diagnostic and notification', function()
    child.lua([[
      local data_path = vim.fn.stdpath('data')
      local config_path = vim.fn.tempname()
      vim.fn.stdpath = function(kind)
        if kind == 'config' then return config_path end
        return data_path
      end
      vim.fn.globpath = function() return {} end
      vim.pack.add = function()
        error('SECRET_TOKEN=package-credential\nstack traceback:\n\tenvironment dump')
      end
      notifications = {}
      vim.notify = function(message, level)
        notifications[#notifications + 1] = { message, level }
      end
      local config = M.config()
      config:select({ 'language' })
      config:validate()
      started = M.actions.packages.sync(true)
      pending = M.inspect('operations')[1]
      pending_copy = vim.deepcopy(pending)
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      operation = M.inspect('operations')[1]
      diagnostic = M.inspect('diagnostics', 'operation.failed')[1]
      diagnostic_codes = vim.tbl_map(function(item) return item.code end, M.inspect('diagnostics'))
    ]])

    expect.equality(child.lua_get([[started.operation_id]]), 'op-00000001')
    expect.equality(child.lua_get([[pending_copy.state]]), 'pending')
    expect.equality(child.lua_get([[pending_copy.completed_at]]), vim.NIL)
    expect.equality(child.lua_get([[operation.error]]), {
      reason = 'execution_failed',
      message = 'Provider package synchronization failed.',
    })
    expect.equality(child.lua_get([[operation.diagnostic_codes]]), { 'operation.failed' })
    expect.equality(child.lua_get([[#M.inspect('diagnostics', 'operation.failed')]]), 1)
    expect.equality(child.lua_get([[diagnostic.details.message]]), 'Provider package synchronization failed.')
    expect.equality(child.lua_get([[diagnostic_codes]]), { 'operation.failed', 'package.partial_unknown' })
    expect.equality(child.lua_get([[#notifications]]), 1)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.ERROR)
    expect.equality(
      child.lua_get([[vim.inspect({ operation, diagnostic, notifications }):find('SECRET_TOKEN', 1, true) == nil]]),
      true
    )
  end)
end)
