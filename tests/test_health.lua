local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

local required_facts = {
  'Plait version',
  'Neovim qualification',
  'Platform qualification',
  'Native package path',
  'Git',
  'Provider nvim-lspconfig',
  'Provider blink.cmp',
  'Provider conform.nvim',
  'Provider mason.nvim',
  'Mason registry',
  'Tool lua-language-server',
  'Tool stylua',
  'Tool tsc',
  'Tool oxfmt',
  'Clipboard path',
  'Blink fuzzy path',
}

local function health_output()
  child.cmd('checkhealth plait')
  return child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
end

describe('Plait health', function()
  it('reports discovery before configuration without creating Plait state', function()
    local output = health_output()

    expect.equality(output:find('Configuration: not configured', 1, true) ~= nil, true)
    for _, fact in ipairs(required_facts) do
      expect.equality(output:find(fact, 1, true) ~= nil, true)
    end

    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      result = config:validate()
    ]])
    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  end)

  it('does not replace or mutate the latest completed snapshot', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      before_health = {
        modules = M.inspect('modules'),
        diagnostics = M.inspect('diagnostics'),
        operations = M.inspect('operations'),
      }
    ]])

    local output = health_output()
    expect.equality(output:find('configured', 1, true) ~= nil, true)
    expect.equality(child.lua_get([[vim.deep_equal(before_health.modules, M.inspect('modules'))]]), true)
    expect.equality(child.lua_get([[vim.deep_equal(before_health.diagnostics, M.inspect('diagnostics'))]]), true)
    expect.equality(child.lua_get([[vim.deep_equal(before_health.operations, M.inspect('operations'))]]), true)
  end)

  it('reports collecting state without a snapshot as not configured', function()
    child.lua([[M.config()]])

    expect.equality(health_output():find('Configuration: not configured', 1, true) ~= nil, true)
  end)

  it('scopes compatibility tools and providers to the effective plan', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua' })
      config:validate()
    ]])

    local output = health_output()
    expect.equality(output:find('Tool lua-language-server', 1, true) ~= nil, true)
    expect.equality(output:find('Tool stylua', 1, true) ~= nil, true)
    expect.equality(output:find('Tool tsc', 1, true) == nil, true)
    expect.equality(output:find('Tool oxfmt', 1, true) == nil, true)
    expect.equality(output:find('Provider blink.cmp', 1, true) == nil, true)
    expect.equality(output:find('Blink fuzzy path', 1, true) == nil, true)
  end)

  it('does not warn about an absent registry when effective Mason tools are satisfied', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua' })
      config:validate()
      local state = require('plait.state')
      for _, tool in ipairs(state.snapshot.tools) do
        tool.state = 'satisfied'
        tool.path = '/qualified/' .. tool.identity
        tool.source = 'PATH'
        tool.version = tool.identity == 'stylua' and '2.5.2' or '3.19.1'
      end
      local fs_stat = vim.uv.fs_stat
      vim.uv.fs_stat = function(path)
        if path:find('/mason/registries/', 1, true) then return nil end
        return fs_stat(path)
      end
    ]])

    local output = health_output()
    expect.equality(
      output:find('Mason registry: not installed; not required by the satisfied effective tools', 1, true) ~= nil,
      true
    )
  end)

  it('reports an incompatible authoritative tool candidate', function()
    child.lua([[
      tool_directory = vim.fn.tempname()
      vim.fn.mkdir(tool_directory, 'p')
      local executable = tool_directory .. '/tsc'
      vim.fn.writefile({ '#!/bin/sh', 'echo Version 6.0.0' }, executable)
      vim.fn.setfperm(executable, 'rwxr-xr-x')
      vim.env.PATH = tool_directory
    ]])

    local output = health_output()
    expect.equality(output:find('Tool tsc: incompatible version 6.0.0', 1, true) ~= nil, true)
    child.lua([[vim.fn.delete(tool_directory, 'rf')]])
  end)
end)
