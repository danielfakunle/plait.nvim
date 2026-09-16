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

  it('degrades TypeScript tools independently when their Node requirement is incompatible', function()
    child.lua([[
      local root = vim.fn.tempname()
      local project_bin = root .. '/node_modules/.bin'
      local path_bin = root .. '/path-bin'
      vim.fn.mkdir(project_bin, 'p')
      vim.fn.mkdir(path_bin, 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo "Version 7.0.2"' }, project_bin .. '/tsc')
      vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.66.0"' }, project_bin .. '/oxfmt')
      vim.fn.writefile({ '#!/bin/sh', 'echo "v18.0.0"' }, path_bin .. '/node')
      vim.fn.setfperm(project_bin .. '/tsc', 'rwxr-xr-x')
      vim.fn.setfperm(project_bin .. '/oxfmt', 'rwxr-xr-x')
      vim.fn.setfperm(path_bin .. '/node', 'rwxr-xr-x')
      vim.env.PATH = path_bin
      vim.cmd.cd(root)
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      result = config:validate()
      tsc = M.inspect('tools', 'tsc')
      oxfmt = M.inspect('tools', 'oxfmt')
    ]])

    expect.equality(child.lua_get([[tsc.state]]), 'satisfied')
    expect.equality(child.lua_get([[oxfmt.state]]), 'incompatible')
    expect.equality(child.lua_get([[oxfmt.version]]), '0.66.0')
    expect.equality(child.lua_get([[oxfmt.runtime.executable]]), 'node')
    expect.equality(child.lua_get([[oxfmt.runtime.version]]), '18.0.0')
    expect.equality(child.lua_get([[oxfmt.runtime.constraint]]), '>=22.12.0')
    expect.equality(
      child.lua_get([[vim.tbl_contains(vim.tbl_map(function(d) return d.code end,
      result.diagnostics), 'tool.incompatible')]]),
      true
    )
  end)

  it('probes a Node symlink by its Node name when its target is a multi-call executable', function()
    child.lua([[
      local root = vim.fn.tempname()
      local workspace = root .. '/node_modules/.bin'
      local runtime = root .. '/runtime'
      vim.fn.mkdir(workspace, 'p')
      vim.fn.mkdir(runtime, 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo "Version 7.0.2"' }, workspace .. '/tsc')
      vim.fn.setfperm(workspace .. '/tsc', 'rwxr-xr-x')
      vim.fn.writefile({ '#!/bin/sh', 'case "$0" in */node) echo v24.21.0 ;; *) echo "vp v0.3.1" ;; esac' }, runtime .. '/vp')
      vim.fn.setfperm(runtime .. '/vp', 'rwxr-xr-x')
      vim.uv.fs_symlink(runtime .. '/vp', runtime .. '/node')
      vim.fn.setenv('PATH', runtime)
      vim.cmd.cd(root)
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      config:validate()
      tsc = M.inspect('tools', 'tsc')
    ]])

    expect.equality(child.lua_get([[tsc.state]]), 'satisfied')
    expect.equality(child.lua_get([[tsc.version]]), '7.0.2')
    expect.equality(child.lua_get([[tsc.runtime]]), vim.NIL)
  end)

  it('keeps a present incompatible workspace oxfmt authoritative over Mason', function()
    child.lua([[
      local root = vim.fn.tempname()
      local workspace = root .. '/node_modules/.bin'
      local data = root .. '/data'
      local mason_package = data .. '/mason/packages/oxfmt'
      local runtime = root .. '/runtime'
      vim.fn.mkdir(workspace, 'p')
      vim.fn.mkdir(mason_package, 'p')
      vim.fn.mkdir(data .. '/mason/bin', 'p')
      vim.fn.mkdir(runtime, 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.65.0"' }, workspace .. '/oxfmt')
      vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.66.0"' }, mason_package .. '/oxfmt')
      vim.fn.writefile({ '#!/bin/sh', 'echo "v22.12.0"' }, runtime .. '/node')
      vim.fn.setfperm(workspace .. '/oxfmt', 'rwxr-xr-x')
      vim.fn.setfperm(mason_package .. '/oxfmt', 'rwxr-xr-x')
      vim.fn.setfperm(runtime .. '/node', 'rwxr-xr-x')
      vim.uv.fs_symlink(mason_package .. '/oxfmt', data .. '/mason/bin/oxfmt')
      local original_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(kind)
        if kind == 'data' then return data end
        return original_stdpath(kind)
      end
      vim.fn.setenv('PATH', runtime)
      vim.cmd.cd(root)
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      config:validate()
      oxfmt = M.inspect('tools', 'oxfmt')
    ]])

    expect.equality(child.lua_get([[oxfmt.state]]), 'incompatible')
    expect.equality(child.lua_get([[oxfmt.source]]), 'workspace')
    expect.equality(child.lua_get([[oxfmt.authoritative_candidate]]), 1)
    expect.equality(child.lua_get([[oxfmt.candidates[2].source]]), 'workspace')
    expect.equality(
      child.lua_get([[vim.tbl_contains(vim.tbl_map(function(item) return item.source end,
      oxfmt.candidates), 'mason')]]),
      true
    )
  end)

  it('falls through an absent workspace oxfmt candidate to Mason', function()
    child.lua([[
      local root = vim.fn.tempname()
      local data = root .. '/data'
      local mason_package = data .. '/mason/packages/oxfmt'
      local runtime = root .. '/runtime'
      vim.fn.mkdir(root .. '/node_modules/.bin', 'p')
      vim.fn.mkdir(mason_package, 'p')
      vim.fn.mkdir(data .. '/mason/bin', 'p')
      vim.fn.mkdir(runtime, 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.66.0"' }, mason_package .. '/oxfmt')
      vim.fn.writefile({ '#!/bin/sh', 'echo "v22.12.0"' }, runtime .. '/node')
      vim.fn.setfperm(mason_package .. '/oxfmt', 'rwxr-xr-x')
      vim.fn.setfperm(runtime .. '/node', 'rwxr-xr-x')
      vim.uv.fs_symlink(mason_package .. '/oxfmt', data .. '/mason/bin/oxfmt')
      local original_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(kind)
        if kind == 'data' then return data end
        return original_stdpath(kind)
      end
      vim.fn.setenv('PATH', runtime)
      vim.cmd.cd(root)
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      config:validate()
      oxfmt = M.inspect('tools', 'oxfmt')
    ]])

    expect.equality(child.lua_get([[oxfmt.state]]), 'satisfied')
    expect.equality(child.lua_get([[oxfmt.source]]), 'mason')
    expect.equality(child.lua_get([[oxfmt.candidates[1].state]]), 'absent')
  end)

  it('classifies absent and unprobeable Node prerequisites', function()
    child.lua([[
      local root = vim.fn.tempname()
      local workspace = root .. '/node_modules/.bin'
      local runtime = root .. '/runtime'
      vim.fn.mkdir(workspace, 'p')
      vim.fn.mkdir(runtime, 'p')
      vim.fn.writefile({ '#!/bin/sh', 'echo "oxfmt 0.66.0"' }, workspace .. '/oxfmt')
      vim.fn.setfperm(workspace .. '/oxfmt', 'rwxr-xr-x')
      vim.cmd.cd(root)
      local resolution = {
        effective_contributions = { 'tooling.tools.oxfmt' },
        contribution_values = {},
        modules = { {
          contributions = { 'tooling.tools.oxfmt' },
          selection_sources = { { file = 'test', line = 1, path = 'select[1]' } },
        } },
      }
      vim.fn.setenv('PATH', runtime)
      node_absent = require('plait.tools').resolve(resolution)[1].state
      vim.fn.writefile({ 'not executable' }, runtime .. '/node')
      node_unprobeable = require('plait.tools').resolve(resolution)[1].state
    ]])

    expect.equality(child.lua_get([[node_absent]]), 'absent')
    expect.equality(child.lua_get([[node_unprobeable]]), 'unprobeable')
  end)
end)

describe('tooling capability actions', function()
  it('refreshes repaired tools exactly once per explicit check and preserves feedback policy', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/tooling_freshness/init.lua' })
    child.lua([[
      vim.fn.writefile({ '#!/bin/sh', 'echo 1.2.3' }, tool_path)
      stale = M.inspect('tools', 'demo')
      stale_diagnostics = M.inspect('diagnostics', 'tool.incompatible')
      checked = M.actions.tooling.check()
    ]])
    expect.equality(child.lua_get([[stale.state]]), 'incompatible')
    expect.equality(child.lua_get([[#stale_diagnostics]]), 1)
    expect.equality(child.lua_get([[tool_probes]]), 2)
    expect.equality(child.lua_get([[checked]]), {
      status = 'performed',
      operation = 'tooling.check',
      details = { tools = { 'demo' }, states = { demo = 'satisfied' } },
    })
    expect.equality(child.lua_get([[M.inspect('tools', 'demo').version]]), '1.2.3')
    expect.equality(
      child.lua_get([[vim.tbl_filter(function(item) return item.code == 'tool.incompatible' end,
        M.inspect('diagnostics'))]]),
      {}
    )
    child.lua([[
      output = {}
      print = function(message) output[#output + 1] = message end
      vim.cmd('Plait tooling check')
    ]])
    expect.equality(child.lua_get([[tool_probes]]), 3)
    expect.equality(child.lua_get([[#output]]), 0)
    for _, policy in ipairs({ 'all', 'silent' }) do
      child.restart({
        '--clean',
        '--cmd',
        'lua feedback_policy = "' .. policy .. '"',
        '-u',
        'tests/fixtures/tooling_freshness/init.lua',
      })
      child.lua([[
        output = {}
        print = function(message) output[#output + 1] = message end
        vim.cmd('Plait tooling check')
      ]])
      expect.equality(child.lua_get([[tool_probes]]), 2)
      expect.equality(child.lua_get([[#output]]), policy == 'all' and 1 or 0)
    end
  end)

  it('reuses one startup observation with and without startup checking or prior validation', function()
    for _, startup_check in ipairs({ true, false }) do
      for _, skip_validation in ipairs({ false, true }) do
        child.restart({
          '--clean',
          '--cmd',
          'lua check_on_startup = ' .. tostring(startup_check) .. '; skip_validation = ' .. tostring(skip_validation),
          '-u',
          'tests/fixtures/tooling_freshness/init.lua',
        })
        expect.equality(child.lua_get([[applied.status]]), 'performed')
        expect.equality(child.lua_get([[tool_probes]]), 1)
        expect.equality(child.lua_get([[M.inspect('tools', 'demo').state]]), 'incompatible')
        if not skip_validation then expect.equality(child.lua_get([[startup_probes]]), 1) end
        expect.equality(
          child.lua_get([[vim.tbl_contains(applied.details.effects.completed, 'tooling/startup-check')]]),
          startup_check
        )
      end
    end
  end)

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

  it('closes an operation when an asynchronous Mason callback throws', function()
    child.lua([[
      local state = require('plait.state')
      local data_path = vim.fn.tempname()
      vim.fn.mkdir(data_path, 'p')
      local original_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(kind)
        if kind == 'data' then return data_path end
        return original_stdpath(kind)
      end
      state.snapshot = {
        snapshot_state = 'validated', diagnostics = {}, operations = {}, modules = {}, effects = {}, packages = {},
        capabilities = { { identity = 'tooling' } },
        tools = { { identity = 'demo', state = 'absent' } },
      }
      state.tool_requirements = { demo = { mason = 'demo' } }
      vim.fn.executable = function(name) return (name == 'curl' or name == 'wget') and 1 or 0 end
      vim.fn.filewritable = function() return 2 end
      package.loaded['mason-registry'] = {
        get_package = function()
          return {
            install = function()
              return { once = function(_, _, callback) vim.schedule(callback) end }
            end,
            is_installed = function()
              error('SECRET_TOKEN=tool-credential\nstack traceback:\n\tenvironment dump')
            end,
          }
        end,
      }
      notifications = {}
      vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
      started = M.actions.tooling.ensure()
      vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)
      operation = M.inspect('operations')[1]
      diagnostic = M.inspect('diagnostics', 'operation.failed')[1]
    ]])

    expect.equality(child.lua_get([[started.status]]), 'started')
    expect.equality(child.lua_get([[operation.state]]), 'failed')
    expect.equality(child.lua_get([[operation.error.message]]), 'Mason tool mutation failed.')
    expect.equality(child.lua_get([[diagnostic.details.message]]), 'Mason tool mutation failed.')
    expect.equality(child.lua_get([[#M.inspect('diagnostics', 'operation.failed')]]), 1)
    expect.equality(child.lua_get([[#notifications]]), 1)
    expect.equality(child.lua_get('notifications[1][2]'), vim.log.levels.ERROR)
    expect.equality(
      child.lua_get([[vim.inspect({ operation, diagnostic }):find('SECRET_TOKEN', 1, true) == nil]]),
      true
    )
  end)
end)
