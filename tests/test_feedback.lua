local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

--- Configure an unmet Mason tool against deterministic external boundaries.
local function unmet_tool(policy, count)
  child.lua(([[
    notifications = {}
    vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    local stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(kind) return kind == 'data' and data or stdpath(kind) end
    local tools = {}
    for index = 1, %d do
      tools[%d == 1 and 'demo' or 'demo' .. index] = { executable = 'plait-feedback-demo', version = '=1.2.3', ownership = 'mason', mason = 'demo' }
    end
    local demo = M.module({ name = 'local.feedback.demo', provides = { 'local.feedback.demo' },
      requires = { 'tooling' }, contribute = { tooling = { tools = tools } } })
    local config = M.config()
    config:select({ 'tooling', demo })
    config:configure({ operation_feedback = %q })
    config:validate()
    package.loaded['mason-registry'] = { get_package = function()
      return { install = function()
        mutations = (mutations or 0) + 1
        return { once = function(_, _, callback) tool_done = callback end }
      end, is_installed = function() return tool_succeeded == true end }
    end }
  ]]):format(count or 1, count or 1, policy))
end

describe('maintenance feedback', function()
  for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
    it('keeps explicit tool findings visible under ' .. policy, function()
      unmet_tool(policy)
      local output = child.cmd_capture('Plait tooling check')
      expect.equality(output:find('demo: absent', 1, true) ~= nil, true)
      expect.equality(output:find('Install through the declared ownership path', 1, true) ~= nil, true)
      expect.equality(child.lua_get([[#notifications]]), 0)
    end)

    it('applies ' .. policy .. ' to direct Lua asynchronous failures', function()
      unmet_tool(policy)
      child.lua(
        [[started = M.actions.tooling.ensure(); vim.wait(1000, function() return tool_done ~= nil end); tool_done()]]
      )
      expect.equality(child.lua_get([[started.status]]), 'started')
      expect.equality(
        child.lua_get([[#notifications]]),
        policy == 'silent' and 0 or ((policy == 'debug' or policy == 'all') and 2 or 1)
      )
      expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'failed')
      if policy == 'debug' or policy == 'all' then
        expect.equality(child.lua_get([[notifications[2][1]:find('op-00000001', 1, true) ~= nil]]), true)
        expect.equality(child.lua_get([[notifications[2][1]:find('tooling.ensure', 1, true) ~= nil]]), true)
      end
    end)
  end

  it('reports a declined package synchronization as cancellation without a ledger mutation', function()
    child.lua([[
      notifications = {}
      vim.notify = function(message) notifications[#notifications + 1] = message end
      vim.fn.globpath = function() return {} end
      vim.fn.has = function() return 1 end
      vim.fn.confirm = function() return 2 end
      local config = M.config(); config:select({ 'language' }); config:validate()
    ]])
    expect.equality(
      child.cmd_capture('Plait packages sync'),
      'Plait: Package synchronization cancelled; no packages changed.'
    )
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
    expect.equality(child.lua_get([[#notifications]]), 0)
    child.lua([[cancelled = M.actions.packages.sync()]])
    expect.equality(child.lua_get([[cancelled.reason]]), 'consent_denied')
    expect.equality(child.lua_get([[#notifications]]), 0)
  end)

  it('confirms satisfied tool maintenance once without claiming mutation and keeps Lua quiet', function()
    unmet_tool('info')
    child.lua([[
      local root = vim.fn.stdpath('data') .. '/mason'
      local path = root .. '/packages/demo/bin/plait-feedback-demo'
      vim.fn.mkdir(vim.fs.dirname(path), 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo 1.2.3' }, path)
      vim.fn.setfperm(path, 'rwxr-xr-x')
      vim.fn.mkdir(root .. '/bin', 'p')
      vim.uv.fs_symlink(path, root .. '/bin/plait-feedback-demo')
      M.actions.tooling.check()
    ]])
    for _, action in ipairs({ 'install demo', 'ensure', 'update demo' }) do
      expect.equality(child.cmd_capture('Plait tooling ' .. action), 'Plait: demo is already satisfied.')
    end
    child.lua([[result = M.actions.tooling.ensure()]])
    expect.equality(child.lua_get([[result.status]]), 'performed')
    expect.equality(child.lua_get([[#notifications]]), 0)
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  end)

  for _, invocation in ipairs({ 'command', 'lua' }) do
    it('reports actual tool mutation for ' .. invocation .. ' and retains the successful result', function()
      unmet_tool('info')
      if invocation == 'command' then
        child.cmd('Plait tooling install demo')
      else
        child.lua([[started = M.actions.tooling.install('demo')]])
      end
      child.lua([[
        vim.wait(1000, function() return tool_done ~= nil end)
        local root = vim.fn.stdpath('data') .. '/mason'
        local path = root .. '/packages/demo/bin/plait-feedback-demo'
        vim.fn.mkdir(vim.fs.dirname(path), 'p')
        vim.fn.writefile({ '#!/bin/sh', 'echo 1.2.3' }, path)
        vim.fn.setfperm(path, 'rwxr-xr-x')
        vim.fn.mkdir(root .. '/bin', 'p')
        vim.uv.fs_symlink(path, root .. '/bin/plait-feedback-demo')
        tool_succeeded = true
        tool_done()
      ]])
      expect.equality(child.lua_get([[mutations]]), 1)
      expect.equality(child.lua_get([[M.inspect('operations')[1].result.details.states.demo]]), 'satisfied')
      expect.equality(child.lua_get([[#notifications]]), invocation == 'command' and 2 or 0)
      if invocation == 'command' then
        expect.equality(child.lua_get([=[notifications[2][1]]=]), 'Plait: demo installed.')
      end
    end)
  end

  for _, entry in ipairs({ 'command', 'lua' }) do
    it('uses the selected entry-point policy for a custom ' .. entry .. ' mapping', function()
      unmet_tool('info')
      if entry == 'command' then
        child.cmd('nnoremap <F4> :Plait tooling ensure<CR>')
      else
        child.lua([[vim.keymap.set('n', '<F4>', function() mapped = M.actions.tooling.ensure() end)]])
      end
      child.type_keys('<F4>')
      child.lua([[vim.wait(1000, function() return tool_done ~= nil end)]])
      expect.equality(child.lua_get([[#notifications]]), entry == 'command' and 1 or 0)
      child.lua([[tool_done()]])
      expect.equality(child.lua_get([[#notifications]]), entry == 'command' and 2 or 1)
      expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'failed')
    end)
  end

  it('summarizes long maintenance target lists with names, counts, and an inspection pointer', function()
    unmet_tool('info', 5)
    child.cmd('Plait tooling ensure')
    expect.equality(child.lua_get([[#notifications]]), 1)
    local message = child.lua_get([=[notifications[1][1]]=])
    expect.equality(message:find('5 tools (demo1, demo2, demo3', 1, true) ~= nil, true)
    expect.equality(message:find(':Plait inspect tools', 1, true) ~= nil, true)
    expect.equality(message:find('op-', 1, true), nil)
  end)

  it('keeps explicit inspection, validation, and rendering visible under every policy', function()
    for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
      child.setup()
      unmet_tool(policy)
      child.lua([[result = M.actions.tooling.install('demo')]])
      expect.equality(child.cmd_capture('Plait validate'):find('valid ', 1, true) ~= nil, true)
      expect.equality(child.cmd_capture('Plait inspect tools --json'):find('"identity":"demo"', 1, true) ~= nil, true)
      expect.equality(child.lua_get([[M.render(result):find('tooling.install', 1, true) ~= nil]]), true)
    end
  end)

  it('keeps blocked direct Lua actions quiet only under silent', function()
    for _, policy in ipairs({ 'silent', 'errors', 'info', 'debug', 'all' }) do
      child.setup()
      child.lua(([[
        notifications = {}
        vim.notify = function(message) notifications[#notifications + 1] = message end
        local config = M.config(); config:select({ 'editor' })
        config:configure({ operation_feedback = %q }); config:validate()
        result = M.actions.tooling.ensure()
      ]]):format(policy))
      expect.equality(child.lua_get([[result.reason]]), 'capability_inactive')
      expect.equality(child.lua_get([[#notifications]]), policy == 'silent' and 0 or 1)
      expect.equality(child.lua_get([[M.render(result):find('Repair:', 1, true) ~= nil]]), true)
    end
  end)

  for _, policy in ipairs({ 'info', 'debug', 'all' }) do
    it('announces one command start and one asynchronous failure at ' .. policy, function()
      unmet_tool(policy)
      child.cmd('Plait tooling ensure')
      expect.equality(child.lua_get([[#notifications]]), 1)
      expect.equality(child.lua_get([[notifications[1][1]:find('Plait: Preparing demo.', 1, true) == 1]]), true)
      child.lua([[tool_done(); tool_done()]])
      expect.equality(child.lua_get([[#notifications]]), 2)
      expect.equality(child.lua_get([[notifications[2][1]:find('Repair:', 1, true) ~= nil]]), true)
      expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'failed')
    end)
  end
end)
