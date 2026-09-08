local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

local function restart_with_init(path) child.restart({ '--clean', '-u', path }) end

describe('editor capability application', function()
  it('re-resolves and applies configured native behavior during init.lua', function()
    restart_with_init('tests/fixtures/editor_apply/init.lua')

    expect.equality(child.lua_get([[validation.plan_id ~= apply_result.details.plan_id]]), true)
    expect.equality(child.lua_get([[apply_result]]), {
      status = 'performed',
      operation = 'apply',
      details = {
        plan_id = child.lua_get([[apply_result.details.plan_id]]),
        effects = {
          completed = {
            'editor/native-options',
            'editor/actions',
            'editor/mappings',
          },
          failed = {},
          skipped = {},
        },
      },
    })
    expect.equality(
      child.lua_get([[
        {
          vim.o.termguicolors,
          vim.o.ignorecase,
          vim.o.smartcase,
          vim.o.signcolumn,
          vim.o.number,
          vim.o.relativenumber,
          vim.o.undofile,
          vim.o.splitbelow,
          vim.o.splitright,
          vim.o.expandtab,
          vim.o.shiftwidth,
          vim.o.tabstop,
          vim.o.softtabstop,
          vim.o.wrap,
          vim.o.linebreak,
          vim.o.breakindent,
          vim.o.clipboard,
        }
      ]]),
      { true, true, true, 'yes', true, true, false, false, false, false, 4, 4, -1, true, true, true, '' }
    )
    expect.equality(child.lua_get([[vim.g.clipboard.name]]), 'OSC 52')
    expect.equality(child.lua_get([[type(vim.g.clipboard.copy['+'])]]), 'function')
    expect.equality(child.lua_get([[vim.g.clipboard.paste == nil]]), true)
    expect.equality(
      child.lua_get([[vim.tbl_map(function(effect) return effect.state end, M.inspect('effects'))]]),
      { 'completed', 'completed', 'completed' }
    )
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
    expect.equality(
      child.lua_get(
        [[pcall(vim.api.nvim_get_autocmds, { event = 'TextYankPost', group = 'plait.editor.yank_highlight' })]]
      ),
      false
    )
  end)

  it('installs exact mapping modes and honors replacements and disables', function()
    restart_with_init('tests/fixtures/editor_apply/init.lua')

    expect.equality(
      child.lua_get([[
        (function()
          local rows = {}
          for _, mode in ipairs({ 'n', 'i', 'x', 's' }) do
            local mapping = vim.fn.maparg('<leader>w', mode, false, true)
            rows[#rows + 1] = { mode, mapping.buffer, type(mapping.callback) }
          end
          return rows
        end)()
      ]]),
      {
        { 'n', 0, 'function' },
        { 'i', 0, 'function' },
        { 'x', 0, 'function' },
        { 's', 0, 'function' },
      }
    )
    expect.equality(child.lua_get([[vim.fn.maparg('<Esc>', 'n')]]), '')
    expect.equality(child.lua_get([[vim.fn.maparg('<C-h>', 'n')]]), '')
    expect.equality(
      child.lua_get([[vim.inspect(vim.fn.maparg('<CR>', 'i', false, true))]]),
      child.lua_get([[enter_mapping_before]])
    )
    expect.equality(
      child.lua_get([[vim.inspect(vim.fn.maparg('<Tab>', 'i', false, true))]]),
      child.lua_get([[tab_mapping_before]])
    )
  end)

  it('owns the exact optional yank-highlight autocmd', function()
    restart_with_init('tests/fixtures/editor_apply_descendant/init.lua')

    expect.equality(
      child.lua_get([[
        (function()
          local autocmds = vim.api.nvim_get_autocmds({ group = 'plait.editor.yank_highlight' })
          return vim.tbl_map(function(autocmd)
            return { autocmd.group_name, autocmd.event, autocmd.pattern }
          end, autocmds)
        end)()
      ]]),
      { { 'plait.editor.yank_highlight', 'TextYankPost', '*' } }
    )
    child.lua([[
      vim.highlight.on_yank = function(opts) yank_opts = opts end
      vim.api.nvim_exec_autocmds('TextYankPost', { group = 'plait.editor.yank_highlight' })
    ]])
    expect.equality(child.lua_get([[yank_opts]]), { higroup = 'IncSearch', timeout = 150 })
  end)

  it('applies from a synchronously loaded init.lua descendant and exposes closed actions', function()
    restart_with_init('tests/fixtures/editor_apply_descendant/init.lua')

    expect.equality(child.lua_get([[apply_result.status]]), 'performed')
    child.lua([[
      focus_without_neighbor = M.actions.editor.focus('right')
      vim.cmd.vsplit()
      vim.cmd.wincmd('h')
      local left_window = vim.api.nvim_get_current_win()
      focus_right = M.actions.editor.focus('right')
      vim.api.nvim_set_current_win(left_window)
      clear_search = M.actions.editor.clear_search()

      local path = vim.fn.tempname()
      vim.api.nvim_buf_set_name(0, path)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'saved' })
      save = M.actions.editor.save()
      saved_contents = vim.fn.readfile(path)
      vim.fn.delete(path)

      vim.cmd.enew()
      vim.bo.buftype = 'nofile'
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'cannot save' })
      save_failure = M.actions.editor.save()
    ]])
    expect.equality(child.lua_get([[focus_without_neighbor]]), {
      status = 'performed',
      operation = 'editor.focus',
      details = { window = child.lua_get([[focus_without_neighbor.details.window]]) },
    })
    expect.equality(child.lua_get([[focus_right.operation]]), 'editor.focus')
    expect.equality(child.lua_get([[focus_right.status]]), 'performed')
    expect.equality(child.lua_get([[clear_search]]), {
      status = 'performed',
      operation = 'editor.clear_search',
      details = { window = child.lua_get([[clear_search.details.window]]) },
    })
    expect.equality(child.lua_get([[save]]), {
      status = 'performed',
      operation = 'editor.save',
      details = { buffer = child.lua_get([[save.details.buffer]]) },
    })
    expect.equality(child.lua_get([[saved_contents]]), { 'saved' })
    expect.equality(child.lua_get([[save_failure]]), {
      status = 'unavailable',
      operation = 'editor.save',
      reason = 'execution_failed',
      details = {
        diagnostic_codes = {},
        plan_id = child.lua_get([[apply_result.details.plan_id]]),
        effects = {
          completed = {
            'editor/native-options',
            'editor/actions',
            'editor/mappings',
            'editor/yank-highlight',
          },
          failed = {},
          skipped = {},
        },
      },
    })
  end)

  it('rejects invalid focus directions as sanitized misuse', function()
    restart_with_init('tests/fixtures/editor_apply_descendant/init.lua')
    child.lua([[focus_ok, focus_error = pcall(M.actions.editor.focus, 'diagonal\nsecret')]])

    expect.equality(child.lua_get([[focus_ok]]), false)
    expect.equality(
      child.lua_get([[focus_error:match('plait: editor focus direction must be left, down, up, or right$')]]),
      'plait: editor focus direction must be left, down, up, or right'
    )
  end)

  it('rejects every post-startup apply before managed effects', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      apply_ok, apply_error = pcall(function() config:apply() end)
      second_ok, second_error = pcall(function() config:apply() end)
    ]])

    expect.equality(child.lua_get([[apply_ok]]), false)
    expect.equality(
      child.lua_get([[apply_error:match('plait: apply is only available during synchronous init.lua startup$')]]),
      'plait: apply is only available during synchronous init.lua startup'
    )
    expect.equality(child.lua_get([[second_ok]]), false)
    expect.equality(
      child.lua_get([[second_error:match('plait: apply may only be called once$')]]),
      'plait: apply may only be called once'
    )
    expect.equality(child.lua_get([[vim.o.termguicolors]]), false)
  end)

  it('rejects apply from a plugin entrypoint while startup is still active', function()
    restart_with_init('tests/fixtures/editor_apply_plugin/init.lua')

    expect.equality(child.lua_get([[plugin_apply_ok]]), false)
    expect.equality(
      child.lua_get([[plugin_apply_error:match('plait: apply is only available during synchronous init.lua startup$')]]),
      'plait: apply is only available during synchronous init.lua startup'
    )
    expect.equality(child.lua_get([[vim.o.termguicolors]]), false)
  end)

  it('publishes a closed sanitized record when an editor effect fails', function()
    restart_with_init('tests/fixtures/editor_apply_failure/init.lua')

    expect.equality(child.lua_get([[apply_result]]), {
      status = 'unavailable',
      operation = 'apply',
      reason = 'execution_failed',
      details = {
        diagnostic_codes = { 'effect.failed' },
        plan_id = child.lua_get([[apply_result.details.plan_id]]),
        effects = {
          completed = { 'editor/native-options', 'editor/actions' },
          failed = { 'editor/mappings' },
          skipped = { 'editor/yank-highlight' },
        },
      },
    })
    expect.equality(child.lua_get([[M.inspect('effects', 'editor/mappings').error]]), {
      code = 'effect.failed',
      summary = 'Effect editor/mappings failed.',
      responsible_capability = 'editor',
      operation_id = 'apply',
      details = {
        operation_id = 'apply',
        stage = 4,
        effect = 'editor/mappings',
        capability = 'editor',
        provider = vim.NIL,
        completed = { 'editor/native-options', 'editor/actions' },
        failed = { 'editor/mappings' },
        skipped = { 'editor/yank-highlight' },
        message = 'Managed editor effect failed.',
      },
    })
    expect.equality(
      child.lua_get([[M.inspect('diagnostics', 'effect.failed')[1].details.message]]),
      'Managed editor effect failed.'
    )
    expect.equality(child.lua_get([[vim.inspect(M.inspect('diagnostics')):find('SECRET', 1, true) == nil]]), true)
    expect.equality(child.lua_get([[M.actions.editor.focus('right').status]]), 'performed')
    child.lua([[config:validate()]])
    expect.equality(child.lua_get([[M.inspect('diagnostics', 'effect.failed')[1].code]]), 'effect.failed')
  end)

  it('rejects synchronous autocmd callback re-entry from the owner init stack', function()
    restart_with_init('tests/fixtures/editor_apply_callback/init.lua')

    expect.equality(child.lua_get([[callback_apply_ok]]), false)
    expect.equality(
      child.lua_get(
        [[callback_apply_error:match('plait: apply is only available during synchronous init.lua startup$')]]
      ),
      'plait: apply is only available during synchronous init.lua startup'
    )
    expect.equality(child.lua_get([[vim.o.termguicolors]]), false)
  end)

  it('publishes the invalid snapshot from apply-time re-resolution', function()
    restart_with_init('tests/fixtures/editor_apply_invalid/init.lua')

    expect.equality(child.lua_get([[apply_result.status]]), 'unavailable')
    expect.equality(child.lua_get([[apply_result.operation]]), 'apply')
    expect.equality(child.lua_get([[apply_result.reason]]), 'invalid_plan')
    expect.equality(child.lua_get([[apply_result.details.diagnostic_codes]]), { 'config.invalid' })
    expect.equality(child.lua_get([[require('plait.state').snapshot.snapshot_state]]), 'invalid')
    expect.equality(child.lua_get([[M.inspect('effects')]]), {})
  end)
end)
