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
    expect.equality(child.lua_get([[type(blink_setup.enabled)]]), 'function')
    expect.equality(child.lua_get([[blink_setup.enabled()]]), true)
    child.lua([[
      blink_setup_without_enabled = vim.deepcopy(blink_setup)
      blink_setup_without_enabled.enabled = nil
      blink_cmdline_auto_show = blink_setup_without_enabled.cmdline.completion.menu.auto_show
      blink_setup_without_enabled.cmdline.completion.menu.auto_show = nil
    ]])
    expect.equality(child.lua_get([[blink_setup_without_enabled]]), {
      appearance = { nerd_font_variant = 'mono' },
      keymap = { preset = 'none' },
      completion = {
        menu = { enabled = true, auto_show = false },
        trigger = { show_on_keyword = false, show_on_trigger_character = false },
        list = { selection = { preselect = false } },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
      },
      signature = { enabled = false },
      sources = { default = { 'path', 'buffer', 'snippets', 'lsp' } },
      cmdline = {
        enabled = true,
        keymap = { preset = 'cmdline', ['<Right>'] = false, ['<Left>'] = false },
        completion = {
          list = { selection = { preselect = false } },
          menu = {},
          ghost_text = { enabled = true },
        },
      },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    })
    expect.equality(child.lua_get([[type(blink_cmdline_auto_show)]]), 'function')
    expect.equality(child.lua_get([[blink_cmdline_auto_show()]]), false)
    expect.equality(child.lua_get([[vim.fn.maparg('<CR>', 'i', false, true).callback()]]), '<CR>')
    expect.equality(child.lua_get([[vim.fn.maparg('<C-y>', 'i', false, true).callback()]]), '<C-y>')
    expect.equality(child.lua_get([[vim.fn.maparg('<Up>', 'i', false, true).callback()]]), '<Up>')
    expect.equality(child.lua_get([[vim.fn.maparg('<Down>', 'i', false, true).callback()]]), '<Down>')
    expect.equality(child.lua_get([[(vim.fn.maparg('<Tab>', 'i', false, true).sid or 0) <= 0]]), true)
    expect.equality(child.lua_get([[vim.fn.maparg('<C-n>', 'i', false, true).callback()]]), '<C-n>')
  end)

  it('satisfies the qualified Blink revision enabled contract', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })

    expect.equality(child.lua_get([[type(blink_setup.enabled)]]), 'function')
  end)

  it('accepts on Enter only after selection and lets Ctrl-Y select the first candidate', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })
    child.lua([[
      local selected = false
      local calls = {}
      package.loaded['blink.cmp'] = {
        is_active = function() return true end,
        get_selected_item = function() return selected and { label = 'first' } or nil end,
        select_and_accept = function()
          if not selected then selected = true; calls[#calls + 1] = 'select' end
          calls[#calls + 1] = 'accept'
          return true
        end,
        accept = function() calls[#calls + 1] = 'accept'; return true end,
      }
      enter_without_selection = vim.fn.maparg('<CR>', 'i', false, true).callback()
      ctrl_y = vim.fn.maparg('<C-y>', 'i', false, true).callback()
      enter_with_selection = vim.fn.maparg('<CR>', 'i', false, true).callback()
      accepted_calls = calls
    ]])
    expect.equality(child.lua_get([[enter_without_selection]]), '<CR>')
    expect.equality(child.lua_get([[ctrl_y]]), '')
    expect.equality(child.lua_get([[enter_with_selection]]), '')
    expect.equality(child.lua_get([[accepted_calls]]), { 'select', 'accept', 'accept' })
  end)

  it('uses Ctrl-Space to show completion and toggle documentation', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })
    child.type_keys('i')
    child.lua([[
      local active, documentation = false, false
      local calls = {}
      package.loaded['blink.cmp'] = {
        is_active = function() return active end,
        is_documentation_visible = function() return documentation end,
        show = function() active = true; calls[#calls + 1] = 'show'; return true end,
        show_documentation = function() documentation = true; calls[#calls + 1] = 'show_documentation'; return true end,
        hide_documentation = function() documentation = false; calls[#calls + 1] = 'hide_documentation'; return true end,
      }
      local callback = vim.fn.maparg('<C-Space>', 'i', false, true).callback
      trigger_results = { callback(), callback(), callback() }
      trigger_calls = calls
    ]])
    expect.equality(child.lua_get([[trigger_results]]), { '', '', '' })
    expect.equality(child.lua_get([[trigger_calls]]), { 'show', 'show_documentation', 'hide_documentation' })
  end)

  it('does not insert text when Ctrl-Space is pressed with an open completion menu', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })
    child.type_keys('iword<Esc>a')
    child.lua([[
      package.loaded['blink.cmp'] = {
        is_active = function() return true end,
        is_documentation_visible = function() return false end,
        show_documentation = function() return false end,
      }
    ]])
    child.type_keys('<C-Space>')
    expect.equality(child.lua_get([[vim.api.nvim_get_current_line()]]), 'word')
  end)

  it('navigates with arrows and Ctrl keys, and hides completion with Ctrl-E', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/completion_apply/init.lua' })
    child.lua([[
      local calls = {}
      package.loaded['blink.cmp'] = {
        is_active = function() return true end,
        select_prev = function() calls[#calls + 1] = 'previous'; return true end,
        select_next = function() calls[#calls + 1] = 'next'; return true end,
        hide = function() calls[#calls + 1] = 'hide'; return true end,
      }
      navigation_results = {
        vim.fn.maparg('<Up>', 'i', false, true).callback(),
        vim.fn.maparg('<Down>', 'i', false, true).callback(),
        vim.fn.maparg('<C-p>', 'i', false, true).callback(),
        vim.fn.maparg('<C-n>', 'i', false, true).callback(),
        vim.fn.maparg('<C-e>', 'i', false, true).callback(),
      }
      navigation_calls = calls
    ]])
    expect.equality(child.lua_get([[navigation_results]]), { '', '', '', '', '' })
    expect.equality(child.lua_get([[navigation_calls]]), { 'previous', 'next', 'previous', 'next', 'hide' })
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
