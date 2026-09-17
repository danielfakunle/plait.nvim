local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

describe('formatting capability facade', function()
  it('visibly explains collision preflight while preserving foreign mappings and pending effects', function()
    child.restart({
      '--clean',
      '--cmd',
      'lua vim.g.formatting_collision = true',
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    expect.equality(child.lua_get([[formatting_apply_result.reason]]), 'invalid_plan')
    expect.equality(child.lua_get([[apply_notifications]]), {
      {
        'Plait application was blocked or failed. 4 problems. '
          .. 'Managed identity mapping:n:<leader>f:global already exists. '
          .. 'Repair: Remove or rename the external effect before apply. '
          .. 'Inspect: :Plait inspect diagnostics',
        child.lua_get([[vim.log.levels.ERROR]]),
      },
    })
    expect.equality(child.lua_get([[#M.inspect('effects') > 0]]), true)
    expect.equality(
      child.lua_get([[vim.iter(M.inspect('effects')):all(function(effect)
      return effect.state == 'pending'
    end)]]),
      true
    )
    expect.equality(child.lua_get([[#M.inspect('diagnostics', 'effect.collision')]]), 2)
    expect.equality(child.lua_get([[vim.fn.maparg('<leader>f', 'n')]]), '<Cmd>echo "foreign formatter"<CR>')
    expect.equality(child.lua_get([[vim.fn.maparg('<leader>f', 'x')]]), '<Cmd>echo "foreign range formatter"<CR>')
    expect.equality(child.lua_get([[conform_setup]]), vim.NIL)
  end)

  for _, policy in ipairs({ 'errors', 'all', 'silent' }) do
    it('respects ' .. policy .. ' feedback for a blocked attempt and repaired restart', function()
      child.restart({
        '--clean',
        '--cmd',
        ('lua vim.g.formatting_collision = true; vim.g.apply_feedback = %q'):format(policy),
        '-u',
        'tests/fixtures/formatting_apply/init.lua',
      })
      expect.equality(child.lua_get([[#apply_notifications]]), policy == 'silent' and 0 or 1)
      expect.equality(child.lua_get([[formatting_apply_result]]), {
        status = 'unavailable',
        operation = 'apply',
        reason = 'invalid_plan',
        details = { diagnostic_codes = { 'effect.collision', 'package.absent' } },
      })
      local diagnostics = child.cmd_capture('Plait inspect diagnostics effect.collision --json')
      expect.equality(
        vim.json.decode(diagnostics:sub(#'diagnostics: ' + 1)),
        child.lua_get([[M.inspect('diagnostics', 'effect.collision')]])
      )
      child.restart({
        '--clean',
        '--cmd',
        ('lua vim.g.apply_feedback = %q'):format(policy),
        '-u',
        'tests/fixtures/formatting_apply/init.lua',
      })
      expect.equality(child.lua_get([[formatting_apply_result.status]]), 'performed')
      expect.equality(child.lua_get([[#apply_notifications]]), policy == 'all' and 1 or 0)
      expect.equality(
        child.lua_get([[vim.iter(M.inspect('diagnostics')):any(function(item)
        return item.code == 'effect.collision'
      end)]]),
        false
      )
      expect.equality(
        child.lua_get([[vim.iter(M.inspect('effects')):all(function(effect)
        return effect.state == 'completed'
      end)]]),
        true
      )
    end)
  end

  it('explains an explicitly disabled local chain and retains managed LSP fallback', function()
    child.restart({
      '--clean',
      '--cmd',
      'lua vim.g.formatting_disable_python = true',
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    child.lua([[
      inspection = M.inspect('capabilities', 'formatting')
      vim.bo.filetype = 'python'
      vim.lsp.get_clients = function()
        return { { supports_method = function() return true end } }
      end
      package.loaded.conform.format = function(options, callback)
        disabled_chain_options = vim.deepcopy(options)
        callback(nil, true)
        return true
      end
      disabled_chain_result = M.actions.formatting.format()
      vim.cmd('Plait inspect capabilities formatting')
      chain_report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    ]])
    expect.equality(child.lua_get([[formatting_apply_result.status]]), 'performed')
    expect.equality(child.lua_get([[inspection.formatter_chains[1].chain]]), { 'stylua' })
    expect.equality(child.lua_get([[inspection.formatter_chains[1].declaration]]), 'local.formatting.lua')
    expect.equality(child.lua_get([[inspection.formatter_chains[2].filetype]]), 'python')
    expect.equality(child.lua_get([[inspection.formatter_chains[2].state]]), 'disabled')
    expect.equality(child.lua_get([[inspection.formatter_chains[2].chain]]), {})
    expect.equality(child.lua_get([[inspection.formatter_chains[2].declaration]]), 'owner override (disable)')
    expect.equality(child.lua_get([[inspection.formatter_chains[2].sources[1].path]]), 'override')
    expect.equality(child.lua_get([[inspection.formatter_chains[2].sources[1].line > 0]]), true)
    expect.equality(child.lua_get([[disabled_chain_result.status]]), 'started')
    expect.equality(child.lua_get([[disabled_chain_result.details.chain]]), {})
    expect.equality(child.lua_get([[disabled_chain_options.lsp_format]]), 'fallback')
    expect.equality(child.lua_get([[conform_setup.formatters_by_ft.python]]), vim.NIL)
    expect.equality(
      child.lua_get([[chain_report:find('python: none [disabled]; owner override (disable)', 1, true) ~= nil]]),
      true
    )
    expect.equality(child.lua_get([[chain_report:find('still permit formatting', 1, true) ~= nil]]), true)
    expect.equality(
      child.cmd_capture('Plait inspect capabilities formatting --json'):find('"path":"override"', 1, true) ~= nil,
      true
    )
  end)

  it('applies a qualified formatter whose provider command is dynamic', function()
    child.restart({ '--clean', '-u', vim.fn.getcwd() .. '/tests/fixtures/formatting_dynamic_apply/init.lua' })

    expect.equality(child.lua_get([[formatting_apply_result.status]]), 'performed')
    expect.equality(
      child.lua_get([[conform_setup.formatters.oxfmt.command]]),
      child.lua_get([[
      vim.uv.fs_realpath(vim.fn.getcwd() .. '/node_modules/.bin/oxfmt')
    ]])
    )
  end)

  it('applies the qualified Conform policy, mappings, and independently configurable save behavior', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/formatting_apply/init.lua' })

    expect.equality(child.lua_get([[formatting_apply_result.status]]), 'performed')
    expect.equality(child.lua_get([[conform_setup.formatters_by_ft]]), { lua = { 'stylua' } })
    expect.equality(
      child.lua_get([[conform_setup.formatters.stylua.command]]),
      vim.uv.fs_realpath(vim.fn.exepath('stylua'))
    )
    expect.equality(child.lua_get([[conform_setup.formatters.stylua.args]]), {
      '--search-parent-directories',
      '--stdin-filepath',
      '$FILENAME',
      '-',
    })
    expect.equality(child.lua_get([[conform_setup.default_format_opts]]), {
      timeout_ms = 1375,
      lsp_format = 'fallback',
    })
    expect.equality(child.lua_get([[conform_setup.notify_on_error]]), false)
    expect.equality(child.lua_get([[conform_setup.notify_no_formatters]]), false)
    expect.equality(child.lua_get([[conform_setup.format_on_save]]), vim.NIL)
    expect.equality(child.lua_get([[vim.fn.maparg('<leader>f', 'n', false, true).callback ~= nil]]), true)
    expect.equality(child.lua_get([[vim.fn.maparg('<leader>f', 'x', false, true).callback ~= nil]]), true)
    expect.equality(child.lua_get([[M.actions.formatting.format ~= nil]]), true)
  end)

  it('keeps save formatting synchronous and owns sanitized failure notifications', function()
    child.restart({
      '--clean',
      '--cmd',
      'lua vim.g.formatting_on_save = true',
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    child.lua([[
      vim.bo.filetype = 'lua'
      local notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      save_options, save_callback = conform_setup.format_on_save(1)
      save_callback('token=SECRET\ntrace')
      save_notifications = notifications
    ]])

    expect.equality(child.lua_get([[save_options]]), {
      timeout_ms = 1375,
      formatters = { 'stylua' },
      lsp_format = 'never',
      quiet = true,
    })
    expect.equality(child.lua_get([[save_notifications]]), {
      {
        'Plait formatting operation failed. Repair: Inspect :Plait inspect tools and diagnostics, repair the formatter, then retry.',
        vim.log.levels.ERROR,
      },
    })
    expect.equality(child.lua_get([[vim.inspect(save_notifications):find('SECRET', 1, true) == nil]]), true)
  end)

  it('suppresses automatic format-on-save failures under silent', function()
    child.restart({
      '--clean',
      '--cmd',
      "lua vim.g.formatting_on_save = true; vim.g.apply_feedback = 'silent'",
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    child.lua([[
      vim.bo.filetype = 'lua'
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      local _, callback = conform_setup.format_on_save(1)
      callback('SECRET')
    ]])
    expect.equality(child.lua_get([[#notifications]]), 0)
  end)

  it('validates and starts zero-based end-exclusive ranged formatting', function()
    child.lua([[
      local state = require('plait.state')
      state.formatting_active = true
      state.formatting_configuration = { timeout_ms = 900, lsp_fallback = 'never' }
      state.formatting_formatters = { stylua = { tool = 'stylua' } }
      state.formatting_by_filetype = { lua = { 'stylua' } }
      state.snapshot = {
        diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {},
        tools = { { identity = 'stylua', state = 'satisfied' } },
      }
      vim.bo.filetype = 'lua'
      package.loaded.conform = {
        format = function(options, callback)
          conform_format_options = vim.deepcopy(options)
          callback(nil, true)
          return true
        end,
      }
      local range = { start = { line = 1, character = 2 }, end_ = { line = 3, character = 4 } }
      ranged = M.actions.formatting.format({ range = range })
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      ranged_operation = M.inspect('operations')[1]
      bad_ok, bad_error = pcall(M.actions.formatting.format, { range = {
        start = { line = 1, character = 0 }, end_ = { line = 0, character = 0 }, extra = true,
      } })
    ]])

    expect.equality(child.lua_get([[ranged]]), {
      status = 'started',
      operation = 'formatting.format',
      operation_id = 'op-00000001',
      details = {
        buffer = 1,
        range = { start = { line = 1, character = 2 }, end_ = { line = 3, character = 4 } },
        chain = { 'stylua' },
      },
    })
    expect.equality(child.lua_get([[conform_format_options]]), {
      bufnr = 1,
      async = true,
      timeout_ms = 900,
      formatters = { 'stylua' },
      lsp_format = 'never',
      quiet = true,
      range = { start = { 2, 2 }, ['end'] = { 4, 4 } },
    })
    expect.equality(child.lua_get([[ranged_operation.state]]), 'succeeded')
    expect.equality(child.lua_get([[bad_ok]]), false)
    expect.equality(child.lua_get([[bad_error]]), 'plait: formatting.format range is invalid')
  end)

  it('degrades an unavailable external chain atomically and forbids LSP fallback', function()
    child.lua([[
      local state = require('plait.state')
      state.formatting_active = true
      state.language_active = true
      state.formatting_configuration = { timeout_ms = 1000, lsp_fallback = 'if_no_formatter' }
      state.formatting_formatters = { first = { tool = 'one' }, second = { tool = 'two' } }
      state.formatting_by_filetype = { lua = { 'first', 'second' } }
      state.snapshot = {
        diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {},
        tools = {
          { identity = 'one', state = 'absent' },
          { identity = 'two', state = 'incompatible' },
        },
      }
      vim.bo.filetype = 'lua'
      vim.lsp.get_clients = function()
        return { { supports_method = function() return true end } }
      end
      package.loaded.conform = { format = function() conform_called = true end }
      unavailable_chain = M.actions.formatting.format()
    ]])

    expect.equality(child.lua_get([[unavailable_chain]]), {
      status = 'unavailable',
      operation = 'formatting.format',
      reason = 'formatter_chain_unavailable',
      details = {
        buffer = 1,
        unavailable = {
          { formatter = 'first', tool = 'one', state = 'absent' },
          { formatter = 'second', tool = 'two', state = 'incompatible' },
        },
      },
    })
    expect.equality(child.lua_get([[conform_called]]), vim.NIL)
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  end)

  it('uses LSP only when no external chain exists and sanitizes provider failures', function()
    child.lua([[
      local state = require('plait.state')
      state.formatting_active = true
      state.language_active = true
      state.formatting_configuration = { timeout_ms = 1000, lsp_fallback = 'if_no_formatter' }
      state.formatting_formatters = {}
      state.formatting_by_filetype = {}
      state.snapshot = {
        diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {}, tools = {},
      }
      vim.bo.filetype = 'markdown'
      vim.lsp.get_clients = function()
        return { { supports_method = function(_, method) return method == 'textDocument/formatting' end } }
      end
      package.loaded.conform = {
        format = function(options, callback)
          fallback_options = vim.deepcopy(options)
          callback('token=SECRET\ntrace')
          return true
        end,
      }
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      fallback = M.actions.formatting.format()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      failed_operation = M.inspect('operations')[1]
      failed_diagnostic = M.inspect('diagnostics', 'operation.failed')
    ]])

    expect.equality(child.lua_get([[fallback.status]]), 'started')
    expect.equality(child.lua_get([[fallback.details.chain]]), {})
    expect.equality(child.lua_get([[fallback_options.lsp_format]]), 'fallback')
    expect.equality(child.lua_get([[fallback_options.formatters]]), vim.NIL)
    expect.equality(child.lua_get([[failed_operation.error]]), {
      reason = 'execution_failed',
      message = 'Formatting operation failed.',
    })
    expect.equality(child.lua_get([[vim.inspect(failed_operation):find('SECRET', 1, true) == nil]]), true)
    expect.equality(child.lua_get([[#failed_diagnostic]]), 1)
    expect.equality(child.lua_get([[#notifications]]), 1)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.ERROR)
  end)

  it('does not let a synchronous callback turn a rejected provider start into success', function()
    child.lua([[
      local state = require('plait.state')
      state.formatting_active = true
      state.formatting_configuration = { timeout_ms = 1000, lsp_fallback = 'never' }
      state.formatting_formatters = { stylua = { tool = 'stylua' } }
      state.formatting_by_filetype = { lua = { 'stylua' } }
      state.snapshot = {
        diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {},
        tools = { { identity = 'stylua', state = 'satisfied' } },
      }
      vim.bo.filetype = 'lua'
      package.loaded.conform = {
        format = function(_, callback)
          callback(nil, false)
          return false
        end,
      }
      rejected_start = M.actions.formatting.format()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      rejected_operation = M.inspect('operations')[1]
    ]])

    expect.equality(child.lua_get([[rejected_start.status]]), 'started')
    expect.equality(child.lua_get([[rejected_operation.state]]), 'failed')
    expect.equality(child.lua_get([[rejected_operation.error.message]]), 'Formatting operation failed.')
  end)
end)
