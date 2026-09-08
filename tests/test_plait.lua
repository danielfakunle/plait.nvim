local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

local minimal_editor = [[
  config = M.config()
  config:select({ 'editor' })
  config:configure({
    editor = {
      line_numbers = 'absolute',
      persistent_undo = true,
      yank_highlight = true,
      splits = { horizontal = 'below', vertical = 'right' },
      indentation = { style = 'spaces', width = 2 },
      wrap = false,
      clipboard = 'auto',
      mappings = {
        save = '<C-s>',
        clear_search = '<Esc>',
        focus_left = '<C-h>',
        focus_down = '<C-j>',
        focus_up = '<C-k>',
        focus_right = '<C-l>',
      },
    },
  })
]]

local function without_provenance(plan)
  local semantic = vim.deepcopy(plan)
  semantic.snapshot_state = nil
  for _, module in ipairs(semantic.modules) do
    module.selection_sources = nil
  end
  for _, effect in ipairs(semantic.effects) do
    effect.sources = nil
    effect.state = nil
    effect.error = nil
  end
  for _, capability in ipairs(semantic.capabilities) do
    capability.configuration.sources = nil
  end
  return semantic
end

describe('effective plan', function()
  it('validates and publishes the minimal editor plan', function()
    child.lua(minimal_editor .. [[result = config:validate()]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[result.diagnostics]]), {})
    expect.equality(child.lua_get([[result.plan_id:match('^[0-9a-f]+$') and #result.plan_id]]), 64)
    expect.equality(child.lua_get([[M.inspect('modules')]]), {
      {
        identity = 'editor',
        state = 'active',
        selection_sources = {
          { file = '<nvim>', line = 2, path = 'select[1]' },
        },
        provides = { 'editor' },
        requires = {},
        ordering_edges = {},
        contributions = { 'editor.configuration' },
      },
    })
    expect.equality(
      child.lua_get([[
      (function()
        local capabilities = M.inspect('capabilities')
        for _, capability in ipairs(capabilities) do
          capability.configuration = capability.configuration.values
        end
        return capabilities
      end)()
    ]]),
      {
        {
          identity = 'editor',
          state = 'active',
          activator = 'editor',
          cardinality = 'exclusive',
          responsible_integration = 'editor/native',
          dependents = {},
          providers = {},
          configuration = {
            line_numbers = 'absolute',
            persistent_undo = true,
            yank_highlight = true,
            splits = { horizontal = 'below', vertical = 'right' },
            indentation = { style = 'spaces', width = 2 },
            wrap = false,
            clipboard = 'auto',
            mappings = {
              save = '<C-s>',
              clear_search = '<Esc>',
              focus_left = '<C-h>',
              focus_down = '<C-j>',
              focus_up = '<C-k>',
              focus_right = '<C-l>',
            },
          },
          contributions = { 'editor.configuration' },
          actions = {
            'editor.clear_search',
            'editor.focus',
            'editor.save',
          },
          degradation_reasons = {},
        },
      }
    )
  end)

  it('resolves every built-in module in canonical dependency order', function()
    child.lua([[
      local config = M.config()
      config:select({
        'lang.typescript',
        'tooling',
        'formatting',
        'completion',
        'language',
        'editor',
        'lang.lua',
      })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(
      child.lua_get([[
        vim.tbl_map(function(module)
          return {
            identity = module.identity,
            provides = module.provides,
            requires = module.requires,
            ordering_edges = module.ordering_edges,
          }
        end, M.inspect('modules'))
      ]]),
      {
        { identity = 'editor', provides = { 'editor' }, requires = {}, ordering_edges = {} },
        { identity = 'language', provides = { 'language' }, requires = {}, ordering_edges = {} },
        {
          identity = 'completion',
          provides = { 'completion' },
          requires = { 'language' },
          ordering_edges = { 'language' },
        },
        { identity = 'formatting', provides = { 'formatting' }, requires = {}, ordering_edges = { 'language' } },
        { identity = 'tooling', provides = { 'tooling' }, requires = {}, ordering_edges = {} },
        {
          identity = 'lang.lua',
          provides = { 'lang.lua' },
          requires = { 'formatting', 'language', 'tooling' },
          ordering_edges = { 'completion', 'formatting', 'language', 'tooling' },
        },
        {
          identity = 'lang.typescript',
          provides = { 'lang.typescript' },
          requires = { 'formatting', 'language', 'tooling' },
          ordering_edges = { 'completion', 'formatting', 'language', 'tooling' },
        },
      }
    )
    expect.equality(
      child.lua_get([[
        vim.tbl_map(function(capability)
          return {
            identity = capability.identity,
            activator = capability.activator,
            cardinality = capability.cardinality,
            dependents = capability.dependents,
          }
        end, M.inspect('capabilities'))
      ]]),
      {
        {
          identity = 'completion',
          activator = 'completion',
          cardinality = 'exclusive',
          dependents = { 'lang.lua', 'lang.typescript' },
        },
        { identity = 'editor', activator = 'editor', cardinality = 'exclusive', dependents = {} },
        {
          identity = 'formatting',
          activator = 'formatting',
          cardinality = 'exclusive',
          dependents = { 'lang.lua', 'lang.typescript' },
        },
        { identity = 'lang.lua', activator = 'lang.lua', cardinality = 'exclusive', dependents = {} },
        {
          identity = 'lang.typescript',
          activator = 'lang.typescript',
          cardinality = 'exclusive',
          dependents = {},
        },
        {
          identity = 'language',
          activator = 'language',
          cardinality = 'exclusive',
          dependents = { 'completion', 'formatting', 'lang.lua', 'lang.typescript' },
        },
        {
          identity = 'tooling',
          activator = 'tooling',
          cardinality = 'exclusive',
          dependents = { 'lang.lua', 'lang.typescript' },
        },
      }
    )
  end)

  it('produces identical semantics for selection permutations', function()
    child.lua([[
      local config = M.config()
      config:select({ 'tooling', 'lang.lua', 'formatting', 'language' })
      first = config:validate()
    ]])
    local first_plan = without_provenance(child.lua_get([[first.plan]]))
    local first_modules = child.lua_get([[M.inspect('modules')]])
    local first_capabilities = child.lua_get([[M.inspect('capabilities')]])

    child.setup()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'formatting' })
      config:select({ 'lang.lua', 'tooling' })
      second = config:validate()
    ]])

    expect.equality(child.lua_get([[second.status]]), 'valid')
    expect.equality(without_provenance(child.lua_get([[second.plan]])), first_plan)
    expect.equality(
      child.lua_get([[vim.tbl_map(function(module) return module.identity end, M.inspect('modules'))]]),
      vim.tbl_map(function(module) return module.identity end, first_modules)
    )
    expect.equality(child.lua_get([[M.inspect('capabilities')]]), first_capabilities)
  end)

  it('produces identical semantics for declaration and table iteration permutations', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { wrap = true } })
      config:configure({ editor = { indentation = { width = 4, style = 'spaces' } } })
      first = config:validate()
    ]])
    local first_plan = without_provenance(child.lua_get([[first.plan]]))

    child.setup()
    child.lua([[
      local indentation = {}
      indentation.style = 'spaces'
      indentation.width = 4
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { indentation = indentation } })
      config:configure({ editor = { wrap = true } })
      second = config:validate()
    ]])

    expect.equality(child.lua_get([[second.status]]), 'valid')
    expect.equality(without_provenance(child.lua_get([[second.plan]])), first_plan)
  end)

  it('coalesces duplicate selections and retains every source reason', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor', 'editor' })
      config:select({ 'editor' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[#M.inspect('modules')]]), 1)
    expect.equality(child.lua_get([[#M.inspect('capabilities')]]), 1)
    expect.equality(child.lua_get([[M.inspect('modules', 'editor').selection_sources]]), {
      { file = '<nvim>', line = 2, path = 'select[1]' },
      { file = '<nvim>', line = 2, path = 'select[2]' },
      { file = '<nvim>', line = 3, path = 'select[1]' },
    })
  end)

  it('allows optional interactions to be absent without activating capabilities', function()
    child.lua([[
      local config = M.config()
      config:select({ 'formatting' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[M.inspect('modules', 'formatting').ordering_edges]]), {})
    expect.equality(
      child.lua_get([[vim.tbl_map(function(capability) return capability.identity end, M.inspect('capabilities'))]]),
      { 'formatting' }
    )
  end)

  it('returns detached inspection records', function()
    child.lua(minimal_editor .. [[
      config:validate()
      local first = M.inspect('modules')
      first[1].identity = 'changed'
      detached = M.inspect('modules')
    ]])

    expect.equality(child.lua_get([[detached[1].identity]]), 'editor')
    expect.equality(child.cmd_capture('Plait inspect packages'), 'packages: []')
    expect.equality(child.cmd_capture('Plait inspect modules'):find('"requires":[]', 1, true) ~= nil, true)
  end)

  it('revalidates deterministically and permits only one collector', function()
    child.lua(minimal_editor .. [[
      first = config:validate()
      second = config:validate()
      second_collector_ok, second_collector_error = pcall(M.config)
    ]])

    expect.equality(child.lua_get([[second.plan_id]]), child.lua_get([[first.plan_id]]))
    expect.equality(child.lua_get([[second_collector_ok]]), false)
    expect.equality(
      child.lua_get([[second_collector_error:match('plait: a configuration collector already exists$')]]),
      'plait: a configuration collector already exists'
    )
  end)

  it('revalidates newly collected declarations without sealing', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      first = config:validate()
      config:configure({ editor = { wrap = true } })
      second = config:validate()
    ]])

    expect.equality(child.lua_get([[first.status]]), 'valid')
    expect.equality(child.lua_get([[first.plan.capabilities[1].configuration.values.wrap]]), false)
    expect.equality(child.lua_get([[second.plan.capabilities[1].configuration.values.wrap]]), true)
    expect.equality(child.lua_get([[first.plan_id ~= second.plan_id]]), true)
  end)

  it('resolves every supported capability default and owner configuration', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor', 'language', 'completion', 'formatting', 'tooling' })
      config:configure({
        language = {
          diagnostics = { virtual_text = false, update_in_insert = true },
          mappings = { definition = false, hover = 'H' },
        },
        completion = {
          automatic = false,
          sources = { 'path', 'lsp' },
          documentation = 'automatic',
          signature_help = false,
          mappings = { trigger = false, accept = '<CR>' },
        },
        formatting = {
          on_save = false,
          timeout_ms = 60000,
          lsp_fallback = 'never',
          mappings = { format = false },
        },
        tooling = { check_on_startup = false },
      })
      result = config:validate()
      configurations = {}
      for _, capability in ipairs(result.plan.capabilities) do
        configurations[capability.identity] = capability.configuration.values
      end
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[configurations.language]]), {
      diagnostics = {
        signs = true,
        underline = true,
        virtual_text = false,
        severity_sort = true,
        update_in_insert = true,
      },
      mappings = {
        definition = false,
        references = 'gr',
        hover = 'H',
        rename = '<leader>cr',
        code_action = '<leader>ca',
        previous_diagnostic = '[d',
        next_diagnostic = ']d',
      },
      inlay_hints = false,
    })
    expect.equality(child.lua_get([[configurations.completion]]), {
      automatic = false,
      sources = { 'path', 'lsp' },
      documentation = 'automatic',
      signature_help = false,
      mappings = {
        trigger = false,
        next = '<C-n>',
        previous = '<C-p>',
        accept = '<CR>',
        cancel = '<C-e>',
        scroll_documentation_down = '<C-f>',
        scroll_documentation_up = '<C-b>',
      },
    })
    expect.equality(child.lua_get([[configurations.formatting]]), {
      on_save = false,
      timeout_ms = 60000,
      lsp_fallback = 'never',
      mappings = { format = false },
    })
    expect.equality(child.lua_get([[configurations.tooling]]), { check_on_startup = false })
    expect.equality(
      child.lua_get([[
        vim.tbl_filter(function(item)
          return item.path == 'configure.tooling.check_on_startup'
        end, M.inspect('capabilities', 'tooling').configuration.sources)
      ]]),
      { { file = '<nvim>', line = 3, path = 'configure.tooling.check_on_startup' } }
    )
    expect.equality(
      child.lua_get([[
        vim.tbl_filter(function(item)
          return item.path == 'configure.editor.line_numbers'
        end, M.inspect('capabilities', 'editor').configuration.sources)
      ]]),
      {
        {
          file = 'plait:v0.1/editor.line_numbers',
          line = 0,
          path = 'configure.editor.line_numbers',
        },
      }
    )
  end)

  it('identifies semantic plans independently of declaration order and provenance', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'completion' })
      config:configure({ completion = { sources = { 'path', 'lsp' } } })
      first = config:validate()
    ]])
    local first_id = child.lua_get([[first.plan_id]])

    child.setup()
    child.lua([[


      local config = M.config()
      config:configure({ completion = { sources = { 'path', 'lsp' } } })
      config:select({ 'completion' })
      config:select({ 'language' })
      equivalent = config:validate()
      config:configure({ completion = { documentation = 'automatic' } })
      changed = config:validate()
    ]])

    expect.equality(child.lua_get([[equivalent.plan_id]]), first_id)
    expect.equality(child.lua_get([[changed.plan_id ~= equivalent.plan_id]]), true)

    child.setup()
    child.lua([[
      local config = M.config()
      config:select({ 'completion', 'language' })
      config:configure({ completion = { sources = { 'lsp', 'path' } } })
      reordered = config:validate()
    ]])
    expect.equality(child.lua_get([[reordered.plan_id ~= first_id]]), true)
  end)

  it('returns the collector from collection methods', function()
    child.lua([[
      local config = M.config()
      same = config:select({ 'editor' }):configure({ editor = {} }):override({}):providers({}) == config
    ]])

    expect.equality(child.lua_get([[same]]), true)
  end)

  it('seals at first apply entry before argument checks', function()
    child.lua(minimal_editor .. [[
      config:validate()
      first_ok, first_error = pcall(function() config:apply('unexpected') end)
      collect_ok, collect_error = pcall(function() config:select({ 'editor' }) end)
      second_ok, second_error = pcall(function() config:apply() end)
      collector_ok, collector_error = pcall(M.config)
      diagnostics = M.inspect('diagnostics')
    ]])

    expect.equality(child.lua_get([[first_ok]]), false)
    expect.equality(
      child.lua_get([[first_error:match('plait: apply expects no arguments$')]]),
      'plait: apply expects no arguments'
    )
    expect.equality(child.lua_get([[collect_ok]]), false)
    expect.equality(
      child.lua_get([[collect_error:match('plait: configuration collector is sealed$')]]),
      'plait: configuration collector is sealed'
    )
    expect.equality(child.lua_get([[second_ok]]), false)
    expect.equality(
      child.lua_get([[second_error:match('plait: apply may only be called once$')]]),
      'plait: apply may only be called once'
    )
    expect.equality(child.lua_get([[collector_ok]]), false)
    expect.equality(
      child.lua_get([[collector_error:match('plait: a configuration collector already exists$')]]),
      'plait: a configuration collector already exists'
    )
    expect.equality(child.lua_get([[diagnostics]]), {})
  end)

  it('rejects every collection method after sealing', function()
    child.lua([[
      local config = M.config()
      pcall(function() config:apply('unexpected') end)
      errors = {}
      for _, call in ipairs({
        function() config:select({ 'editor' }) end,
        function() config:configure({ editor = {} }) end,
        function() config:override({}) end,
        function() config:providers({}) end,
      }) do
        local ok, err = pcall(call)
        errors[#errors + 1] = { ok = ok, sanitized = err:match('plait: configuration collector is sealed$') }
      end
    ]])

    expect.equality(child.lua_get([[errors]]), {
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
      { ok = false, sanitized = 'plait: configuration collector is sealed' },
    })
  end)

  it('collects disjoint declarations across repeated calls', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { wrap = true } })
      config:configure({ editor = { persistent_undo = false } })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'valid')
    expect.equality(child.lua_get([[result.plan.capabilities[1].configuration.values.wrap]]), true)
    expect.equality(child.lua_get([[result.plan.capabilities[1].configuration.values.persistent_undo]]), false)
  end)

  it('rejects incompatible repeated declarations without call-order precedence', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { wrap = true } })
      config:configure({ editor = { wrap = false } })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.effects]]), {})
  end)

  it('keeps prior results and inspections detached across snapshot replacement', function()
    child.lua(minimal_editor .. [[
      first = config:validate()
      first.plan.modules[1].identity = 'changed-result'
      first.diagnostics[1] = { code = 'changed-result' }

      inspection = M.inspect('capabilities')
      inspection[1].configuration.values.mappings.save = 'changed-inspection'

      config:configure({ editor = { wrap = 'invalid' } })
      second = config:validate()
      current = M.inspect('capabilities')
      current_diagnostics = M.inspect('diagnostics')
    ]])

    expect.equality(child.lua_get([[second.status]]), 'invalid')
    expect.equality(child.lua_get([[first.plan.capabilities[1].configuration.values.mappings.save]]), '<C-s>')
    expect.equality(child.lua_get([[current]]), {})
    expect.equality(child.lua_get([[current_diagnostics[1].code]]), 'config.invalid')
    expect.equality(child.lua_get([[M.inspect('diagnostics') ~= current_diagnostics]]), true)
  end)

  it('raises sanitized inspection misuse without changing the snapshot', function()
    child.lua(minimal_editor .. [[
      config:validate()
      before = M.inspect('modules')
      section_ok, section_error = pcall(function() M.inspect('missing\nsecret') end)
      identity_ok, identity_error = pcall(function() M.inspect('modules', 'missing\nsecret') end)
      after = M.inspect('modules')
      inspections_detached = before ~= after and before[1] ~= after[1]
    ]])

    expect.equality(child.lua_get([[section_ok]]), false)
    expect.equality(
      child.lua_get([[section_error:match('plait: unknown inspection section$')]]),
      'plait: unknown inspection section'
    )
    expect.equality(child.lua_get([[identity_ok]]), false)
    expect.equality(
      child.lua_get([[identity_error:match('plait: inspection identity not found$')]]),
      'plait: inspection identity not found'
    )
    expect.equality(child.lua_get([[vim.deep_equal(before, after)]]), true)
    expect.equality(child.lua_get([[inspections_detached]]), true)
  end)

  it('rejects inspection before a completed snapshot and invalid requests', function()
    child.lua([[
      before_ok, before_error = pcall(function() M.inspect('modules') end)
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
      section_ok, section_error = pcall(function() M.inspect('') end)
      identity_ok, identity_error = pcall(function() M.inspect('modules', {}) end)
    ]])

    expect.equality(child.lua_get([[before_ok]]), false)
    expect.equality(
      child.lua_get([[before_error:match('plait: inspection requires a completed snapshot$')]]),
      'plait: inspection requires a completed snapshot'
    )
    expect.equality(child.lua_get([[section_ok]]), false)
    expect.equality(
      child.lua_get([[section_error:match('plait: inspection section must be a non%-empty string$')]]),
      'plait: inspection section must be a non-empty string'
    )
    expect.equality(child.lua_get([[identity_ok]]), false)
    expect.equality(
      child.lua_get([[identity_error:match('plait: inspection identity must be a non%-empty string$')]]),
      'plait: inspection identity must be a non-empty string'
    )
  end)
end)
