local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

local function activate_language()
  child.lua([[
    local state = require('plait.state')
    state.language_active = true
    state.snapshot = {
      diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {}, tools = {},
    }
  ]])
end

describe('language capability facade', function()
  it('keeps generic language valid without a contributed server', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language' })
      result = config:validate()
      effects = vim.tbl_map(function(effect) return effect.identity end, result.plan.effects)
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[effects]]), {
      'language/native-diagnostics',
      'language/actions-and-mappings',
    })
    expect.equality(
      child.lua_get([[
      vim.tbl_filter(function(item) return item.code ~= 'package.absent' end, result.diagnostics)
    ]]),
      {}
    )
  end)

  it('distinguishes native diagnostic navigation from no diagnostics', function()
    activate_language()
    child.lua([[
      local calls = {}
      vim.diagnostic.jump = function(options)
        calls[#calls + 1] = options
        if options.count == -1 then return { lnum = 1 } end
      end
      previous = M.actions.language.previous_diagnostic()
      next_result = M.actions.language.next_diagnostic()
      jump_calls = calls
    ]])

    expect.equality(child.lua_get([[previous]]), {
      status = 'performed',
      operation = 'language.previous_diagnostic',
      details = { buffer = 1 },
    })
    expect.equality(child.lua_get([[next_result]]), {
      status = 'unavailable',
      operation = 'language.next_diagnostic',
      reason = 'no_diagnostics',
      details = { buffer = 1 },
    })
    expect.equality(child.lua_get([[jump_calls]]), { { count = -1, float = true }, { count = 1, float = true } })
  end)

  it('starts only requests supported by an attached client', function()
    activate_language()
    child.lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '', '', 'value' })
      vim.api.nvim_win_set_cursor(0, { 3, 4 })
      local clients = {}
      vim.lsp.get_clients = function() return clients end
      no_client = M.actions.language.definition()
      clients = { { supports_method = function() return false end } }
      unsupported = M.actions.language.definition()
      called = 0
      clients = { { supports_method = function(_, method) return method == 'textDocument/definition' end } }
      vim.lsp.buf.definition = function()
        called = called + 1
        called_buffer = vim.api.nvim_get_current_buf()
      end
      started = M.actions.language.definition()
      vim.cmd.enew()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      operation = M.inspect('operations')[1]
    ]])

    expect.equality(child.lua_get([[no_client]]), {
      status = 'unavailable',
      operation = 'language.definition',
      reason = 'no_client',
      details = { buffer = 1, position = { line = 2, character = 4 } },
    })
    expect.equality(child.lua_get([[unsupported.reason]]), 'client_unsupported')
    expect.equality(child.lua_get([[started]]), {
      status = 'started',
      operation = 'language.definition',
      operation_id = 'op-00000001',
      details = { buffer = 1, position = { line = 2, character = 4 } },
    })
    expect.equality(child.lua_get([[called]]), 1)
    expect.equality(child.lua_get([[called_buffer]]), 1)
    expect.equality(child.lua_get([[operation.state]]), 'succeeded')
    expect.equality(child.lua_get([[operation.result]]), {
      status = 'performed',
      operation = 'language.definition',
      details = { buffer = 1, position = { line = 2, character = 4 } },
    })
  end)

  it('sanitizes asynchronous action failures in canonical records', function()
    activate_language()
    child.lua([[
      vim.lsp.get_clients = function()
        return { { supports_method = function() return true end } }
      end
      require('plait.state').snapshot.diagnostics = {
        { code = 'operation.succeeded', severity = 'info', summary = 'existing', repair = '', source = nil,
          related_sources = {}, details = {} },
      }
      vim.lsp.buf.hover = function() error('token=SECRET\ntrace') end
      started = M.actions.language.hover()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      operation = M.inspect('operations')[1]
      diagnostic = M.inspect('diagnostics', 'operation.failed')[1]
      diagnostic_codes = vim.tbl_map(function(item) return item.code end, M.inspect('diagnostics'))
    ]])

    expect.equality(child.lua_get([[started.status]]), 'started')
    expect.equality(child.lua_get([[operation.error]]), {
      reason = 'execution_failed',
      message = 'Language action failed.',
    })
    expect.equality(child.lua_get([[diagnostic.details.message]]), 'Language action failed.')
    expect.equality(child.lua_get([[diagnostic_codes]]), { 'operation.failed', 'operation.succeeded' })
    expect.equality(child.lua_get([[vim.inspect(operation):find('SECRET', 1, true) == nil]]), true)
  end)

  it('applies only native diagnostics, inlay hints, and fixed buffer mappings', function()
    child.lua([[
      local language = require('plait.language')
      local diagnostic_options
      local hint_calls = {}
      vim.diagnostic.config = function(options) diagnostic_options = vim.deepcopy(options) end
      vim.lsp.inlay_hint.enable = function(value, options) hint_calls[#hint_calls + 1] = { value, options } end
      language.apply_effect('language/native-diagnostics', {
        diagnostics = { signs = false, underline = true, virtual_text = false, severity_sort = true, update_in_insert = false },
        inlay_hints = true,
        mappings = { previous_diagnostic = '[x', next_diagnostic = ']x', definition = 'gd', references = false,
          hover = false, rename = false, code_action = false },
      })
      language.apply_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = '[x', next_diagnostic = ']x', definition = 'gd', references = false,
          hover = false, rename = false, code_action = false },
      })
      configured = diagnostic_options
      hints = hint_calls
      previous_map = vim.fn.maparg('[x', 'n', false, true)
      next_map = vim.fn.maparg(']x', 'n', false, true)
    ]])

    expect.equality(child.lua_get([[configured]]), {
      signs = false,
      underline = true,
      virtual_text = false,
      severity_sort = true,
      update_in_insert = false,
    })
    expect.equality(child.lua_get([[hints]]), { { true, { bufnr = 1 } } })
    expect.equality(child.lua_get([[previous_map.buffer]]), 1)
    expect.equality(child.lua_get([[next_map.buffer]]), 1)
  end)

  it('preflights diagnostic mapping collisions', function()
    child.lua([[
      local language = require('plait.language')
      vim.keymap.set('n', '[x', function() end, { buffer = 0 })
      collisions = language.preflight_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = '[x', next_diagnostic = ']x', definition = false, references = false,
          hover = false, rename = false, code_action = false },
      })
    ]])

    expect.equality(child.lua_get([[collisions]]), {
      { identity = 'mapping:n:[x:buffer:1', observed_owner = 'mapping' },
    })
  end)
end)
