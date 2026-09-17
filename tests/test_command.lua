local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

describe('Plait command', function()
  it('completes every supported top-level subcommand deterministically', function()
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait ', 'cmdline')]]), {
      'format',
      'inspect',
      'packages',
      'tooling',
      'validate',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait in', 'cmdline')]]), { 'inspect' })
  end)

  it('completes only valid static arguments at each nested command position', function()
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect ', 'cmdline')]]), {
      '--json',
      '--verbose',
      'capabilities',
      'diagnostics',
      'effects',
      'language_servers',
      'modules',
      'operations',
      'packages',
      'tools',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait packages ', 'cmdline')]]), { 'sync', 'sync!' })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait tooling ', 'cmdline')]]), {
      'check',
      'ensure',
      'install',
      'update',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait validate ', 'cmdline')]]), {})
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait packages sync ', 'cmdline')]]), {})
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait tooling check ', 'cmdline')]]), {})
  end)

  it('completes inspection identities, JSON, and effective tool identities without side effects', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua' })
      config:validate()
      completion_snapshot_before = vim.inspect({
        modules = M.inspect('modules'),
        tools = M.inspect('tools'),
        operations = M.inspect('operations'),
      })
    ]])

    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect modules ', 'cmdline')]]), {
      '--json',
      '--verbose',
      'formatting',
      'lang.lua',
      'language',
      'tooling',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect modules la', 'cmdline')]]), {
      'lang.lua',
      'language',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect modules lang.lua ', 'cmdline')]]), {
      '--json',
      '--verbose',
    })
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect operations ', 'cmdline')]]),
      { '--json', '--verbose' }
    )
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait tooling install ', 'cmdline')]]), {
      'lua-language-server',
      'stylua',
    })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait tooling update sty', 'cmdline')]]), { 'stylua' })
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait tooling install stylua ', 'cmdline')]]), {})
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect modules --json --verbose -- ', 'cmdline')]]),
      {}
    )
    expect.equality(
      child.lua_get([[
        completion_snapshot_before == vim.inspect({
          modules = M.inspect('modules'),
          tools = M.inspect('tools'),
          operations = M.inspect('operations'),
        })
      ]]),
      true
    )
  end)

  it('completes repeated diagnostic codes as one accepted inspection identity', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ unknown = true, editor = { line_numbers = 1 } })
      config:validate()
    ]])

    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect diagnostics ', 'cmdline')]]), {
      '--json',
      '--verbose',
      'config.invalid',
    })
    expect.equality(
      child.cmd_capture('Plait inspect diagnostics config.invalid --json'):match('^diagnostics: %['),
      'diagnostics: ['
    )
  end)

  it('renders current-buffer language server inspection without notifications', function()
    child.lua([[
      local state = require('plait.state')
      state.snapshot = {
        diagnostics = {}, operations = {}, modules = {}, capabilities = {}, effects = {}, packages = {}, tools = {},
      }
      state.language_servers.lua_ls = {
        filetypes = { 'lua' }, tool = 'lua-language-server', state = 'satisfied', language = 'lang.lua',
      }
      vim.bo.filetype = 'lua'
      vim.lsp.get_clients = function() return { { name = 'lua_ls' } } end
    ]])

    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect language_servers ', 'cmdline')]]), {
      '--json',
      '--verbose',
      'lua_ls',
    })
    local json = child.cmd_capture('Plait inspect language_servers lua_ls --json')
    expect.equality(json:find('initial diagnostics may be delayed', 1, true) ~= nil, true)
    expect.equality(json:find('.luarc.json', 1, true) ~= nil, true)
  end)

  it('registers one process-wide dispatcher', function()
    expect.equality(child.lua_get([[vim.api.nvim_get_commands({ builtin = false }).Plait.nargs]]), '+')
    expect.equality(
      child.lua_get(
        [[#vim.tbl_filter(function(name) return name == 'Plait' end, vim.tbl_keys(vim.api.nvim_get_commands({ builtin = false })))]]
      ),
      1
    )
  end)

  it('preserves an existing command and records one non-invalidating collision', function()
    child.restart({
      '--clean',
      '--cmd',
      [[command! Plait echo 'external']],
      '-u',
      'scripts/minimal_init.lua',
    })
    child.lua([[M = require('plait')]])
    child.cmd('runtime plugin/plait.lua')

    expect.equality(child.cmd_capture('Plait'), 'external')

    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[#result.diagnostics]]), 1)
    expect.equality(child.lua_get([=[result.diagnostics[1]]=]), {
      code = 'bootstrap.command_collision',
      severity = 'error',
      summary = 'Command Plait already exists; :Plait was not registered.',
      repair = 'Remove or rename the existing command, then restart.',
      related_sources = {},
      details = { identity = 'Plait', observed_owner = 'external' },
    })
    expect.equality(child.lua_get([[M.inspect('diagnostics')]]), child.lua_get([[result.diagnostics]]))
  end)

  it('validates sealed configuration through the public contract', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      pcall(function() config:apply('seal') end)
    ]])

    local output = child.cmd_capture('Plait validate')
    expect.equality(output:match('^valid [0-9a-f]+$') and #output, 70)
    expect.equality(child.lua_get([[M.inspect('modules', 'editor').identity]]), 'editor')
  end)

  it('opens a readable report in the empty current window and refreshes it in place', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
    ]])

    expect.equality(child.cmd_capture('Plait inspect'), '')
    expect.equality(child.lua_get([[vim.api.nvim_buf_get_name(0)]]), 'plait://inspect')
    expect.equality(child.lua_get([[vim.bo.filetype]]), 'plait-report')
    expect.equality(child.lua_get([[vim.bo.modifiable]]), false)
    expect.equality(child.lua_get([[vim.bo.swapfile]]), false)
    expect.equality(child.lua_get([[vim.bo.bufhidden]]), 'wipe')
    expect.equality(child.lua_get([[vim.fn.maparg('q', 'n', false, true).buffer]]), 1)
    local report = child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
    expect.equality(report:find('Modules\n  [ACTIVE] editor', 1, true) ~= nil, true)
    expect.equality(report:find('    Provides:\n      - editor', 1, true) ~= nil, true)
    expect.equality(report:find('[ACTIVE] editor\n    Integration:', 1, true) ~= nil, true)
    expect.equality(report:find('Managed effects\n  [PENDING] editor/native-options', 1, true) ~= nil, true)
    expect.equality(report:find('Packages\n  No package requirements.', 1, true) ~= nil, true)
    expect.equality(report:find('Tools\n  No tool requirements.', 1, true) ~= nil, true)
    expect.equality(report:find('Diagnostics\n  No diagnostics.', 1, true) ~= nil, true)
    expect.equality(report:find('Operations\n  No operations.', 1, true) ~= nil, true)

    child.cmd('Plait inspect modules editor')
    expect.equality(child.lua_get([[#vim.api.nvim_list_bufs()]]), 1)
    expect.equality(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, 3, false)]]), {
      'Plait inspection',
      '',
      'Modules',
    })
  end)

  it('opens inspection in a dedicated tab without replacing an editing buffer', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      vim.api.nvim_buf_set_name(0, 'notes.txt')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'keep me' })
      editing_buffer = vim.api.nvim_get_current_buf()
    ]])

    child.cmd('Plait inspect modules')
    expect.equality(child.lua_get([[#vim.api.nvim_list_tabpages()]]), 2)
    expect.equality(child.lua_get([[vim.api.nvim_buf_get_name(editing_buffer)]]):match('notes.txt$'), 'notes.txt')
    expect.equality(child.lua_get([[vim.api.nvim_buf_get_lines(editing_buffer, 0, -1, false)]]), { 'keep me' })
    child.cmd('tabprevious')
    child.cmd('Plait inspect capabilities')
    expect.equality(child.lua_get([[#vim.api.nvim_list_tabpages()]]), 2)
    expect.equality(
      child.lua_get(
        [[#vim.tbl_filter(function(buffer) return vim.api.nvim_buf_get_name(buffer) == 'plait://inspect' end, vim.api.nvim_list_bufs())]]
      ),
      1
    )
    child.cmd('normal q')
    expect.equality(child.lua_get([[#vim.api.nvim_list_tabpages()]]), 1)
    expect.equality(child.lua_get([[vim.api.nvim_get_current_buf()]]), child.lua_get([[editing_buffer]]))
  end)

  it('closes only a report that reused an empty split', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      vim.api.nvim_buf_set_name(0, 'editing.txt')
      editing_buffer = vim.api.nvim_get_current_buf()
      vim.cmd.vnew()
      vim.cmd.tabnew()
      vim.api.nvim_buf_set_name(0, 'other-tab.txt')
      vim.cmd.tabprevious()
    ]])

    child.cmd('Plait inspect modules')
    child.cmd('normal q')
    expect.equality(child.lua_get([[#vim.api.nvim_list_tabpages()]]), 2)
    expect.equality(child.lua_get([[vim.api.nvim_buf_is_valid(editing_buffer)]]), true)
    expect.equality(child.lua_get([[vim.api.nvim_buf_get_name(editing_buffer)]]):match('editing.txt$'), 'editing.txt')
  end)

  it('preserves deterministic machine-readable inspection behind --json', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
    ]])

    expect.equality(child.cmd_capture('Plait inspect packages --json'), 'packages: []')
    local output = child.cmd_capture('Plait inspect modules editor --json')
    expect.equality(output:match('^modules: {'), 'modules: {')
    expect.equality(output:find('"identity":"editor"', 1, true) ~= nil, true)
  end)

  it('uses section-specific fields and distinguishable report states', function()
    child.lua([[
      M.inspect = function(section)
        local fixtures = {
          modules = { { identity = 'demo', state = 'invalid', provides = {}, requires = { 'base' }, contributions = {}, selection_sources = { { file = 'init.lua', line = 12, path = 'select[1]' } } } },
          capabilities = { { identity = 'demo', state = 'degraded', responsible_integration = 'demo/native', providers = { 'native' }, dependents = {}, actions = {}, degradation_reasons = { 'tool.absent' }, configuration = { values = { nested = { enabled = true } }, sources = { nested = { file = 'init.lua', line = 15, path = 'configure.demo.nested' } }, providers = { { identity = 'demo.nvim', target = 'setup', value = { mode = 'safe' } } } } } },
          effects = { { identity = 'demo/effect', state = 'pending', responsible_capability = 'demo', provider = 'demo.nvim', stage = 2, dependencies = {}, error = { summary = 'Provider stopped.', details = { cause = 'bad option' } } } },
          language_servers = {},
          packages = { { identity = 'demo.nvim', state = 'satisfied', source = 'https://example.test/demo', required_commit = 'abc', responsible_capabilities = { 'demo' }, repair = '' } },
          tools = { { identity = 'demo', state = 'absent', executable = 'demo', constraint = '>=1,<2', ownership = 'project', affected_operations = { 'demo.run' }, repair = 'Install demo in the project.' } },
          diagnostics = { { code = 'demo.failed', severity = 'error', summary = 'Demo failed.', repair = 'Repair demo.', details = { target = 'demo' } } },
          operations = {
            { identity = 'op-00000001', state = 'succeeded', operation = 'demo.run', targets = { 'one' }, diagnostic_codes = { 'operation.succeeded' } },
            { identity = 'op-00000002', state = 'failed', operation = 'demo.run', targets = { 'two' }, error = { reason = 'execution_failed', message = 'Demo stopped.' }, diagnostic_codes = { 'operation.failed' } },
          },
        }
        return vim.deepcopy(fixtures[section])
      end
    ]])

    child.cmd('Plait inspect --verbose')
    local report = child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
    for _, text in ipairs({
      '[INVALID] demo',
      '[DEGRADED] demo',
      '[PENDING] demo/effect',
      '[SATISFIED] demo.nvim',
      '[ABSENT] demo',
      '[ERROR] demo.failed',
      '[SUCCEEDED] op-00000001',
      '[FAILED] op-00000002',
      'Version constraint: >=1,<2',
      'Repair: Install demo in the project.',
      'Affected:\n      target: demo',
      'Selected at:\n      - file: init.lua\n        line: 12\n        path: select[1]',
      'Configuration:\n      providers:\n        - identity: demo.nvim',
      'values:\n        nested:\n          enabled: true',
      'Error:\n      details:\n        cause: bad option',
    }) do
      expect.equality(report:find(text, 1, true) ~= nil, true)
    end
    expect.equality(report:find('Repair:\n', 1, true) == nil, true)
  end)

  it('renders unavailable action context and repair guidance without JSON', function()
    child.lua([[
      M.actions.tooling.ensure = function()
        return {
          status = 'unavailable', operation = 'tooling.ensure', reason = 'capability_inactive',
          details = { capability = 'tooling', targets = { 'stylua', 'lua-language-server' } },
        }
      end
    ]])

    expect.equality(
      child.cmd_capture('Plait tooling ensure'),
      'plait: tooling.ensure unavailable: capability inactive\nAffected capability: tooling\nAffected targets: stylua, lua-language-server\nRepair: activate the tooling capability, validate again, then retry.'
    )
  end)

  it('routes package sync bang through the public package action', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
    ]])

    expect.equality(child.cmd_capture('Plait packages sync!'), 'Plait: Packages are already satisfied.')
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  end)

  it('routes tooling commands through the public tooling actions', function()
    child.lua([[
      local config = M.config()
      config:select({ 'tooling' })
      config:validate()
    ]])

    expect.equality(child.cmd_capture('Plait tooling check'), 'Plait: No tool requirements.')
    expect.equality(child.cmd_capture('Plait tooling ensure'), 'Plait: Tools are already satisfied.')
  end)

  it('routes command ranges through the shared formatting action', function()
    child.lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'second', 'three' })
      M.actions.formatting.format = function(options)
        command_format_options = vim.deepcopy(options)
        return {
          status = 'started', operation = 'formatting.format', operation_id = 'op-00000009',
          details = { buffer = 1, range = options.range, chain = { 'demo' } },
        }
      end
    ]])

    expect.equality(child.cmd_capture('2,3Plait format'), '')
    expect.equality(child.lua_get([[command_format_options]]), {
      range = {
        start = { line = 1, character = 0 },
        end_ = { line = 2, character = 5 },
      },
    })
  end)

  it('applies every automatic operation feedback policy to command results', function()
    child.lua([[
      M.actions.tooling.check = function()
        return { status = 'performed', operation = 'tooling.check', details = {} }
      end
      M.actions.tooling.ensure = function()
        return { status = 'unavailable', operation = 'tooling.ensure', reason = 'capability_inactive',
          details = { capability = 'tooling' } }
      end
    ]])

    child.lua([[require('plait.state').operation_feedback = 'errors']])
    expect.equality(child.cmd_capture('Plait tooling check'), 'Plait: No tool requirements.')
    expect.equality(
      child.cmd_capture('Plait tooling ensure'):match('^plait: tooling.ensure unavailable'),
      'plait: tooling.ensure unavailable'
    )

    child.lua([[require('plait.state').operation_feedback = 'all']])
    expect.equality(
      child.cmd_capture('Plait tooling check'),
      'Plait: No tool requirements.\nplait: tooling.check performed'
    )

    child.lua([[require('plait.state').operation_feedback = 'silent']])
    expect.equality(child.cmd_capture('Plait tooling ensure'), '')
  end)
end)
