local MiniTest = require('mini.test')
local helpers = dofile('tests/helpers.lua')

local child = helpers.new_clean_neovim()
local expect = MiniTest.expect

local lsp_guards = {
  'cmd',
  'filetypes',
  'root_dir',
  'root_markers',
  'workspace_folders',
  'workspace_required',
  'reuse_client',
  'name',
  'capabilities.textDocument.completion.completionItem.snippetSupport',
  'capabilities.textDocument.completion.completionItem.commitCharactersSupport',
  'capabilities.textDocument.completion.completionItem.documentationFormat',
  'capabilities.textDocument.completion.completionItem.deprecatedSupport',
  'capabilities.textDocument.completion.completionItem.preselectSupport',
  'capabilities.textDocument.completion.completionItem.tagSupport.valueSet',
  'capabilities.textDocument.completion.completionItem.insertReplaceSupport',
  'capabilities.textDocument.completion.completionItem.resolveSupport.properties',
  'capabilities.textDocument.completion.completionItem.insertTextModeSupport.valueSet',
  'capabilities.textDocument.completion.completionItem.labelDetailsSupport',
  'capabilities.textDocument.completion.completionList.itemDefaults',
  'capabilities.textDocument.completion.contextSupport',
  'capabilities.textDocument.completion.insertTextMode',
}

local guard_cases = {
  { capability = 'language', provider = 'vim.lsp', target = 'global', guards = lsp_guards },
  {
    capability = 'language',
    provider = 'vim.lsp',
    category = 'servers',
    target = 'lua_ls',
    guards = vim.list_extend(vim.deepcopy(lsp_guards), {
      'settings.Lua.runtime.version',
      'settings.Lua.workspace.checkThirdParty',
      'settings.Lua.workspace.library',
      'settings.Lua.telemetry.enable',
    }),
  },
  { capability = 'language', provider = 'vim.lsp', category = 'servers', target = 'tsc', guards = lsp_guards },
  {
    capability = 'completion',
    provider = 'blink.cmp',
    target = 'setup',
    guards = {
      'keymap',
      'sources.default',
      'sources.per_filetype',
      'enabled',
      'completion.menu.enabled',
      'completion.menu.auto_show',
      'completion.trigger.show_on_keyword',
      'completion.trigger.show_on_trigger_character',
      'completion.documentation.auto_show',
      'signature.enabled',
      'sources.providers.lsp.module',
      'sources.providers.lsp.enabled',
      'sources.providers.lsp.fallbacks',
      'sources.providers.lsp.score_offset',
      'sources.providers.path.module',
      'sources.providers.path.enabled',
      'sources.providers.path.fallbacks',
      'sources.providers.path.score_offset',
      'sources.providers.snippets.module',
      'sources.providers.snippets.enabled',
      'sources.providers.snippets.fallbacks',
      'sources.providers.snippets.score_offset',
      'sources.providers.buffer.module',
      'sources.providers.buffer.enabled',
      'sources.providers.buffer.fallbacks',
      'sources.providers.buffer.score_offset',
    },
  },
  {
    capability = 'formatting',
    provider = 'conform.nvim',
    target = 'setup',
    guards = {
      'formatters_by_ft',
      'formatters',
      'default_format_opts',
      'format_on_save',
      'format_after_save',
      'notify_on_error',
      'notify_no_formatters',
    },
  },
  {
    capability = 'formatting',
    provider = 'conform.nvim',
    category = 'formatters',
    target = 'stylua',
    guards = { 'command', 'format', 'inherit' },
  },
  {
    capability = 'formatting',
    provider = 'conform.nvim',
    category = 'formatters',
    target = 'oxfmt',
    guards = { 'command', 'format', 'inherit' },
  },
  {
    capability = 'tooling',
    provider = 'mason.nvim',
    target = 'setup',
    guards = { 'PATH', 'firewall.auto_managed' },
  },
}

local selected_modules = {
  'language',
  'completion',
  'formatting',
  'tooling',
  'lang.lua',
  'lang.typescript',
}

