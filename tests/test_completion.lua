local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

describe('completion capability facade', function()
  it('distinguishes an inactive capability with closed details', function()
    child.lua([[inactive = M.actions.completion.trigger()]])

    expect.equality(child.lua_get([[inactive]]), {
      status = 'unavailable',
      operation = 'completion.trigger',
      reason = 'capability_inactive',
      details = { capability = 'completion' },
    })
  end)

  it('distinguishes inactive sessions, missing candidates, and unavailable documentation', function()
    child.lua([[
      local state = require('plait.state')
      state.completion_active = true
      local visible = false
      package.loaded['blink.cmp'] = {
        is_active = function() return visible end,
        show = function()
          show_called = true
          return true
        end,
        select_next = function() return false end,
        scroll_documentation_down = function() return false end,
      }
      no_session = M.actions.completion.trigger()
      visible = true
      no_candidate = M.actions.completion.next()
      no_documentation = M.actions.completion.scroll_documentation(1)
    ]])

    expect.equality(child.lua_get([[no_session]]), {
      status = 'unavailable',
      operation = 'completion.trigger',
      reason = 'completion_inactive',
      details = { buffer = 1 },
    })
    expect.equality(child.lua_get([[show_called]]), vim.NIL)
    expect.equality(child.lua_get([[no_candidate]]), {
      status = 'unavailable',
      operation = 'completion.next',
      reason = 'no_candidate',
      details = { buffer = 1 },
    })
    expect.equality(child.lua_get([[no_documentation]]), {
      status = 'unavailable',
      operation = 'completion.scroll_documentation',
      reason = 'documentation_unavailable',
      details = { buffer = 1 },
    })
  end)

  it('applies the exact Blink policy and fixed insert mappings with native fallback', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })

    expect.equality(child.lua_get([[completion_apply_result.status]]), 'performed')
    expect.equality(child.lua_get([[blink_setup]]), {
      appearance = { nerd_font_variant = 'mono' },
      keymap = { preset = 'none' },
      enabled = true,
      completion = {
        menu = { enabled = true, auto_show = false },
        trigger = { show_on_keyword = false, show_on_trigger_character = false },
        documentation = { auto_show = true },
      },
      signature = { enabled = false },
      sources = { default = { 'path', 'buffer', 'snippets', 'lsp' } },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    })
    expect.equality(child.lua_get([[vim.fn.maparg('<CR>', 'i', false, true)]]), {})
    expect.equality(child.lua_get([[(vim.fn.maparg('<Tab>', 'i', false, true).sid or 0) <= 0]]), true)
    expect.equality(child.lua_get([[vim.fn.maparg('<C-n>', 'i', false, true).callback()]]), '<C-n>')
  end)

  it('shows documentation when a candidate is explicitly selected by default', function()
    child.restart({
      '--clean',
      '--cmd',
      "lua vim.g.completion_documentation = 'selected'",
      '-u',
      'tests/fixtures/completion_apply/init.lua',
    })

    expect.equality(child.lua_get([[blink_setup.completion.documentation.auto_show]]), true)
  end)
end)
