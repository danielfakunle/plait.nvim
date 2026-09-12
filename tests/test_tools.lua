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

describe('tooling capability actions', function()
  it('enforces not-configured, inactive, and invalid snapshot preconditions', function()
    child.lua([[not_configured = M.actions.tooling.check()]])
    expect.equality(child.lua_get([[not_configured]]), {
      status = 'unavailable',
      operation = 'tooling.check',
      reason = 'not_configured',
      details = {},
    })

    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      inactive = M.actions.tooling.ensure()
    ]])
    expect.equality(child.lua_get([[inactive]]), {
      status = 'unavailable',
      operation = 'tooling.ensure',
      reason = 'capability_inactive',
      details = { capability = 'tooling' },
    })
  end)

  it('checks effective tools and returns canonical state details', function()
    child.lua([[
      local config = M.config()
      config:select({ 'tooling' })
      config:validate()
      checked = M.actions.tooling.check()
    ]])

    expect.equality(child.lua_get([[checked.status]]), 'performed')
    expect.equality(child.lua_get([[checked.operation]]), 'tooling.check')
    expect.equality(child.lua_get([[checked.details.tools]]), {})
    expect.equality(child.lua_get([[checked.details.states]]), {})
  end)

  it('rejects unknown install identities as misuse', function()
    child.lua([[
      local config = M.config()
      config:select({ 'tooling' })
      config:validate()
      install_ok, install_error = pcall(M.actions.tooling.install, 'missing')
    ]])

    expect.equality(child.lua_get([[install_ok]]), false)
    expect.equality(child.lua_get([[install_error]]), 'plait: tooling.install requires an effective tool identity')
  end)

  it('applies the pinned Mason setup policy without refreshing a registry', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/tooling_apply/init.lua' })

    expect.equality(child.lua_get([[tooling_apply_result.status]]), 'performed')
    expect.equality(child.lua_get([[tooling_setup]]), {
      PATH = 'skip',
      registries = { 'github:mason-org/mason-registry@2026-09-07-abaft-pruner' },
      firewall = { auto_managed = false },
      ui = { border = 'single' },
    })
  end)

  it('starts Mason repair through the process-lifetime operation ledger', function()
    child.lua([[
      local data_path = vim.fn.tempname()
      vim.fn.mkdir(data_path, 'p')
      local original_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(kind)
        if kind == 'data' then return data_path end
        return original_stdpath(kind)
      end
      local demo = M.module({
        name = 'local.tools.demo', provides = { 'local.tools.demo' }, requires = { 'tooling' },
        contribute = { tooling = { tools = { demo = {
          executable = 'demo', version = '=1.2.3', ownership = 'mason', mason = 'demo'
        } } } },
      })
      local config = M.config()
      config:select({ 'tooling', demo })
      config:validate()
      local original_executable = vim.fn.executable
      vim.fn.executable = function(name)
        if name == 'curl' or name == 'wget' then return 1 end
        return original_executable(name)
      end
      vim.fn.filewritable = function() return 2 end
      package.loaded['mason-registry'] = {
        get_package = function(name)
          mason_requested_package = name
          return {
            install = function()
              return {
                once = function(_, event, callback)
                  mason_event = event
                  local root = vim.fn.stdpath('data') .. '/mason'
                  local executable = root .. '/packages/demo/bin/demo'
                  vim.fn.mkdir(vim.fs.dirname(executable), 'p')
                  vim.fn.mkdir(root .. '/bin', 'p')
                  vim.fn.writefile({ '#!/bin/sh', 'printf "1.2.3\\n"' }, executable)
                  vim.uv.fs_chmod(executable, 493)
                  vim.uv.fs_symlink(executable, root .. '/bin/demo')
                  callback()
                end,
              }
            end,
            is_installed = function() return true end,
          }
        end,
      }
      ensure_result = M.actions.tooling.ensure()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      operation = M.inspect('operations')[1]
    ]])

    expect.equality(child.lua_get([[ensure_result]]), {
      status = 'started',
      operation = 'tooling.ensure',
      operation_id = 'op-00000001',
      details = { targets = { 'demo' } },
    })
    expect.equality(child.lua_get([[mason_requested_package]]), 'demo')
    expect.equality(child.lua_get([[mason_event]]), 'closed')
    expect.equality(child.lua_get([[operation.state]]), 'succeeded')
    expect.equality(child.lua_get([[operation.result.details.targets]]), { 'demo' })
  end)
end)