local function payload_at(path)
  local root = {}
  local cursor = root
  local parts = vim.split(path, '.', { plain = true })
  for index = 1, #parts - 1 do
    cursor[parts[index]] = {}
    cursor = cursor[parts[index]]
  end
  cursor[parts[#parts]] = true
  return root
end

local function declaration(case, payload)
  local target = case.category and { [case.category] = { [case.target] = payload } } or { [case.target] = payload }
  return { [case.capability] = { [case.provider] = target } }
end

local function validate_guard(case, owner_path, expected_guard)
  child.setup()
  child.lua(string.format(
    [[
      local config = M.config()
      config:select(%s)
      config:providers(%s)
      result = config:validate()
    ]],
    vim.inspect(selected_modules),
    vim.inspect(declaration(case, payload_at(owner_path)))
  ))
  local status = child.lua_get([[result.status]])
  if status ~= 'invalid' then
    error(('expected %s.%s %s to be guarded, got %s'):format(case.provider, case.target, owner_path, status))
  end
  expect.equality(child.lua_get([[#result.diagnostics]]), 1)
  expect.equality(child.lua_get([[result.diagnostics[1].code]]), 'provider.guarded_path')
  if expected_guard then
    expect.equality(child.lua_get([[result.diagnostics[1].details.generated_source.path]]), expected_guard)
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = child.setup,
    post_once = child.stop,
  },
})

T['provider escape hatches'] = MiniTest.new_set()

T['provider escape hatches']['compose disjoint maps and expose opaque provenance'] = function()
  child.lua([[
    local callback = function() return true end
    local config = M.config()
    config:select({ 'language', 'completion' })
    config:providers({ completion = { ['blink.cmp'] = { setup = { appearance = { nerd_font_variant = 'mono' } } } } })
    config:providers({ completion = { ['blink.cmp'] = { setup = { fuzzy = { implementation = 'lua' }, transform = callback } } } })
    result = config:validate()
    provider = M.inspect('capabilities', 'completion').configuration.providers[1]
  ]])

  expect.equality(child.lua_get([[result.status]]), 'valid')
  expect.equality(child.lua_get([[provider.identity]]), 'blink.cmp')
  expect.equality(child.lua_get([[provider.target]]), 'setup')
  expect.equality(child.lua_get([[provider.opaque]]), true)
  expect.equality(child.lua_get([[provider.revision_coupled]]), true)
  expect.equality(child.lua_get([[provider.value.appearance.nerd_font_variant]]), 'mono')
  expect.equality(child.lua_get([[provider.value.fuzzy.implementation]]), 'lua')
  expect.equality(child.lua_get([[provider.value.transform.kind]]), 'function')
  expect.equality(child.lua_get([[type(provider.value.transform.source)]]), 'string')
  expect.equality(child.lua_get([[provider.value.transform.line > 0]]), true)
  expect.equality(child.lua_get([[#provider.sources]]), 3)
end

T['provider escape hatches']['reject unsupported and ineffective targets'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'language' })
    config:providers({ language = { ['nvim-lspconfig'] = { setup = {} } } })
    config:providers({ language = { ['vim.lsp'] = { servers = { missing = { settings = {} } } } } })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.code end, result.diagnostics)]]), {
    'config.invalid',
    'config.invalid',
  })
end

T['provider escape hatches']['reject malformed opaque values'] = function()
  child.lua([[
    local cyclic = {}
    cyclic.self = cyclic
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = {
      cycle = cyclic,
      sparse = { [2] = 'bad' },
      mixed = { 'bad', key = true },
      infinite = math.huge,
      keyed = { [true] = 'bad' },
      meta = setmetatable({}, {}),
    } } } })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[#result.diagnostics]]), 6)
end

T['provider escape hatches']['coalesce equal leaves and conflict independent of call order'] = function()
  child.lua([[
    local function validate(first, second)
      local config = M.config()
      config:select({ 'tooling' })
      config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = first } } } } })
      config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = second } } } } })
      return config:validate()
    end
    equal = validate('single', 'single')
  ]])
  expect.equality(child.lua_get([[equal.status]]), 'valid')

  child.setup()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = 'single' } } } } })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = 'double' } } } } })
    result = config:validate()
  ]])
  expect.equality(child.lua_get([[result.diagnostics[1].code]]), 'contribution.conflict')
  expect.equality(child.lua_get([[#result.diagnostics[1].related_sources]]), 1)

  child.setup()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = 'single' } } } } })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = 'atomic' } } } })
    descendant_first = config:validate()
  ]])
  expect.equality(child.lua_get([[descendant_first.diagnostics[1].code]]), 'contribution.conflict')
  expect.equality(child.lua_get([[#descendant_first.diagnostics[1].related_sources]]), 1)

  child.setup()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = 'atomic' } } } })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = 'single' } } } } })
    ancestor_first = config:validate()
  ]])
  expect.equality(child.lua_get([[ancestor_first.diagnostics[1].code]]), 'contribution.conflict')
  expect.equality(child.lua_get([[#ancestor_first.diagnostics[1].related_sources]]), 1)
end

T['provider escape hatches']['provider provenance and map order do not change semantic identity'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = { border = 'single', width = 80 } } } } })
    first = config:validate()
  ]])
  local first_id = child.lua_get([[first.plan_id]])

  child.setup()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    local ui = {}
    ui.width = 80
    ui.border = 'single'
    config:providers({ tooling = { ['mason.nvim'] = { setup = { ui = ui } } } })
    second = config:validate()
  ]])
  expect.equality(child.lua_get([[second.plan_id]]), first_id)
