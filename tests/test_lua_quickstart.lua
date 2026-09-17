local MiniTest = require('mini.test')
local helpers = dofile('tests/helpers.lua')

local child = helpers.new_clean_neovim()
local expect = MiniTest.expect

local function assert_schema(expression, fields)
  expect.equality(
    child.lua_get(([[vim.iter(%s):all(function(record)
      local keys = vim.tbl_keys(record)
      table.sort(keys)
      return vim.deep_equal(keys, %s)
    end)]]):format(expression, vim.inspect(fields))),
    true
  )
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = child.setup,
    post_once = child.stop,
  },
})

T['canonical Lua quickstart'] = MiniTest.new_set()

T['canonical Lua quickstart']['locks the successful author journey'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/lua_quickstart/init.lua' })

  expect.equality(child.lua_get([[vim.tbl_count(lua_startup_probe_counts_at_apply)]]), 2)
  expect.equality(
    child.lua_get([[vim.iter(lua_startup_probe_counts_at_apply):all(function(_, count) return count == 1 end)]]),
    true
  )
  expect.equality(child.lua_get([[lua_quickstart.validation.status]]), 'valid')
  expect.equality(child.lua_get([[lua_quickstart.provider_package_calls]]), 1)
  expect.equality(child.lua_get([[lua_quickstart.result.status]]), 'performed')
  expect.equality(
    child.lua_get([[lua_quickstart.result.details.plan_id]]),
    child.lua_get([[lua_quickstart.validation.plan_id]])
  )
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('modules'))]]), {
    'editor',
    'language',
    'completion',
    'formatting',
    'tooling',
    'lang.lua',
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, M.inspect('capabilities'))]]), {
    'completion',
    'editor',
    'formatting',
    'lang.lua',
    'language',
    'tooling',
  })
  expect.equality(child.lua_get([[lua_quickstart.contributions]]), {
    'formatting.by_filetype.lua',
    'formatting.formatters.stylua',
    'language.servers.lua_ls',
    'tooling.tools.lua-language-server',
    'tooling.tools.stylua',
  })
  expect.equality(child.lua_get([[lua_quickstart.package_facts]]), {
    { 'blink.cmp', 'satisfied' },
    { 'conform.nvim', 'satisfied' },
    { 'mason.nvim', 'satisfied' },
    { 'nvim-lspconfig', 'satisfied' },
  })
  expect.equality(child.lua_get([[lua_quickstart.tool_facts]]), {
    { 'lua-language-server', '3.19.1', 'satisfied' },
    { 'stylua', '2.5.2', 'satisfied' },
  })
  expect.equality(child.lua_get([[lua_quickstart.effect_identities]]), {
    'completion/package/blink.cmp',
    'formatting/package/conform.nvim',
    'language/package/nvim-lspconfig',
    'tooling/package/mason.nvim',
    'completion/provider-setup',
    'editor/native-options',
    'language/native-diagnostics',
    'tooling/provider-setup',
    'tooling/tool-resolution',
    'formatting/provider-setup',
    'language/server-definition/lua_ls',
    'completion/actions-and-mappings',
    'editor/actions',
    'editor/mappings',
    'editor/yank-highlight',
    'formatting/actions-and-mapping',
    'language/actions-and-mappings',
    'tooling/actions',
    'tooling/startup-check',
    'language/service/lua_ls',
  })
  expect.equality(child.lua_get([[lua_quickstart.lua_filetypes]]), { 'lua' })
  expect.equality(child.lua_get([[lua_quickstart.lua_formatter_chain]]), { 'stylua' })
  expect.equality(
    child.lua_get([[lua_quickstart.lua_ls_settings]]),
    child.lua_get([[lua_quickstart.expected_lua_ls_settings]])
  )
  expect.equality(
    child.lua_get([[lua_quickstart.lua_ls_capabilities]]),
    child.lua_get([[lua_quickstart.expected_completion_capabilities]])
  )
  expect.equality(child.lua_get([[lua_quickstart.validation.diagnostics]]), {})
  expect.equality(child.lua_get([[M.inspect('diagnostics')]]), {})
  expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  expect.equality(
    child.lua_get([[vim.iter(M.inspect('effects')):all(function(item) return item.state == 'completed' end)]]),
    true
  )
  expect.equality(child.lua_get([[lua_quickstart.validation_detached]]), true)
  expect.equality(child.lua_get([[lua_quickstart.inspection_detached]]), true)
  expect.equality(
    child.lua_get([[lua_quickstart.nested_semantics_hash]]),
    '92f5b03f2ed31ecbba391ed7433a7228169420438ac3831bc278dc339ade3949'
  )
  expect.equality(child.lua_get([[lua_quickstart.lifecycle_errors]]), {
    'plait: apply may only be called once',
    'plait: configuration collector is sealed',
    'plait: configuration collector is sealed',
    'plait: configuration collector is sealed',
    'plait: a configuration collector already exists',
  })

  local schemas = {
    modules = { 'contributions', 'identity', 'ordering_edges', 'provides', 'requires', 'selection_sources', 'state' },
    capabilities = {
      'actions',
      'activator',
      'cardinality',
      'configuration',
      'contribution_history',
      'contributions',
      'degradation_details',
      'degradation_reasons',
      'dependents',
      'identity',
      'overrides',
      'providers',
      'responsible_integration',
      'state',
    },
    effects = { 'dependencies', 'error', 'identity', 'provider', 'responsible_capability', 'sources', 'stage', 'state' },
    packages = {
      'active_commit',
      'active_source',
      'identity',
      'inconsistency',
      'repair',
      'required_commit',
      'responsible_capabilities',
      'source',
      'sources',
      'state',
    },
    tools = {
      'affected_operations',
      'authoritative_candidate',
      'candidates',
      'constraint',
      'executable',
      'identity',
      'ownership',
      'path',
      'repair',
      'runtime',
      'source',
      'sources',
      'state',
      'version',
    },
  }
  for section, fields in pairs(schemas) do
    if section == 'capabilities' then
      assert_schema(
        [[vim.tbl_filter(function(item) return item.identity ~= 'formatting' end, M.inspect('capabilities'))]],
        fields
      )
      local formatting_fields = vim.list_extend(vim.deepcopy(fields), { 'formatter_chains', 'lsp_fallback' })
      table.sort(formatting_fields)
      assert_schema([[{ M.inspect('capabilities', 'formatting') }]], formatting_fields)
    else
      assert_schema(([[M.inspect(%q)]]):format(section), fields)
    end
  end
  assert_schema(
    [[vim.iter(M.inspect('modules')):map(function(item) return item.selection_sources end):flatten():totable()]],
    {
      'file',
      'line',
      'path',
    }
  )
  assert_schema([[vim.iter(M.inspect('capabilities')):map(function(item) return item.configuration end):totable()]], {
    'providers',
    'sources',
    'values',
  })
  assert_schema([[vim.iter(M.inspect('tools')):map(function(item) return item.candidates end):flatten():totable()]], {
    'path',
    'real_path',
    'reason',
    'source',
    'state',
  })

  for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }) do
    local rendered = child.cmd_capture('Plait inspect ' .. section .. ' --json')
    local prefix = section .. ': '
    expect.equality(rendered:sub(1, #prefix), prefix)
    expect.equality(vim.json.decode(rendered:sub(#prefix + 1)), child.lua_get(([[M.inspect(%q)]]):format(section)))
    expect.equality(child.cmd_capture('Plait inspect ' .. section .. ' --json'), rendered)
    if section == 'effects' then
      expect.equality(rendered:find('"error":null', 1, true) ~= nil, true)
      expect.equality(rendered:find('"provider":null', 1, true) ~= nil, true)
    end
  end
  for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools' }) do
    local identity = child.lua_get(([[M.inspect(%q)[1].identity]]):format(section))
    local rendered = child.cmd_capture(('Plait inspect %s %s --json'):format(section, identity))
    local prefix = section .. ': '
    expect.equality(
      vim.json.decode(rendered:sub(#prefix + 1)),
      child.lua_get(([[M.inspect(%q, %q)]]):format(section, identity))
    )
    expect.equality(child.cmd_capture(('Plait inspect %s %s --json'):format(section, identity)), rendered)
  end
end

T['canonical Lua quickstart']['does not mutate absent packages in non-interactive startup'] = function()
  child.restart({
    '--clean',
    '--cmd',
    [[lua vim.g.lua_quickstart_mode = 'absent']],
    '-u',
    'tests/fixtures/lua_quickstart/init.lua',
  })

  expect.equality(child.lua_get([[lua_quickstart.validation.status]]), 'valid')
  expect.equality(child.lua_get([[lua_quickstart.provider_package_calls]]), 0)
  expect.equality(child.lua_get([[lua_quickstart.result]]), {
    status = 'unavailable',
    operation = 'apply',
    reason = 'package_absent',
    details = {
      packages = { 'blink.cmp', 'conform.nvim', 'mason.nvim', 'nvim-lspconfig' },
      states = {
        ['blink.cmp'] = 'absent',
        ['conform.nvim'] = 'absent',
        ['mason.nvim'] = 'absent',
        ['nvim-lspconfig'] = 'absent',
      },
    },
  })
  expect.equality(
    child.lua_get([[vim.iter(lua_quickstart.effects):all(function(item) return item.state == 'pending' end)]]),
    true
  )
  expect.equality(
    child.lua_get(
      [[vim.iter(lua_quickstart.effects):filter(function(item) return item.state ~= 'pending' end):totable()]]
    ),
    {}
  )
  expect.equality(
    child.cmd_capture('Plait packages sync!'),
    'Plait: Synchronizing 4 packages (blink.cmp, conform.nvim, mason.nvim, …; inspect: :Plait inspect packages).'
  )
  expect.equality(child.lua_get([[M.inspect('operations')[1].targets]]), {
    'blink.cmp',
    'conform.nvim',
    'mason.nvim',
    'nvim-lspconfig',
  })
end

T['canonical Lua quickstart']['installs a wholly absent provider set interactively and continues'] = function()
  child.restart({
    '--clean',
    '--cmd',
    [[lua vim.g.lua_quickstart_mode = 'interactive']],
    '-u',
    'tests/fixtures/lua_quickstart/init.lua',
  })

  expect.equality(child.lua_get([[lua_quickstart.validation.status]]), 'valid')
  expect.equality(child.lua_get([[lua_quickstart.result.status]]), 'performed')
  expect.equality(child.lua_get([[lua_quickstart.consent_calls]]), 1)
  expect.equality(child.lua_get([[lua_quickstart.provider_package_options]]), { load = false, confirm = false })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.state end, M.inspect('packages'))]]), {
    'satisfied',
    'satisfied',
    'satisfied',
    'satisfied',
  })
end

T['canonical Lua quickstart']['records synchronization restart and fresh-process recomputation'] = function()
  local shared_root = vim.fn.tempname()
  child.restart({
    '--clean',
    '--cmd',
    ("lua vim.g.lua_quickstart_mode = 'sync_success'; vim.g.lua_quickstart_root = %q"):format(shared_root),
    '-u',
    'tests/fixtures/lua_quickstart/init.lua',
  })

  expect.equality(
    child.cmd_capture('Plait packages sync!'),
    'Plait: Synchronizing 4 packages (blink.cmp, conform.nvim, mason.nvim, …; inspect: :Plait inspect packages).'
  )
  child.lua([[vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)]])
  expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'succeeded')
  assert_schema([[M.inspect('operations')]], {
    'completed_at',
    'diagnostic_codes',
    'error',
    'identity',
    'operation',
    'result',
    'started_at',
    'state',
    'targets',
  })
  assert_schema([[{ M.inspect('operations')[1].result }]], { 'details', 'operation', 'status' })
  expect.equality(
    child.lua_get([[vim.uv.fs_stat(vim.g.lua_quickstart_root .. '/config/nvim-pack-lock.json') ~= nil]]),
    true
  )
  expect.equality(
    child.lua_get([[vim.iter(M.inspect('packages')):all(function(item)
      return vim.uv.fs_stat(vim.g.lua_quickstart_root .. '/pack/plait/opt/' .. item.identity) ~= nil
    end)]]),
    true
  )
  local whole_operations = child.cmd_capture('Plait inspect operations')
  local filtered_operation = child.cmd_capture('Plait inspect operations op-00000001')
  expect.equality(child.cmd_capture('Plait inspect operations'), whole_operations)
  expect.equality(child.cmd_capture('Plait inspect operations op-00000001'), filtered_operation)
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.state end, M.inspect('packages'))]]), {
    'restart_required',
    'restart_required',
    'restart_required',
    'restart_required',
  })

  child.restart({
    '--clean',
    '--cmd',
    ("lua vim.g.lua_quickstart_mode = 'recomputed'; vim.g.lua_quickstart_root = %q"):format(shared_root),
    '-u',
    'tests/fixtures/lua_quickstart/init.lua',
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.state end, M.inspect('packages'))]]), {
    'satisfied',
    'satisfied',
    'satisfied',
    'satisfied',
  })
