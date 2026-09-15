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
  it('inspects a rootless attached LuaLS without publishing a diagnostic', function()
    activate_language()
    child.lua([[
      local state = require('plait.state')
      state.language_servers.lua_ls = {
        filetypes = { 'lua' }, tool = 'lua-language-server', state = 'satisfied', language = 'lang.lua',
      }
      vim.bo.filetype = 'lua'
      vim.lsp.get_clients = function() return { { name = 'lua_ls', root_dir = nil } } end
      rootless = M.inspect('language_servers', 'lua_ls')
      plait_diagnostics = M.inspect('diagnostics')
      vim.lsp.get_clients = function() return { { name = 'lua_ls', root_dir = '/tmp/lua-project' } } end
      rooted = M.inspect('language_servers', 'lua_ls')
    ]])

    expect.equality(child.lua_get([[rootless.state]]), 'attached')
    expect.equality(child.lua_get([[rootless.workspace_root]]), vim.NIL)
    expect.equality(child.lua_get([[rootless.note:find('initial diagnostics may be delayed', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[rootless.repair:find('.luarc.json', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[rooted.workspace_root]]), '/tmp/lua-project')
    expect.equality(child.lua_get([[rooted.note]]), vim.NIL)
    expect.equality(child.lua_get([[plait_diagnostics]]), {})
  end)

  it('closes a references quickfix window with q without mapping ordinary buffers', function()
    child.lua([[
      local language = require('plait.language')
      vim.lsp.get_clients = function() return {} end
      language.apply_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = false, next_diagnostic = false, definition = false, references = 'gr',
          hover = false, rename = false, code_action = false },
      })
      source_buffer = vim.api.nvim_get_current_buf()
      source_q = vim.fn.maparg('q', 'n', false, true)
      vim.fn.setqflist({ { filename = 'main.lua', lnum = 1, text = 'reference' } })
      vim.cmd.copen()
      quickfix_buffer = vim.api.nvim_get_current_buf()
      quickfix_q = vim.fn.maparg('q', 'n', false, true)
      if quickfix_q.callback then quickfix_q.callback() end
      quickfix_window_closed = vim.fn.getqflist({ winid = 0 }).winid == 0
    ]])

    expect.equality(child.lua_get([[next(source_q)]]), vim.NIL)
    expect.equality(child.lua_get([[quickfix_buffer ~= source_buffer]]), true)
    expect.equality(child.lua_get([[quickfix_q.buffer]]), 1)
    expect.equality(child.lua_get([[quickfix_window_closed]]), true)
  end)

  it('installs client-supported mappings after a late LSP attach', function()
    child.lua([[
      local language = require('plait.language')
      local clients = {}
      vim.lsp.get_clients = function() return clients end
      language.apply_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = false, next_diagnostic = false, definition = false, references = 'gr',
          hover = false, rename = false, code_action = false },
      })
      before_attach = vim.fn.maparg('gr', 'n', false, true)
      clients = { { supports_method = function(_, method) return method == 'textDocument/references' end } }
      vim.api.nvim_exec_autocmds('LspAttach', { buffer = 0, data = { client_id = 1 } })
      after_attach = vim.fn.maparg('gr', 'n', false, true)
    ]])

    expect.equality(child.lua_get([[next(before_attach)]]), vim.NIL)
    expect.equality(child.lua_get([[after_attach.buffer]]), 1)
    expect.equality(child.lua_get([[type(after_attach.callback)]]), 'function')
  end)

  it('replaces the native gr mapping family when language is applied', function()
    child.lua([[
      local language = require('plait.language')
      vim.lsp.get_clients = function()
        return { { supports_method = function(_, method) return method == 'textDocument/references' end } }
      end
      language.apply_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = false, next_diagnostic = false, definition = false, references = 'gr',
          hover = false, rename = false, code_action = false },
      })
    ]])

    expect.equality(child.lua_get([[vim.fn.maparg('gr', 'n', false, true).callback ~= nil]]), true)
    for _, mapping in ipairs({ 'grr', 'gra', 'grn', 'gri', 'grt' }) do
      expect.equality(child.lua_get(([[vim.fn.maparg(%q, 'n')]]):format(mapping)), '')
    end
  end)

  it('preserves owner and plugin gr mappings while removing only native defaults', function()
    child.lua([[
      local language = require('plait.language')
      vim.keymap.set('n', 'grr', function() end, { desc = 'Owner references' })
      vim.keymap.set('n', 'gra', function() end, { buffer = 0, desc = 'Plugin action' })
      language.apply_effect('language/actions-and-mappings', {
        mappings = { previous_diagnostic = false, next_diagnostic = false, definition = false, references = false,
          hover = false, rename = false, code_action = false },
      })
      owner_grr = vim.fn.maparg('grr', 'n', false, true)
      plugin_gra = vim.fn.maparg('gra', 'n', false, true)
    ]])

    expect.equality(child.lua_get([[owner_grr.desc]]), 'Owner references')
    expect.equality(child.lua_get([[plugin_gra.desc]]), 'Plugin action')
    expect.equality(child.lua_get([[plugin_gra.buffer]]), 1)
    for _, mapping in ipairs({ 'grn', 'gri', 'grt' }) do
      expect.equality(child.lua_get(([[vim.fn.maparg(%q, 'n')]]):format(mapping)), '')
    end
  end)

  it('plans the canonical TypeScript language integration', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      result = config:validate()
      server_effects = vim.tbl_filter(function(effect)
        return effect.identity:find('/tsc', 1, true) ~= nil
      end, M.inspect('effects'))
      typescript = M.inspect('capabilities', 'lang.typescript')
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[typescript.contributions]]), {
      'formatting.by_filetype.javascript',
      'formatting.by_filetype.javascriptreact',
      'formatting.by_filetype.typescript',
      'formatting.by_filetype.typescriptreact',
      'formatting.formatters.oxfmt',
      'language.servers.tsc',
      'tooling.tools.oxfmt',
      'tooling.tools.tsc',
    })
    expect.equality(child.lua_get([[vim.tbl_map(function(effect) return effect.identity end, server_effects)]]), {
      'language/server-definition/tsc',
      'language/service/tsc',
    })
  end)

  it('plans the canonical Lua language integration', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua' })
      result = config:validate()
      modules = M.inspect('modules')
      effects = vim.tbl_map(function(effect) return {
        identity = effect.identity,
        stage = effect.stage,
        dependencies = effect.dependencies,
      } end, M.inspect('effects'))
      tools = vim.tbl_map(function(tool) return {
        identity = tool.identity,
        constraint = tool.constraint,
        affected_operations = tool.affected_operations,
      } end, M.inspect('tools'))
      lua_definition_source = M.inspect('effects', 'language/server-definition/lua_ls').sources[1]
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[modules[4].identity]]), 'lang.lua')
    expect.equality(child.lua_get([[modules[4].contributions]]), {
      'formatting.by_filetype.lua',
      'formatting.formatters.stylua',
      'language.servers.lua_ls',
      'tooling.tools.lua-language-server',
      'tooling.tools.stylua',
    })
    expect.equality(child.lua_get([[effects]]), {
      { identity = 'formatting/package/conform.nvim', stage = 2, dependencies = {} },
      { identity = 'language/package/nvim-lspconfig', stage = 2, dependencies = {} },
      { identity = 'tooling/package/mason.nvim', stage = 2, dependencies = {} },
      {
        identity = 'language/native-diagnostics',
        stage = 3,
        dependencies = { 'language/package/nvim-lspconfig' },
      },
      {
        identity = 'tooling/provider-setup',
        stage = 3,
        dependencies = { 'tooling/package/mason.nvim' },
      },
      {
        identity = 'tooling/tool-resolution',
        stage = 3,
        dependencies = { 'tooling/package/mason.nvim' },
      },
      {
        identity = 'formatting/provider-setup',
        stage = 3,
        dependencies = { 'formatting/package/conform.nvim', 'tooling/tool-resolution' },
      },
      {
        identity = 'language/server-definition/lua_ls',
        stage = 3,
        dependencies = { 'language/package/nvim-lspconfig', 'tooling/tool-resolution' },
      },
      {
        identity = 'formatting/actions-and-mapping',
        stage = 4,
        dependencies = { 'formatting/provider-setup' },
      },
      {
        identity = 'language/actions-and-mappings',
        stage = 4,
        dependencies = { 'language/native-diagnostics' },
      },
      { identity = 'tooling/actions', stage = 4, dependencies = { 'tooling/tool-resolution' } },
      { identity = 'tooling/startup-check', stage = 5, dependencies = { 'tooling/tool-resolution' } },
      {
        identity = 'language/service/lua_ls',
        stage = 5,
        dependencies = { 'language/server-definition/lua_ls', 'tooling/startup-check' },
      },
    })
    expect.equality(child.lua_get([[tools]]), {
      {
        identity = 'lua-language-server',
        constraint = '=3.19.1',
        affected_operations = {
          'language.code_action',
          'language.definition',
          'language.hover',
          'language.references',
          'language.rename',
        },
      },
      { identity = 'stylua', constraint = '=2.5.2', affected_operations = { 'formatting.lua' } },
    })
    expect.equality(child.lua_get([[lua_definition_source.path]]), 'select[4]')
  end)

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

  it('defines and activates LuaLS from the qualified provider definition', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/language_apply/init.lua' })

    expect.equality(child.lua_get([[language_apply_result.status]]), 'performed')
    expect.equality(child.lua_get([[enabled_server]]), 'lua_ls')
    expect.equality(child.lua_get([[lua_ls_config.cmd]]), { vim.uv.fs_realpath(vim.fn.exepath('lua-language-server')) })
    expect.equality(child.lua_get([[lua_ls_config.filetypes]]), { 'lua' })
    expect.equality(child.lua_get([[lua_ls_config.root_markers]]), { '.luarc.json', '.git' })
    expect.equality(child.lua_get([[lua_ls_config.settings]]), {
      Lua = {
        hint = { enable = true, setType = true },
        runtime = { version = 'LuaJIT' },
        workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
        telemetry = { enable = false },
      },
    })
    expect.equality(child.lua_get([[lua_ls_config.capabilities.textDocument.completion]]), {
      completionItem = {
        snippetSupport = true,
        commitCharactersSupport = true,
        documentationFormat = { 'markdown', 'plaintext' },
        deprecatedSupport = true,
        preselectSupport = true,
        tagSupport = { valueSet = { 1 } },
        insertReplaceSupport = true,
        resolveSupport = {
          properties = { 'documentation', 'detail', 'additionalTextEdits', 'command', 'data' },
        },
        insertTextModeSupport = { valueSet = { 1, 2 } },
        labelDetailsSupport = true,
      },
      completionList = {
        itemDefaults = { 'commitCharacters', 'editRange', 'insertTextFormat', 'insertTextMode', 'data' },
      },
      contextSupport = true,
      insertTextMode = 1,
    })
  end)

  it('reports matching LuaLS tool degradation before no_client for all requests', function()
    activate_language()
    child.lua([[
      vim.bo.filetype = 'lua'
      require('plait.state').language_servers = {
        lua_ls = { filetypes = { 'lua' }, tool = 'lua-language-server', state = 'unprobeable', language = 'lang.lua' },
      }
      degraded = {}
      for _, name in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
        degraded[name] = M.actions.language[name]()
      end
    ]])

    for _, name in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
      expect.equality(child.lua_get('degraded.' .. name .. '.reason'), 'tool_unprobeable')
      expect.equality(child.lua_get('degraded.' .. name .. '.details'), {
        buffer = 1,
        position = { line = 0, character = 0 },
        capability = 'language',
        language = 'lang.lua',
        filetype = 'lua',
        server = 'lua_ls',
        tool = 'lua-language-server',
        state = 'unprobeable',
      })
    end
  end)

  it('reports matching TypeScript tool degradation for all LSP requests', function()
    activate_language()
    child.lua([[
      vim.bo.filetype = 'typescriptreact'
      require('plait.state').language_servers = {
        tsc = {
          filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
          tool = 'tsc', state = 'absent', language = 'lang.typescript',
        },
      }
      degraded = {}
      for _, name in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
        degraded[name] = M.actions.language[name]()
      end
      local state = require('plait.state')
      state.completion_active = true
      package.loaded['blink.cmp'] = { is_active = function() return false end, show = function() return true end }
      vim.api.nvim_get_mode = function() return { mode = 'i' } end
      completion_result = M.actions.completion.trigger()
    ]])

    for _, name in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
      expect.equality(child.lua_get('degraded.' .. name .. '.reason'), 'tool_absent')
      expect.equality(child.lua_get('degraded.' .. name .. '.details.language'), 'lang.typescript')
      expect.equality(child.lua_get('degraded.' .. name .. '.details.server'), 'tsc')
      expect.equality(child.lua_get('degraded.' .. name .. '.details.filetype'), 'typescriptreact')
    end
    expect.equality(child.lua_get([[completion_result.status]]), 'performed')
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
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      require('plait.state').operation_feedback = 'all'
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
    expect.equality(child.lua_get([[#M.inspect('diagnostics', 'operation.succeeded')]]), 1)
    expect.equality(child.lua_get([[#notifications]]), 2)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.INFO)
    expect.equality(child.lua_get('notifications[2][2]'), vim.log.levels.INFO)
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
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
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
    expect.equality(child.lua_get([[#notifications]]), 1)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.ERROR)
    expect.equality(child.lua_get([[vim.inspect(operation):find('SECRET', 1, true) == nil]]), true)
  end)

  it('keeps operation records inspectable under every automatic feedback mode', function()
    activate_language()
    child.lua([[
      vim.lsp.get_clients = function()
        return { { supports_method = function() return true end } }
      end
      local failed = false
      vim.lsp.buf.hover = function()
        if failed then error('expected failure') end
      end
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      for _, policy in ipairs({ 'errors', 'all', 'silent' }) do
        require('plait.state').operation_feedback = policy
        local success = M.actions.language.hover()
        vim.wait(1000, function() return M.inspect('operations', success.operation_id).state ~= 'pending' end)
        failed = true
        local failure = M.actions.language.hover()
        vim.wait(1000, function() return M.inspect('operations', failure.operation_id).state ~= 'pending' end)
        failed = false
      end
      feedback_operations = M.inspect('operations')
    ]])

    expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.state end, feedback_operations)]]), {
      'succeeded',
      'failed',
      'succeeded',
      'failed',
      'succeeded',
      'failed',
    })
    expect.equality(child.lua_get([[#notifications]]), 5)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.ERROR)
    expect.equality(child.lua_get('notifications[2][2]'), vim.log.levels.INFO)
    expect.equality(child.lua_get('notifications[3][2]'), vim.log.levels.INFO)
    expect.equality(child.lua_get('notifications[4][2]'), vim.log.levels.INFO)
    expect.equality(child.lua_get('notifications[5][2]'), vim.log.levels.ERROR)
    expect.equality(
      child.lua_get('notifications[2][1]'),
      'Plait operation language.hover started (op-00000003)\nInspect progress: :Plait inspect operations op-00000003'
    )
  end)

  it('orders accepted operations by start time and then identity', function()
    activate_language()
    child.lua([[
      vim.lsp.get_clients = function()
        return { { supports_method = function() return true end } }
      end
      vim.lsp.buf.definition = function() end
      vim.lsp.buf.references = function() end
      local times = { { 200, 0 }, { 100, 0 } }
      vim.uv.gettimeofday = function()
        local value = table.remove(times, 1) or { 300, 0 }
        return value[1], value[2]
      end
      first = M.actions.language.definition()
      second = M.actions.language.references()
      operation_ids = vim.tbl_map(function(item) return item.identity end, M.inspect('operations'))
    ]])

    expect.equality(child.lua_get([[first.operation_id]]), 'op-00000001')
    expect.equality(child.lua_get([[second.operation_id]]), 'op-00000002')
    expect.equality(child.lua_get([[operation_ids]]), { 'op-00000002', 'op-00000001' })
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
