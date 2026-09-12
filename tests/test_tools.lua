local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

describe('external tool resolution', function()
  it('normalizes valid declarations and rejects invalid ownership fields', function()
    child.lua([[
      local good = M.module({ name = 'local.tools.good', provides = { 'local.tools.good' }, requires = { 'tooling' }, contribute = { tooling = { tools = { demo = { executable = 'demo', version = ' >=1.0.0, <2.0.0 ', ownership = 'project', workspace_paths = { './bin//demo' } } } } } })
      local bad = M.module({ name = 'local.tools.bad', provides = { 'local.tools.bad' }, requires = { 'tooling' }, contribute = { tooling = { tools = { bad = { executable = 'bin/bad', version = '^1.0', ownership = 'mason', mason = 'bad', workspace_paths = { 'bin/bad' } } } } } })
      local first = M.config()
      first:select({ 'tooling', good })
      valid = first:validate()
    ]])
    expect.equality(child.lua_get([[valid.status]]), 'valid')
    expect.equality(child.lua_get([[valid.plan.tools[1].candidates[1].path:match('bin/demo$')]]), 'bin/demo')

    child.restart({ '--clean', '-u', 'scripts/minimal_init.lua' })
    child.lua(
      [[M = require('plait'); local bad = M.module({ name = 'local.tools.bad', provides = { 'local.tools.bad' }, requires = { 'tooling' }, contribute = { tooling = { tools = { bad = { executable = 'bin/bad', version = '^1.0', ownership = 'mason', mason = 'bad', workspace_paths = { 'bin/bad' } } } } } }); local config = M.config(); config:select({ 'tooling', bad }); invalid = config:validate()]]
    )
    expect.equality(child.lua_get([[invalid.status]]), 'invalid')
    expect.equality(child.lua_get([[invalid.diagnostics[1].code]]), 'config.invalid')
  end)

  it('uses the active buffer workspace and stops at the first present candidate', function()
    child.lua([[
      local root = vim.fn.tempname()
      local nested = root .. '/src/deep'
      local executable = root .. '/node_modules/.bin/tsc'
      vim.fn.mkdir(nested, 'p')
      vim.fn.mkdir(root .. '/node_modules/.bin', 'p')
      vim.fn.writefile({ '#!/bin/sh', 'printf "Version 6.0.0\\n"' }, executable)
      vim.uv.fs_chmod(executable, 493)
      vim.cmd.edit(vim.fn.fnameescape(nested .. '/main.ts'))
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      result = config:validate()
      tool = M.inspect('tools', 'tsc')
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[tool.state]]), 'incompatible')
    expect.equality(child.lua_get([[tool.source]]), 'workspace')
    expect.equality(child.lua_get([[tool.version]]), '6.0.0')
    expect.equality(
      child.lua_get(
        [[vim.tbl_contains(vim.tbl_map(function(d) return d.code end, result.diagnostics), 'tool.incompatible')]]
      ),
      true
    )
  end)

  it('does not fall through when the first present candidate is unprobeable', function()
    child.lua([[
      local root = vim.fn.tempname()
      local executable = root .. '/node_modules/.bin/tsc'
      vim.fn.mkdir(root .. '/node_modules/.bin', 'p')
      vim.fn.writefile({ 'not executable' }, executable)
      vim.cmd.cd(root)
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      result = config:validate()
      tool = M.inspect('tools', 'tsc')
    ]])

    expect.equality(child.lua_get([[tool.state]]), 'unprobeable')
    expect.equality(child.lua_get([[tool.authoritative_candidate]]), 1)
    expect.equality(child.lua_get([[result.diagnostics[#result.diagnostics].details.reason]]), 'not_executable')
  end)
end)