end

T['canonical Lua quickstart']['records failed synchronization with its accepted operation ID'] = function()
  child.restart({
    '--clean',
    '--cmd',
    [[lua vim.g.lua_quickstart_mode = 'sync_failure']],
    '-u',
    'tests/fixtures/lua_quickstart/init.lua',
  })

  expect.equality(
    child.cmd_capture('Plait packages sync!'),
    'Plait: Synchronizing 4 packages (blink.cmp, conform.nvim, mason.nvim, …; inspect: :Plait inspect packages).'
  )
  child.lua([[vim.wait(1000, function() return M.inspect('operations')[1].state ~= 'pending' end)]])
  expect.equality(child.lua_get([[M.inspect('operations')[1].state]]), 'failed')
  assert_schema([[M.inspect('operations')]], {
    'completed_at',
    'diagnostic_codes',
    'error',
    'identity',
    'operation',
    'result',
    'started_at',
    'state',
    'targets',
  })
  assert_schema([[{ M.inspect('operations')[1].error }]], { 'message', 'reason' })
  expect.equality(
    child.lua_get([[vim.iter(M.inspect('packages')):all(function(item)
      return item.state == 'partial_unknown' and item.inconsistency == 'interrupted_mutation'
    end)]]),
    true
  )
  expect.equality(
    child.lua_get([[M.inspect('diagnostics', 'package.partial_unknown')[1].details.operation_id]]),
    'op-00000001'
  )
