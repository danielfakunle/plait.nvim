local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

describe('configuration validation', function()
  it('aggregates independent closed-schema errors in canonical order', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({
        unknown = true,
        editor = {
          line_numbers = 1,
          indentation = { width = math.huge },
          mappings = { save = string.char(0xff) },
        },
      })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.plan]]), vim.NIL)
    expect.equality(child.lua_get([[result.plan_id]]), vim.NIL)
    expect.equality(child.lua_get([[result.modules]]), {})
    expect.equality(child.lua_get([[result.capabilities]]), {})
    expect.equality(child.lua_get([[result.effects]]), {})
    expect.equality(child.lua_get([[result.packages]]), {})
    expect.equality(child.lua_get([[result.tools]]), {})
    expect.equality(
      child.lua_get([[
      vim.tbl_map(function(diagnostic) return diagnostic.code end, result.diagnostics)
    ]]),
      { 'config.invalid', 'config.invalid', 'config.invalid', 'config.invalid' }
    )
    expect.equality(
      child.lua_get([[
      vim.tbl_map(function(diagnostic) return diagnostic.details.path end, result.diagnostics)
    ]]),
      {
        'configure.editor.indentation.width',
        'configure.editor.line_numbers',
        'configure.editor.mappings.save',
        'configure.unknown',
      }
    )
    expect.equality(child.lua_get([[M.inspect('effects')]]), {})
    expect.equality(child.lua_get([[#M.inspect('diagnostics', 'config.invalid')]]), 4)
  end)

  it('rejects malformed selection arrays', function()
    child.lua([[
      local config = M.config()
      config:select({ [1] = 'editor', [3] = 'editor', named = 'editor' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.diagnostics[1].details]]), {
      path = 'select',
      expected = 'a dense one-based array of module selections',
      observed = 'mixed or sparse table',
    })
  end)

  it('rejects metatable-driven declarations', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure(setmetatable({ editor = {} }, { __index = {} }))
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.diagnostics[1].details]]), {
      path = 'configure',
      expected = 'a plain map',
      observed = 'table with metatable',
    })
  end)

  it('rejects a false root declaration', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure(false)
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.diagnostics[1].details]]), {
      path = 'configure',
      expected = 'a plain map',
      observed = 'boolean',
    })
  end)

  it('rejects every non-finite numeric form', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { indentation = { width = 0 / 0 } } })
      nan_result = config:validate()
    ]])
    expect.equality(child.lua_get([[nan_result.diagnostics[1].details.observed]]), 'non-finite number')

    child.setup()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { indentation = { width = -math.huge } } })
      negative_infinity_result = config:validate()
    ]])
    expect.equality(child.lua_get([[negative_infinity_result.diagnostics[1].details.observed]]), 'non-finite number')
  end)

  it('enforces capability configuration enums, bounds, arrays, and closed fields', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'completion', 'formatting', 'tooling' })
      config:configure({
        language = { diagnostics = { signs = 'yes' } },
        completion = {
          sources = { [1] = 'lsp', [3] = 'path' },
          documentation = 'sometimes',
        },
        formatting = { timeout_ms = 60001, lsp_fallback = false },
        tooling = { install_on_startup = true },
      })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.details.path end, result.diagnostics)]]), {
      'configure.completion.documentation',
      'configure.completion.sources',
      'configure.formatting.lsp_fallback',
      'configure.formatting.timeout_ms',
      'configure.language.diagnostics.signs',
      'configure.tooling.install_on_startup',
    })
  end)

  it('publishes closed source-aware diagnostics', function()
    child.lua([[
      local config = M.config()
      config:select({ 'missing' })
      result = config:validate()
      diagnostic = result.diagnostics[1]
    ]])

    expect.equality(
      child.lua_get([[
      (function()
        local keys = vim.tbl_keys(diagnostic)
        table.sort(keys)
        return keys
      end)()
    ]]),
      {
        'code',
        'details',
        'related_sources',
        'repair',
        'severity',
        'source',
        'summary',
      }
    )
    expect.equality(child.lua_get([[diagnostic.code]]), 'config.invalid')
    expect.equality(child.lua_get([[diagnostic.severity]]), 'error')
    expect.equality(child.lua_get([[diagnostic.summary]]), 'Invalid value at select[1].')
    expect.equality(child.lua_get([[diagnostic.repair]]), 'Use one value/form named by `expected`.')
    expect.equality(child.lua_get([[diagnostic.source.path]]), 'select[1]')
    expect.equality(child.lua_get([[diagnostic.related_sources]]), {})
    expect.equality(child.lua_get([[diagnostic.details]]), {
      path = 'select[1]',
      expected = 'one of "completion", "editor", "formatting", "lang.lua", "lang.typescript", "language", "tooling"',
      observed = '"missing"',
    })
  end)

  it('aggregates missing dependencies without implicitly selecting modules', function()
    child.lua([[
      local config = M.config()
      config:select({ 'lang.lua', 'completion' })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.plan]]), vim.NIL)
    expect.equality(child.lua_get([[result.modules]]), {})
    expect.equality(child.lua_get([[result.capabilities]]), {})
    expect.equality(
      child.lua_get([[
        vim.tbl_map(function(item)
          return { code = item.code, details = item.details, source = item.source }
        end, result.diagnostics)
      ]]),
      {
        {
          code = 'dependency.missing',
          details = { module = 'lang.lua', capability = 'formatting' },
          source = { file = '<nvim>', line = 2, path = 'select[1]' },
        },
        {
          code = 'dependency.missing',
          details = { module = 'lang.lua', capability = 'language' },
          source = { file = '<nvim>', line = 2, path = 'select[1]' },
        },
        {
          code = 'dependency.missing',
          details = { module = 'lang.lua', capability = 'tooling' },
          source = { file = '<nvim>', line = 2, path = 'select[1]' },
        },
        {
          code = 'dependency.missing',
          details = { module = 'completion', capability = 'language' },
          source = { file = '<nvim>', line = 2, path = 'select[2]' },
        },
      }
    )
  end)

  it('treats repeated semantic arrays as atomic declarations', function()
    child.lua([[
      local config = M.config()
      config:select({ 'language', 'completion' })
      config:configure({ completion = { sources = { 'lsp' } } })
      config:configure({ completion = { sources = { 'lsp', 'path' } } })
      result = config:validate()
    ]])

    expect.equality(child.lua_get([[result.status]]), 'invalid')
    expect.equality(child.lua_get([[result.diagnostics[1].details.path]]), 'configure.completion.sources')
  end)

  it('retains dependency errors independent of invalid selections', function()
    child.lua([[
      local config = M.config()
      config:select({ 'missing', 'completion' })
      result = config:validate()
    ]])

    expect.equality(
      child.lua_get([[vim.tbl_map(function(item) return item.code end, result.diagnostics)]]),
      { 'config.invalid', 'dependency.missing' }
    )
    expect.equality(child.lua_get([[result.diagnostics[2].details]]), {
      module = 'completion',
      capability = 'language',
    })
  end)

  it('renders canonical diagnostic lines through the headless command', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { line_numbers = 'bad' } })
    ]])

    expect.equality(
      child.cmd_capture('Plait validate'),
      table.concat({
        'ERROR config.invalid: Invalid value at configure.editor.line_numbers. '
          .. '[at <nvim>:3 configure.editor.line_numbers] '
          .. '[repair: Use one value/form named by `expected`.] '
          .. '[details: {"expected":"one of \\"absolute\\", \\"relative\\", \\"off\\"",'
          .. '"observed":"\\"bad\\"","path":"configure.editor.line_numbers"}]',
        'invalid',
      }, '\n')
    )
  end)

  it('sanitizes and truncates diagnostic interpolation at UTF-8 boundaries', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      local key = string.rep('界', 70) .. '\nsecret' .. string.char(0xff)
      config:configure({ [key] = true })
      diagnostic = config:validate().diagnostics[1]
    ]])

    expect.equality(child.lua_get([[#diagnostic.summary <= 160]]), true)
    expect.equality(child.lua_get([[diagnostic.summary:find('[\n\r]') == nil]]), true)
    expect.equality(child.lua_get([[diagnostic.summary:sub(-4)]]), '....')
    expect.equality(child.lua_get([[pcall(vim.str_utfindex, diagnostic.summary)]]), true)
    expect.equality(child.lua_get([[diagnostic.details.path:find('\n') == nil]]), true)
  end)
end)