end

T['provider escape hatches']['reject targets for inactive capabilities'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'editor' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = {} } } })
    result = config:validate()
  ]])
  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[result.diagnostics[1].code]]), 'config.invalid')
end

T['provider escape hatches']['qualify effective local server and formatter definitions'] = function()
  child.lua([[
    local python = M.module({
      name = 'local.lang.python', provides = { 'local.lang.python' },
      requires = { 'language', 'formatting', 'tooling' },
      contribute = {
        language = { servers = { basedpyright = { filetypes = { 'python' }, tool = 'basedpyright' } } },
        formatting = {
          formatters = { ruff = { tool = 'ruff' } },
          by_filetype = { python = { 'ruff' } },
        },
        tooling = { tools = {
          basedpyright = {
            executable = 'basedpyright-langserver', version = '>=1.0.0,<2.0.0',
            ownership = 'mason', mason = 'basedpyright',
          },
          ruff = {
            executable = 'ruff', version = '>=0.13.0,<0.14.0', ownership = 'mason', mason = 'ruff',
          },
        } },
      },
    })
    local config = M.config()
    config:select({ 'language', 'formatting', 'tooling', python })
    config:providers({ language = { ['vim.lsp'] = { servers = { basedpyright = {
      settings = { basedpyright = { analysis = { typeCheckingMode = 'basic' } } },
    } } } } })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'valid')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.identity end, result.plan.tools)]]), {
    'basedpyright',
    'ruff',
  })
end

T['provider escape hatches']['reject unqualified dynamic local definitions with actionable diagnostics'] = function()
  child.lua([[
    local unsupported = M.module({
      name = 'local.lang.unsupported', provides = { 'local.lang.unsupported' },
      requires = { 'language', 'formatting', 'tooling' },
      contribute = {
        language = { servers = { dynamic_server = { filetypes = { 'python' }, tool = 'server-tool' } } },
        formatting = {
          formatters = { dynamic_formatter = { tool = 'formatter-tool' } },
          by_filetype = { python = { 'dynamic_formatter' } },
        },
        tooling = { tools = {
          ['server-tool'] = {
            executable = 'server-tool', version = '=1.0.0', ownership = 'mason', mason = 'server-tool',
          },
          ['formatter-tool'] = {
            executable = 'formatter-tool', version = '=1.0.0', ownership = 'mason', mason = 'formatter-tool',
          },
        } },
      },
    })
    local config = M.config()
    config:select({ 'language', 'formatting', 'tooling', unsupported })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.code end, result.diagnostics)]]), {
    'provider.unqualified_definition',
    'provider.unqualified_definition',
  })
  expect.equality(
    child.lua_get([[result.diagnostics[1].repair]]),
    'Use a static definition qualified by the compatibility manifest.'
  )
end

T['provider escape hatches']['require every qualified local definition to reference an effective tool'] = function()
  child.lua([[
    local server = M.module({
      name = 'local.server', provides = { 'local.server' }, requires = { 'language', 'tooling' },
      contribute = {
        language = { servers = { basedpyright = { filetypes = { 'python' }, tool = 'missing' } } },
      },
    })
    local config = M.config()
    config:select({ 'language', 'tooling', server })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[result.diagnostics[1].code]]), 'provider.tool_requirement_missing')
  expect.equality(child.lua_get([[result.diagnostics[1].details.tool]]), 'missing')
end

T['provider escape hatches']['reject qualified definitions wired to mismatched executables'] = function()
  child.lua([[
    local python = M.module({
      name = 'local.lang.python', provides = { 'local.lang.python' },
      requires = { 'language', 'formatting', 'tooling' },
      contribute = {
        language = { servers = { basedpyright = { filetypes = { 'python' }, tool = 'ruff' } } },
        formatting = { formatters = { ruff = { tool = 'basedpyright' } }, by_filetype = { python = { 'ruff' } } },
        tooling = { tools = {
          basedpyright = { executable = 'basedpyright-langserver', version = '>=1.0.0,<2.0.0', ownership = 'mason', mason = 'basedpyright' },
          ruff = { executable = 'ruff', version = '>=0.13.0,<0.14.0', ownership = 'mason', mason = 'ruff' },
        } },
      },
    })
    local config = M.config()
    config:select({ 'language', 'formatting', 'tooling', python })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.code end, result.diagnostics)]]), {
    'provider.tool_requirement_mismatch',
    'provider.tool_requirement_mismatch',
  })
end

