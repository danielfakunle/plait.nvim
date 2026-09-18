local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

describe('public result rendering', function()
  it('renders a valid validation result without mutating it or the editor', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      render_value = config:validate()
      render_before = vim.deepcopy(render_value)
      render_buffer = vim.api.nvim_get_current_buf()
      render_windows = #vim.api.nvim_list_wins()
      render_text = M.render(render_value)
    ]])

    local plan_id = child.lua_get([[render_value.plan_id]])
    expect.equality(
      child.lua_get([[render_text]]),
      table.concat({
        'plait: validation valid',
        'Plan ID: ' .. plan_id,
        'Diagnostics: none',
      }, '\n')
    )
    expect.equality(child.lua_get([[vim.deep_equal(render_value, render_before)]]), true)
    expect.equality(child.lua_get([[vim.api.nvim_get_current_buf() == render_buffer]]), true)
    expect.equality(child.lua_get([[#vim.api.nvim_list_wins() == render_windows]]), true)
  end)

  it('renders invalid validation diagnostics with repair guidance', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { line_numbers = 'bad' } })
      render_text = M.render(config:validate())
    ]])

    expect.equality(
      child.lua_get([[render_text]]),
      table.concat({
        'plait: validation invalid',
        'Diagnostics (1):',
        '  ERROR config.invalid: Invalid value at configure.editor.line_numbers. '
          .. '[at <nvim>:3 configure.editor.line_numbers] '
          .. '[repair: Use one value/form named by `expected`.] '
          .. '[affected: expected: one of "absolute", "relative", "off"; observed: "bad"; '
          .. 'path: configure.editor.line_numbers]',
      }, '\n')
    )
  end)

  it('renders closed performed, started, and unavailable action outcomes', function()
    child.lua([[
      rendered_actions = {
        M.render({ status = 'performed', operation = 'editor.save', details = { buffer = 7 } }),
        M.render({
          status = 'started', operation = 'formatting.format', operation_id = 'op-00000009',
          details = { buffer = 7, range = vim.NIL, chain = { 'stylua' } },
        }),
        M.render({
          status = 'unavailable', operation = 'tooling.ensure', reason = 'capability_inactive',
          details = { capability = 'tooling' },
        }),
        M.render({
          status = 'unavailable', operation = 'language.hover', reason = 'no_client',
          details = { buffer = 7, position = { line = 0, character = 0 } },
        }),
      }
    ]])

    expect.equality(child.lua_get([[rendered_actions]]), {
      'plait: editor.save performed\nDetails buffer: 7',
      table.concat({
        'plait: formatting.format started (op-00000009)',
        'Details buffer: 7',
        'Details chain: stylua',
        'Details range: none',
        'Inspect progress: :Plait inspect operations op-00000009',
      }, '\n'),
      table.concat({
        'plait: tooling.ensure unavailable: capability inactive',
        'Affected capability: tooling',
        'Repair: activate the tooling capability, validate again, then retry.',
      }, '\n'),
      table.concat({
        'plait: language.hover unavailable: no client',
        'Affected buffer: 7',
        'Affected position: (character: 0; line: 0)',
        'Repair: inspect diagnostics and the affected targets, repair them, then retry.',
      }, '\n'),
    })
  end)

  it('preserves execution-failure redaction from the action result contract', function()
    child.lua([[
      local state = require('plait.state')
      state.editor_active = true
      state.applied_plan_id = string.rep('a', 64)
      state.applied_effects = { completed = {}, failed = {}, skipped = {} }
      vim.cmd.enew()
      vim.bo.buftype = 'nofile'
      vim.api.nvim_buf_set_name(0, 'token=SECRET')
      local failure = M.actions.editor.save()
      render_failure_text = M.render(failure)
      render_failure_status = failure.status
    ]])

    expect.equality(child.lua_get([[render_failure_status]]), 'unavailable')
    expect.equality(child.lua_get([[render_failure_text:find('SECRET', 1, true) == nil]]), true)
    expect.equality(child.lua_get([[render_failure_text:find('execution failed', 1, true) ~= nil]]), true)
  end)

  it('rejects unsupported values with one bounded sanitized error', function()
    child.lua([[
      local hostile = setmetatable({ status = 'performed\nsecret', operation = string.rep('x', 1000) }, {})
      render_ok, render_error = pcall(M.render, hostile)
      local cyclic = { status = 'performed', operation = 'editor.save', details = {} }
      cyclic.details.cyclic = cyclic.details
      render_cycle_ok, render_cycle_error = pcall(M.render, cyclic)
      render_secret_ok, render_secret_error = pcall(M.render, {
        status = 'failed', operation = 'language.hover', reason = 'execution_failed',
        details = { message = 'token=SECRET\ntrace' },
      })
    ]])

    expect.equality(child.lua_get([[render_ok]]), false)
    expect.equality(child.lua_get([[render_error]]), 'plait: render expects a Plait validation or action result')
    expect.equality(child.lua_get([[#render_error < 100]]), true)
    expect.equality(child.lua_get([[render_cycle_ok]]), false)
    expect.equality(child.lua_get([[render_cycle_error]]), 'plait: render expects a Plait validation or action result')
    expect.equality(child.lua_get([[render_secret_ok]]), false)
    expect.equality(child.lua_get([[render_secret_error:find('SECRET', 1, true) == nil]]), true)
  end)
end)
