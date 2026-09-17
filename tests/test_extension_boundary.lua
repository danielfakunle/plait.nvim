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

local T = MiniTest.new_set({ hooks = { pre_case = child.setup, post_once = child.stop } })

T['extension boundary locks the canonical local module'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/extension_boundary/init.lua' })
  expect.equality(child.lua_get([[extension.validation.status]]), 'valid')
  expect.equality(child.lua_get([[extension.result.status]]), 'performed')
  expect.equality(child.lua_get([[vim.tbl_map(function(x) return x.identity end, M.inspect('modules'))]]), {
    'language',
    'formatting',
    'tooling',
    'local.lang.python',
  })
  expect.equality(child.lua_get([[M.inspect('modules', 'local.lang.python').contributions]]), {
    'formatting.by_filetype.python',
    'formatting.formatters.ruff',
    'language.servers.basedpyright',
    'tooling.tools.basedpyright',
    'tooling.tools.ruff',
  })
end

T['ordinary Lua remains outside every managed surface'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/extension_boundary/init.lua' })
  expect.equality(child.lua_get([[extension.ordinary_lua_excluded]]), true)
  expect.equality(child.lua_get([[vim.o.colorcolumn]]), '88')
  expect.equality(child.lua_get([[extension.validation.plan_id]]), child.lua_get([[extension.result.details.plan_id]]))
end

T['unavailable Python formatter chain is atomic and ordered'] = function()
  child.restart({
    '--clean',
    '--cmd',
    "lua vim.g.extension_mode = 'chain'",
    '-u',
    'tests/fixtures/extension_boundary/init.lua',
  })
  child.lua([[vim.bo.filetype = 'python'; chain_result = M.actions.formatting.format()]])
  local unavailable = {
    { formatter = 'ruff', tool = 'ruff', state = 'incompatible' },
    { formatter = 'oxfmt', tool = 'oxfmt', state = 'absent' },
  }
  expect.equality(child.lua_get([[chain_result]]), {
    status = 'unavailable',
    operation = 'formatting.format',
    reason = 'formatter_chain_unavailable',
    details = { buffer = 1, unavailable = unavailable },
  })
  expect.equality(child.lua_get([[format_called]]), vim.NIL)
  expect.equality(child.lua_get([[lsp_format_called]]), vim.NIL)
  expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  expect.equality(child.lua_get([[M.inspect('diagnostics', 'formatting.chain_unavailable')[1].details]]), {
    filetype = 'python',
    unavailable = unavailable,
  })
  assert_schema([[{ chain_result }]], { 'details', 'operation', 'reason', 'status' })
  assert_schema([[chain_result.details.unavailable]], { 'formatter', 'state', 'tool' })
  child.lua([[
    chain_result.details.unavailable[1].state = 'mutated'
    M.actions.formatting.format()
  ]])
  expect.equality(child.lua_get([[#M.inspect('diagnostics', 'formatting.chain_unavailable')]]), 1)
  expect.equality(
    child.lua_get([[M.inspect('diagnostics', 'formatting.chain_unavailable')[1].details.unavailable]]),
    unavailable
  )
end

T['locks public records, adapter semantics, provenance, and lifecycle'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/extension_boundary/init.lua' })
  expect.equality(child.lua_get([[vim.tbl_map(function(x) return x.identity end, M.inspect('capabilities'))]]), {
    'formatting',
    'language',
    'local.lang.python',
    'tooling',
  })
  expect.equality(
    child.lua_get([[vim.tbl_map(function(x) return { x.identity, x.version, x.state } end, M.inspect('tools'))]]),
    {
      { 'basedpyright', '1.31.4', 'satisfied' },
      { 'ruff', '0.13.2', 'satisfied' },
    }
  )
  expect.equality(
    child.lua_get([[vim.tbl_map(function(x) return { x.identity, x.state } end, M.inspect('packages'))]]),
    {
      { 'conform.nvim', 'satisfied' },
      { 'mason.nvim', 'satisfied' },
      { 'nvim-lspconfig', 'satisfied' },
    }
  )
  expect.equality(child.lua_get([[vim.tbl_map(function(x) return x.identity end, M.inspect('effects'))]]), {
    'formatting/package/conform.nvim',
    'language/package/nvim-lspconfig',
    'tooling/package/mason.nvim',
    'language/native-diagnostics',
    'tooling/provider-setup',
    'tooling/tool-resolution',
    'formatting/provider-setup',
    'language/server-definition/basedpyright',
    'formatting/actions-and-mapping',
    'language/actions-and-mappings',
    'tooling/actions',
    'tooling/startup-check',
    'language/service/basedpyright',
  })
  expect.equality(
    child.lua_get([[vim.tbl_map(function(x) return { x.stage, x.dependencies } end, M.inspect('effects'))]]),
    {
      { 2, {} },
      { 2, {} },
      { 2, {} },
      { 3, { 'language/package/nvim-lspconfig' } },
      { 3, { 'tooling/package/mason.nvim' } },
      { 3, { 'tooling/package/mason.nvim' } },
      { 3, { 'formatting/package/conform.nvim', 'tooling/tool-resolution' } },
      { 3, { 'language/package/nvim-lspconfig', 'tooling/tool-resolution' } },
      { 4, { 'formatting/provider-setup' } },
      { 4, { 'language/native-diagnostics' } },
      { 4, { 'tooling/tool-resolution' } },
      { 5, { 'tooling/tool-resolution' } },
      { 5, { 'language/server-definition/basedpyright', 'tooling/startup-check' } },
    }
  )
  expect.equality(
    child.lua_get(
      [[vim.iter(M.inspect('effects')):all(function(x) return x.state == 'completed' and x.error == vim.NIL end)]]
    ),
    true
  )
  expect.equality(child.lua_get([[extension.validation.plan.snapshot_state]]), 'validated')
  expect.equality(
    child.lua_get([[vim.iter(extension.validation.plan.effects):all(function(x) return x.state == 'pending' end)]]),
    true
  )
  expect.equality(child.lua_get([[extension.validation.diagnostics]]), {})
  expect.equality(child.lua_get([[M.inspect('diagnostics')]]), {})
  expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  expect.equality(child.lua_get([[enabled_server]]), 'basedpyright')
  expect.equality(child.lua_get([[basedpyright_config.filetypes]]), { 'python' })
  expect.equality(child.lua_get([[basedpyright_config.cmd]]), {
    child.lua_get([[vim.uv.fs_realpath(vim.fn.exepath('basedpyright-langserver'))]]),
    '--stdio',
  })
  expect.equality(child.lua_get([[basedpyright_config.settings]]), {
    basedpyright = { analysis = { diagnosticMode = 'openFilesOnly', typeCheckingMode = 'basic' } },
  })
  expect.equality(
    child.lua_get([[basedpyright_config.root_markers]]),
    { 'pyrightconfig.json', 'pyproject.toml', '.git' }
  )
  expect.equality(child.lua_get([[conform_setup.formatters_by_ft]]), { python = { 'ruff' } })
  expect.equality(child.lua_get([[conform_setup.formatters.ruff]]), {
    command = child.lua_get([[vim.uv.fs_realpath(vim.fn.exepath('ruff'))]]),
    args = { 'format', '--force-exclude', '--stdin-filename', '$FILENAME', '-' },
    stdin = true,
  })
  local providers = child.lua_get([[M.inspect('capabilities', 'language').configuration.providers]])
  expect.equality(#providers, 1)
  expect.equality(providers[1].identity, 'vim.lsp')
  expect.equality(providers[1].target, 'basedpyright')
  expect.equality(providers[1].opaque, true)
  expect.equality(providers[1].revision_coupled, true)
  expect.equality(providers[1].value, { settings = { basedpyright = { analysis = { typeCheckingMode = 'basic' } } } })
  expect.equality(#providers[1].sources, 1)
  expect.equality(providers[1].sources[1].file, 'tests/fixtures/extension_boundary/config.lua')
  expect.equality(
    providers[1].sources[1].path,
    'providers.language.vim.lsp.servers.basedpyright.settings.basedpyright.analysis.typeCheckingMode'
  )
  expect.equality(providers[1].sources[1].line, 10)
  for _, capability in ipairs({ 'formatting', 'local.lang.python', 'tooling' }) do
    expect.equality(child.lua_get(([[M.inspect('capabilities', %q).configuration.providers]]):format(capability)), {})
  end
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

  assert_schema([[M.inspect('capabilities', 'language').configuration.providers]], {
    'identity',
    'opaque',
    'revision_coupled',
    'sources',
    'target',
    'value',
  })
  assert_schema([[M.inspect('capabilities', 'formatting').formatter_chains]], {
    'chain',
    'declaration',
    'filetype',
    'reason',
    'sources',
    'state',
  })
  assert_schema([[{ extension.validation }]], { 'diagnostics', 'plan', 'plan_id', 'status' })
  assert_schema(
    [[{ extension.validation.plan }]],
    { 'capabilities', 'effects', 'modules', 'packages', 'snapshot_state', 'tools' }
  )
  assert_schema([[{ extension.result }]], { 'details', 'operation', 'status' })
  child.lua([[
    original_capabilities = M.inspect('capabilities')
    local copy = M.inspect('capabilities')
    inspection_detached = copy ~= original_capabilities and copy[1] ~= original_capabilities[1]
    copy[1].configuration.values.on_save = false
    inspection_detached = inspection_detached and vim.deep_equal(original_capabilities, M.inspect('capabilities'))
    extension.validation.plan.modules[1].identity = 'mutated'
    lifecycle_errors = {}
    for _, call in ipairs({
      function() extension.config:apply() end,
      function() extension.config:select({}) end,
      function() extension.config:configure({}) end,
      function() extension.config:override({}) end,
      function() extension.config:providers({}) end,
      function() M.config() end,
    }) do
      local ok, err = pcall(call)
      assert(not ok)
      lifecycle_errors[#lifecycle_errors + 1] = tostring(err):match('plait:.*')
    end
  ]])
  expect.equality(child.lua_get([[inspection_detached]]), true)
  expect.equality(child.lua_get([[M.inspect('modules')[1].identity]]), 'language')
  expect.equality(child.lua_get([[lifecycle_errors]]), {
    'plait: apply may only be called once',
    'plait: configuration collector is sealed',
    'plait: configuration collector is sealed',
    'plait: configuration collector is sealed',
    'plait: configuration collector is sealed',
    'plait: a configuration collector already exists',
  })
end

T['ordinary Lua cannot change semantic plan identity'] = function()
  local ids = {}
  for _, value in ipairs({ '88', '99' }) do
    child.restart({
      '--clean',
      '--cmd',
      ('lua vim.opt.colorcolumn = %q'):format(value),
      '-u',
      'tests/fixtures/extension_boundary/init.lua',
    })
    ids[#ids + 1] = child.lua_get([[extension.validation.plan_id]])
    for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }) do
      local rendered = child.cmd_capture('Plait inspect ' .. section .. ' --json')
      expect.equality(rendered:find('colorcolumn', 1, true), nil)
      expect.equality(rendered:find('"88"', 1, true), nil)
      expect.equality(rendered:find('"99"', 1, true), nil)
    end
    expect.equality(child.lua_get([[vim.inspect(extension.validation.plan):find('colorcolumn', 1, true)]]), vim.NIL)
  end
  expect.equality(ids[1], ids[2])
end

T['provider escape hatch rejects guarded ownership paths'] = function()
  child.restart({
    '--clean',
    '--cmd',
    "lua vim.g.extension_mode = 'guard'",
    '-u',
    'tests/fixtures/extension_boundary/init.lua',
  })
  expect.equality(child.lua_get([[extension.validation.status]]), 'invalid')
  expect.equality(child.lua_get([[extension.result]]), {
    status = 'unavailable',
    operation = 'apply',
    reason = 'invalid_plan',
    details = { diagnostic_codes = { 'provider.guarded_path' } },
  })
  expect.equality(child.lua_get([[vim.tbl_map(function(x) return x.details.path end, M.inspect('diagnostics'))]]), {
    'command',
    'cmd.1',
  })
  expect.equality(child.lua_get([[extension.validation.plan]]), vim.NIL)
  expect.equality(child.lua_get([[extension.validation.plan_id]]), vim.NIL)
  for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools', 'operations' }) do
    expect.equality(child.lua_get(([[M.inspect(%q)]]):format(section)), {})
  end
  expect.equality(child.lua_get([[conform_setup]]), vim.NIL)
  expect.equality(child.lua_get([[enabled_server]]), vim.NIL)
end

local function normalize_rendered(value, paths)
  local function replace(old, new)
    value = value:gsub(old:gsub('([^%w])', '%%%1'), function() return new end)
  end
  for _, name in ipairs({ 'bin', 'root' }) do
    replace(paths[name].real, '<' .. name .. '>')
    replace(paths[name].path, '<' .. name .. '>')
  end
  replace(vim.fn.getcwd() .. '/', '')
  return value
end

for _, mode in ipairs({ 'satisfied', 'chain', 'guard' }) do
  T['canonical text and JSON lock every semantic field: ' .. mode] = function()
    child.restart({
      '--clean',
      '--cmd',
      ('lua vim.g.extension_mode = %q'):format(mode),
      '-u',
      'tests/fixtures/extension_boundary/init.lua',
    })
    if mode == 'chain' then child.lua([[vim.bo.filetype = 'python'; M.actions.formatting.format()]]) end
    local paths = child.lua_get([[vim.tbl_map(function(path)
      return { path = path, real = vim.uv.fs_realpath(path) or path }
    end, extension_paths)]])
    local sections = mode == 'guard' and { 'diagnostics' }
      or { 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }
    for _, section in ipairs(sections) do
      local base = 'tests/fixtures/extension_boundary/rendered/' .. mode .. '/' .. section
      local expected_json = table.concat(vim.fn.readfile(base .. '.json'), '\n')
      local expected_text = table.concat(vim.fn.readfile(base .. '.txt'), '\n')
      local prefix = section .. ': '
      local rendered = child.cmd_capture('Plait inspect ' .. section .. ' --json')
      expect.equality(normalize_rendered(rendered, paths), prefix .. expected_json)
      -- JSON literals lock all scalar values and every nested semantic array, independently of field-name checks.
      expect.equality(
        vim.json.decode(expected_json),
        vim.json.decode(normalize_rendered(rendered:sub(#prefix + 1), paths))
      )
      expect.equality(vim.json.decode(rendered:sub(#prefix + 1)), child.lua_get(([[M.inspect(%q)]]):format(section)))
      expect.equality(child.cmd_capture('Plait inspect ' .. section .. ' --json'), rendered)
      child.lua(([[vim.cmd(%q)]]):format('Plait inspect ' .. section))
      local text = child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
      expect.equality(normalize_rendered(text, paths), expected_text)
      expect.equality(text:find('colorcolumn', 1, true), nil)
      if mode == 'satisfied' then
        for _, record in ipairs(child.lua_get(([[M.inspect(%q)]]):format(section))) do
          local command = ('Plait inspect %s %s'):format(section, record.identity)
          local filtered = child.cmd_capture(command .. ' --json')
          expect.equality(
            vim.json.decode(filtered:sub(#prefix + 1)),
            child.lua_get(([[M.inspect(%q, %q)]]):format(section, record.identity))
          )
          expect.equality(child.cmd_capture(command .. ' --json'), filtered)
          child.lua(([[vim.cmd(%q)]]):format(command))
          expect.equality(
            child
              .lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]])
              :find(record.identity, 1, true) ~= nil,
            true
          )
        end
      end
      child.lua(([[
        local original, copy = M.inspect(%q), M.inspect(%q)
        local function mutate(value)
          for key, item in pairs(value) do
            if type(item) == 'table' then mutate(item) else value[key] = 'mutated' end
          end
        end
        mutate(copy)
        detached = vim.deep_equal(original, M.inspect(%q))
      ]]):format(section, section, section))
      expect.equality(child.lua_get([[detached]]), true)
    end
  end
end

return T
