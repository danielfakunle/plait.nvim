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

  it('returns the collector from collection methods', function()
    child.lua([[
      local config = M.config()
      same = config:select({ 'editor' }):configure({ editor = {} }) == config
    ]])

    expect.equality(child.lua_get([[same]]), true)
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
end)
