local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

describe('Plait command', function()
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
      config:apply()
    ]])

    local output = child.cmd_capture('Plait validate')
    expect.equality(output:match('^valid [0-9a-f]+$') and #output, 70)
    expect.equality(child.lua_get([[M.inspect('modules', 'editor').identity]]), 'editor')
  end)

  it('renders all inspection sections in canonical order', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
    ]])

    local output = child.cmd_capture('Plait inspect')
    expect.equality(output:match('^modules: '), 'modules: ')
    expect.equality(
      vim.tbl_map(function(line) return line:match('^(%a+):') end, vim.split(output, '\n')),
      { 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }
    )
    expect.equality(output:find('packages: []', 1, true) ~= nil, true)
    expect.equality(output:find('operations: []', 1, true) ~= nil, true)
  end)
end)
