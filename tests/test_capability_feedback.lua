local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()
before_each(function() child.setup() end)
teardown(function() child.stop() end)

--- Activate capabilities through synchronous startup before observing public actions and mappings.
local function applied(policy)
  child.restart({
    '--clean',
    '--cmd',
    ('lua vim.g.feedback_policy = %q'):format(policy),
    '-u',
    'tests/fixtures/capability_feedback.lua',
  })
end

describe('capability feedback', function()
  for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
    it('presents genuine Lua blocking once under ' .. policy, function()
      child.lua(([[
        notifications = {}
        vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
        local config = M.config(); config:configure({ operation_feedback = %q }); config:validate()
        result = M.actions.language.hover()
      ]]):format(policy))
      expect.equality(child.lua_get([[result.reason]]), 'capability_inactive')
      expect.equality(child.lua_get([[#notifications]]), policy == 'silent' and 0 or 1)
    end)
    it('keeps expected completion fallback quiet except in debug under ' .. policy, function()
      applied(policy)
      child.lua(([[
        notifications = {}
        vim.notify = function(message) notifications[#notifications + 1] = message end

        package.loaded['blink.cmp'] = { is_active = function() return false end }
        result = M.actions.completion.next()
      ]]):format(policy))
      expect.equality(child.lua_get([[result.reason]]), 'completion_inactive')
      expect.equality(child.lua_get([[#notifications]]), (policy == 'debug' or policy == 'all') and 1 or 0)
    end)
  end
  it('reports empty diagnostic navigation through a mapping at info without an error', function()
    applied('info')
    child.lua([[
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      vim.fn.maparg(']d', 'n', false, true).callback()
      result = M.actions.language.next_diagnostic()
    ]])
    expect.equality(child.lua_get([[result.reason]]), 'no_diagnostics')
    expect.equality(child.lua_get([[notifications]]), { { 'Plait: No diagnostics to navigate', vim.log.levels.INFO } })
  end)

  it('reports save failure again after recovery, suppressing unchanged automatic failures', function()
    child.restart({
      '--clean',
      '--cmd',
      "lua vim.g.formatting_on_save = true; vim.g.apply_feedback = 'info'",
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    child.lua([[
      vim.bo.filetype = 'lua'
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      local _, callback = conform_setup.format_on_save(1)
      callback('failed'); callback('failed'); callback(nil); callback('failed')
    ]])
    expect.equality(child.lua_get([[#notifications]]), 2)
  end)
  for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
    it('keeps routine editor Lua and mapping success quiet under ' .. policy, function()
      applied(policy)
      child.lua(([[
        notifications = {}
        vim.notify = function(message) notifications[#notifications + 1] = message end
        result = M.actions.editor.clear_search()
        vim.fn.maparg('<F4>', 'n', false, true).callback()
      ]]):format(policy))
      expect.equality(child.lua_get([[result.status]]), 'performed')
      expect.equality(child.lua_get([[#notifications]]), (policy == 'debug' or policy == 'all') and 2 or 0)
    end)
    it('emits one language start/dispatch pair under ' .. policy, function()
      applied(policy)
      child.lua(([[
        notifications = {}
        vim.notify = function(message) notifications[#notifications + 1] = message end
        vim.lsp.get_clients = function() return { { supports_method = function() return true end } } end
        vim.lsp.buf.hover = function() dispatched = true end
        result = M.actions.language.hover()
        vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      ]]):format(policy))
      expect.equality(child.lua_get([[dispatched]]), true)
      expect.equality(child.lua_get([[#notifications]]), (policy == 'debug' or policy == 'all') and 2 or 0)
      if policy == 'debug' or policy == 'all' then
        expect.equality(child.lua_get([[notifications[2]:find('request dispatched', 1, true) ~= nil]]), true)
      end
    end)
  end
  it('reports changed save failures while keeping private provider messages hidden', function()
    child.restart({
      '--clean',
      '--cmd',
      "lua vim.g.formatting_on_save = true; vim.g.apply_feedback = 'info'",
      '-u',
      'tests/fixtures/formatting_apply/init.lua',
    })
    child.lua([[
      vim.bo.filetype = 'lua'
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      local _, callback = conform_setup.format_on_save(1)
      callback('token=SECRET'); callback('token=SECRET'); callback('different failure')
    ]])
    expect.equality(child.lua_get([[#notifications]]), 2)
    expect.equality(child.lua_get([[vim.inspect(notifications):find('SECRET', 1, true) == nil]]), true)
  end)
  it('returns focus mapping outcomes without losing the shared presentation context', function()
    applied('debug')
    child.lua([[
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      vim.cmd.vsplit()
      result = vim.fn.maparg('<C-h>', 'n', false, true).callback()
    ]])
    expect.equality(child.lua_get([[result.status]]), 'performed')
    expect.equality(child.lua_get([[#notifications]]), 1)
  end)
  for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
    it('presents one synchronous save result at debug under ' .. policy, function()
      child.restart({
        '--clean',
        '--cmd',
        ('lua vim.g.formatting_on_save = true; vim.g.apply_feedback = %q'):format(policy),
        '-u',
        'tests/fixtures/formatting_apply/init.lua',
      })
      child.lua([[
        vim.bo.filetype = 'lua'
        notifications = {}
        vim.notify = function(message) notifications[#notifications + 1] = message end
        local _, callback = conform_setup.format_on_save(1)
        callback(nil)
      ]])
      expect.equality(child.lua_get([[#notifications]]), (policy == 'debug' or policy == 'all') and 1 or 0)
    end)
  end
  it('reports automatic mapping warnings after repair and recurrence at info', function()
    applied('info')
    child.lua([[
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      local buffer = vim.api.nvim_get_current_buf()
      vim.lsp.get_clients = function() return { { id = 10, supports_method = function() return true end } } end
      local function attach() vim.api.nvim_exec_autocmds('LspAttach', { buffer = buffer, data = { client_id = 10 } }) end
      vim.keymap.set('n', 'gd', function() end, { buffer = buffer })
      attach(); attach()
      vim.keymap.del('n', 'gd', { buffer = buffer })
      attach()
      vim.keymap.set('n', 'gd', function() end, { buffer = buffer })
      attach()
    ]])
    expect.equality(child.lua_get([[#notifications]]), 2)
    expect.equality(child.lua_get([[notifications[1]:find('Repair:', 1, true) ~= nil]]), true)
  end)
  it('honors silent when another configuration point blocks application', function()
    child.restart({
      '--clean',
      '--cmd',
      "lua vim.g.feedback_policy = 'silent'; vim.g.feedback_invalid = true; notifications = {}; vim.notify = function(message) notifications[#notifications + 1] = message end",
      '-u',
      'tests/fixtures/capability_feedback.lua',
    })
    expect.equality(child.lua_get([[feedback_application.reason]]), 'invalid_plan')
    expect.equality(child.lua_get([[#notifications]]), 0)
  end)
end)