end

for _, variant in ipairs({
  { mode = 'unsupported_neovim', codes = { 'environment.unsupported_neovim' } },
  { mode = 'package_path', codes = { 'environment.package_path' } },
  { mode = 'git_unavailable', codes = { 'environment.git_unavailable' } },
}) do
  T['canonical Lua quickstart']['blocks startup preflight for ' .. variant.mode] = function()
    child.restart({
      '--clean',
      '--cmd',
      ('lua vim.g.lua_quickstart_mode = %q'):format(variant.mode),
      '-u',
      'tests/fixtures/lua_quickstart/init.lua',
    })

    expect.equality(child.lua_get([[lua_quickstart.result.status]]), 'unavailable')
    expect.equality(child.lua_get([[lua_quickstart.result.reason]]), 'environment_unavailable')
    expect.equality(child.lua_get([[lua_quickstart.result.details.diagnostic_codes]]), variant.codes)
    expect.equality(child.lua_get([[lua_quickstart.result.plan_id]]), vim.NIL)
    expect.equality(
      child.lua_get([[vim.iter(lua_quickstart.effects):all(function(item) return item.state == 'pending' end)]]),
      true
    )
    local rendered = child.cmd_capture('Plait inspect diagnostics ' .. variant.codes[1] .. ' --json')
    expect.equality(
      vim.json.decode(rendered:sub(#'diagnostics: ' + 1)),
      child.lua_get(([[M.inspect('diagnostics', %q)]]):format(variant.codes[1]))
    )
    expect.equality(child.cmd_capture('Plait inspect diagnostics ' .. variant.codes[1] .. ' --json'), rendered)
  end
end

for _, inconsistency in ipairs({
  'checkout_without_lock',
  'lock_without_checkout',
  'malformed_metadata',
  'duplicate_metadata',
  'internal_source_mismatch',
  'internal_revision_mismatch',
  'interrupted_mutation',
}) do
  T['canonical Lua quickstart']['reports package inconsistency ' .. inconsistency] = function()
    child.restart({
      '--clean',
      '--cmd',
      ("lua vim.g.lua_quickstart_mode = 'partial'; vim.g.lua_quickstart_inconsistency = %q"):format(inconsistency),
      '-u',
      'tests/fixtures/lua_quickstart/init.lua',
    })

    expect.equality(child.lua_get([[lua_quickstart.result.reason]]), 'partial_unknown')
    expect.equality(
      child.lua_get(([[vim.iter(M.inspect('packages')):all(function(item)
        return item.state == 'partial_unknown' and item.inconsistency == %q
      end)]]):format(inconsistency)),
      true
    )
    expect.equality(
      child.lua_get([[M.inspect('diagnostics', 'package.partial_unknown')[1].details.operation_id]]),
      vim.NIL
    )
  end
end

return T