T['provider escape hatches']['reject guarded descendants and ancestors'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'language', 'completion', 'formatting', 'tooling', 'lang.lua' })
    config:providers({ completion = { ['blink.cmp'] = { setup = { keymap = { preset = 'none' } } } } })
    config:providers({ language = { ['vim.lsp'] = { servers = { lua_ls = {
      capabilities = { textDocument = { completion = true } },
    } } } } })
    config:providers({ formatting = { ['conform.nvim'] = { formatters = { stylua = { command = 'other' } } } } })
    config:providers({ tooling = { ['mason.nvim'] = { setup = { firewall = false } } } })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[result.status]]), 'invalid')
  expect.equality(
    child.lua_get(
      [[vim.tbl_map(function(item) return item.details.path end, M.inspect('diagnostics', 'provider.guarded_path'))]]
    ),
    {
      'keymap.preset',
      'capabilities.textDocument.completion',
      'command',
      'firewall',
    }
  )
end

T['provider escape hatches']['reject every guarded path directly and through a replacing boundary'] = function()
  for _, case in ipairs(guard_cases) do
    for _, guarded_path in ipairs(case.guards) do
      local expected_guard = guarded_path
      if guarded_path:match('^sources%.providers%.') then
        expected_guard = 'sources.providers.{lsp,path,snippets,buffer}.{module,enabled,fallbacks,score_offset}'
      end
      validate_guard(case, guarded_path, expected_guard)

      local parts = vim.split(guarded_path, '.', { plain = true })
      local replacing_path
      if #parts == 1 then
        replacing_path = guarded_path .. '.owned_descendant'
      else
        table.remove(parts)
        replacing_path = table.concat(parts, '.')
      end
      validate_guard(case, replacing_path)
    end
  end
end

T['provider escape hatches']['guard every effective local server and formatter through wildcard metadata'] = function()
  child.lua([[
    local python = M.module({
      name = 'local.lang.python', provides = { 'local.lang.python' },
      requires = { 'language', 'formatting', 'tooling' },
      contribute = {
        language = { servers = { basedpyright = { filetypes = { 'python' }, tool = 'basedpyright' } } },
        formatting = { formatters = { ruff = { tool = 'ruff' } }, by_filetype = { python = { 'ruff' } } },
        tooling = { tools = {
          basedpyright = { executable = 'basedpyright-langserver', version = '>=1.0.0,<2.0.0', ownership = 'mason', mason = 'basedpyright' },
          ruff = { executable = 'ruff', version = '>=0.13.0,<0.14.0', ownership = 'mason', mason = 'ruff' },
        } },
      },
    })
    local config = M.config()
    config:select({ 'language', 'formatting', 'tooling', python })
    config:providers({ language = { ['vim.lsp'] = { servers = { basedpyright = { cmd = true } } } } })
    config:providers({ language = { ['vim.lsp'] = { servers = { basedpyright = { cmd = { extra = true } } } } } })
    config:providers({ language = { ['vim.lsp'] = { servers = { basedpyright = { capabilities = true } } } } })
    config:providers({ formatting = { ['conform.nvim'] = { formatters = { ruff = { command = 'other' } } } } })
    config:providers({ formatting = { ['conform.nvim'] = { formatters = { ruff = { command = { extra = true } } } } } })
    config:providers({ formatting = { ['conform.nvim'] = { formatters = { ruff = true } } } })
    result = config:validate()
  ]])

  expect.equality(child.lua_get([[#M.inspect('diagnostics', 'provider.guarded_path')]]), 6)
end

T['provider escape hatches']['accept representative disjoint siblings beside every guard family'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'language', 'completion', 'formatting', 'tooling', 'lang.lua' })
    config:providers({ language = { ['vim.lsp'] = {
      global = { settings = { owner = true }, capabilities = { workspace = { configuration = true } } },
      servers = { lua_ls = { settings = { Lua = { runtime = { path = { '?.lua' } }, hint = { enable = true } } } } },
    } } })
    config:providers({ completion = { ['blink.cmp'] = { setup = {
      appearance = { nerd_font_variant = 'mono' },
      sources = { providers = { lsp = { opts = { tailwind = true } } } },
    } } } })
    config:providers({ formatting = { ['conform.nvim'] = {
      setup = { log_level = vim.log.levels.DEBUG },
      formatters = { stylua = { args = { '--search-parent-directories', '-' } } },
    } } })
    config:providers({ tooling = { ['mason.nvim'] = { setup = {
      install_root_dir = '/tmp/plait-mason', firewall = { enabled = true },
    } } } })
    result = config:validate()
  ]])
  expect.equality(child.lua_get([[result.status]]), 'valid')
end

T['provider escape hatches']['treat dotted map keys as one opaque path component'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'tooling' })
    config:providers({ tooling = { ['mason.nvim'] = { setup = {
      ['firewall.auto_managed'] = true,
    } } } })
    result = config:validate()
  ]])
  expect.equality(child.lua_get([[result.status]]), 'valid')
end

return T
