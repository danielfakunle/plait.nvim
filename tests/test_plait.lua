local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

local minimal_editor = [[
  config = M.config()
  config:select({ 'editor' })
  config:configure({
    editor = {
      line_numbers = 'absolute',
      persistent_undo = true,
      yank_highlight = true,
      splits = { horizontal = 'below', vertical = 'right' },
      indentation = { style = 'spaces', width = 2 },
      wrap = false,
      clipboard = 'auto',
      mappings = {
        save = '<C-s>',
        clear_search = '<Esc>',
        focus_left = '<C-h>',
        focus_down = '<C-j>',
        focus_up = '<C-k>',
        focus_right = '<C-l>',
      },
    },
  })
]]

describe('effective plan', function()
  it('validates and publishes the minimal editor plan', function()
    child.lua(minimal_editor .. [[result = config:validate()]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[result.diagnostics]]), {})
    expect.equality(child.lua_get([[result.plan_id:match('^[0-9a-f]+$') and #result.plan_id]]), 64)
    expect.equality(child.lua_get([[M.inspect('modules')]]), {
      {
        identity = 'editor',
        state = 'active',
        selection_sources = {
          { file = '<nvim>', line = 2, path = 'select[1]' },
        },
        provides = { 'editor' },
        requires = {},
        ordering_edges = {},
        contributions = { 'editor.configuration' },
      },
    })
    expect.equality(child.lua_get([[M.inspect('capabilities')]]), {
      {
        identity = 'editor',
        state = 'active',
        activator = 'editor',
        cardinality = 'exclusive',
        responsible_integration = 'editor/native',
        dependents = {},
        providers = {},
        configuration = {
          line_numbers = 'absolute',
          persistent_undo = true,
          yank_highlight = true,
          splits = { horizontal = 'below', vertical = 'right' },
          indentation = { style = 'spaces', width = 2 },
          wrap = false,
          clipboard = 'auto',
          mappings = {
            save = '<C-s>',
            clear_search = '<Esc>',
            focus_left = '<C-h>',
            focus_down = '<C-j>',
            focus_up = '<C-k>',
            focus_right = '<C-l>',
          },
        },
        contributions = { 'editor.configuration' },
        actions = {
          'editor.clear_search',
          'editor.focus',
          'editor.save',
        },
        degradation_reasons = {},
      },
    })
  end)

  it('returns detached inspection records', function()
    child.lua(minimal_editor .. [[
      config:validate()
      local first = M.inspect('modules')
      first[1].identity = 'changed'
      detached = M.inspect('modules')
    ]])

    expect.equality(child.lua_get([[detached[1].identity]]), 'editor')
    expect.equality(child.cmd_capture('Plait inspect packages'), 'packages: []')
    expect.equality(child.cmd_capture('Plait inspect modules'):find('"requires":[]', 1, true) ~= nil, true)
  end)

  it('revalidates deterministically and permits only one collector', function()
    child.lua(minimal_editor .. [[
      first = config:validate()
      second = config:validate()
      second_collector_ok, second_collector_error = pcall(M.config)
    ]])

    expect.equality(child.lua_get([[second.plan_id]]), child.lua_get([[first.plan_id]]))
    expect.equality(child.lua_get([[second_collector_ok]]), false)
    expect.equality(
      child.lua_get([[second_collector_error:match('plait: a configuration collector already exists$')]]),
      'plait: a configuration collector already exists'
    )
  end)

  it('revalidates newly collected declarations without sealing', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      first = config:validate()
      config:configure({ editor = { wrap = true } })
      second = config:validate()
    ]])

    expect.equality(child.lua_get([[first.status]]), 'valid')
    expect.equality(child.lua_get([[first.plan.capabilities[1].configuration.wrap]]), false)
    expect.equality(child.lua_get([[second.plan.capabilities[1].configuration.wrap]]), true)
    expect.equality(child.lua_get([[first.plan_id ~= second.plan_id]]), true)
  end)

  it('returns the collector from collection methods', function()
    child.lua([[
      local config = M.config()
      same = config:select({ 'editor' }):configure({ editor = {} }):override({}):providers({}) == config
    ]])

    expect.equality(child.lua_get([[same]]), true)
  end)

  it('seals at first apply entry before argument checks', function()
    child.lua(minimal_editor .. [[
      config:validate()
      first_ok, first_error = pcall(function() config:apply('unexpected') end)
      collect_ok, collect_error = pcall(function() config:select({ 'editor' }) end)
      second_ok, second_error = pcall(function() config:apply() end)
      collector_ok, collector_error = pcall(M.config)
      diagnostics = M.inspect('diagnostics')
    ]])

    expect.equality(child.lua_get([[first_ok]]), false)
    expect.equality(
      child.lua_get([[first_error:match('plait: apply expects no arguments$')]]),
      'plait: apply expects no arguments'
    )
    expect.equality(child.lua_get([[collect_ok]]), false)
    expect.equality(
      child.lua_get([[collect_error:match('plait: configuration collector is sealed$')]]),
      'plait: configuration collector is sealed'
    )
    expect.equality(child.lua_get([[second_ok]]), false)
    expect.equality(
      child.lua_get([[second_error:match('plait: apply may only be called once$')]]),
      'plait: apply may only be called once'
    )
    expect.equality(child.lua_get([[collector_ok]]), false)
    expect.equality(
      child.lua_get([[collector_error:match('plait: a configuration collector already exists$')]]),
      'plait: a configuration collector already exists'
    )
    expect.equality(child.lua_get([[diagnostics]]), {})
  end)

  it('rejects every collection method after sealing', function()
    child.lua([[
      local config = M.config()
      pcall(function() config:apply('unexpected') end)
      errors = {}
      for _, call in ipairs({
        function() config:select({ 'editor' }) end,
        function() config:configure({ editor = {} }) end,
        function() config:override({}) end,
        function() config:providers({}) end,
      }) do
        local ok, err = pcall(call)
        errors[#errors + 1] = { ok = ok, sanitized = err:match('plait: configuration collector is sealed$') }
      end
    ]])

    expect.equality(child.lua_get([[errors]]), {
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
    })
  end)

  it('collects disjoint declarations across repeated calls', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { wrap = true } })
      config:configure({ editor = { persistent_undo = false } })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[result.plan.capabilities[1].configuration.wrap]]), true)
    expect.equality(child.lua_get([[result.plan.capabilities[1].configuration.persistent_undo]]), false)
  end)

  it('rejects incompatible repeated declarations without call-order precedence', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { wrap = true } })
      config:configure({ editor = { wrap = false } })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.effects]]), {})
  end)

  it('keeps prior results and inspections detached across snapshot replacement', function()
    child.lua(minimal_editor .. [[
      first = config:validate()
      first.plan.modules[1].identity = 'changed-result'
      first.diagnostics[1] = { code = 'changed-result' }

      inspection = M.inspect('capabilities')
      inspection[1].configuration.mappings.save = 'changed-inspection'

      config:configure({ editor = { wrap = 'invalid' } })
      second = config:validate()
      current = M.inspect('capabilities')
      current_diagnostics = M.inspect('diagnostics')
    ]])

    expect.equality(child.lua_get([[second.status]]), 'invalid')
    expect.equality(child.lua_get([[first.plan.capabilities[1].configuration.mappings.save]]), '<C-s>')
    expect.equality(child.lua_get([[current]]), {})
    expect.equality(child.lua_get([[current_diagnostics[1].code]]), 'config.invalid')
    expect.equality(child.lua_get([[M.inspect('diagnostics') ~= current_diagnostics]]), true)
  end)

  it('raises sanitized inspection misuse without changing the snapshot', function()
    child.lua(minimal_editor .. [[
      config:validate()
      before = M.inspect('modules')
      section_ok, section_error = pcall(function() M.inspect('missing\nsecret') end)
      identity_ok, identity_error = pcall(function() M.inspect('modules', 'missing\nsecret') end)
      after = M.inspect('modules')
      inspections_detached = before ~= after and before[1] ~= after[1]
    ]])

    expect.equality(child.lua_get([[section_ok]]), false)
    expect.equality(
      child.lua_get([[section_error:match('plait: unknown inspection section$')]]),
      'plait: unknown inspection section'
    )
    expect.equality(child.lua_get([[identity_ok]]), false)
    expect.equality(
      child.lua_get([[identity_error:match('plait: inspection identity not found$')]]),
      'plait: inspection identity not found'
    )
    expect.equality(child.lua_get([[vim.deep_equal(before, after)]]), true)
    expect.equality(child.lua_get([[inspections_detached]]), true)
  end)

  it('rejects inspection before a completed snapshot and invalid requests', function()
    child.lua([[
      before_ok, before_error = pcall(function() M.inspect('modules') end)
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      section_ok, section_error = pcall(function() M.inspect('') end)
      identity_ok, identity_error = pcall(function() M.inspect('modules', {}) end)
    ]])

    expect.equality(child.lua_get([[before_ok]]), false)
    expect.equality(
      child.lua_get([[before_error:match('plait: inspection requires a completed snapshot$')]]),
      'plait: inspection requires a completed snapshot'
    )
    expect.equality(child.lua_get([[section_ok]]), false)
    expect.equality(
      child.lua_get([[section_error:match('plait: inspection section must be a non%-empty string$')]]),
      'plait: inspection section must be a non-empty string'
    )
    expect.equality(child.lua_get([[identity_ok]]), false)
    expect.equality(
      child.lua_get([[identity_error:match('plait: inspection identity must be a non%-empty string$')]]),
      'plait: inspection identity must be a non-empty string'
    )
  end)
end)
