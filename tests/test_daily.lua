local MiniTest = require('mini.test')
local child = dofile('tests/helpers.lua').new_clean_neovim()
local expect = MiniTest.expect
local T = MiniTest.new_set({
  hooks = {
    pre_case = child.setup,
    post_case = function() dofile('tests/public_contract.lua')(child) end,
    post_once = child.stop,
  },
})

local function assert_rendered(mode)
  child.lua([[daily_renderer = dofile('tests/fixtures/daily/render.lua')]])
  for _, section in ipairs(child.lua_get([[daily_renderer.sections]])) do
    local actual = child.lua_get(([[daily_renderer.capture(%q)]]):format(section))
    local stable = section == 'modules' or section == 'packages' or section == 'operations'
    local base = 'tests/fixtures/daily/rendered/' .. (stable and 'satisfied' or mode) .. '/' .. section
    expect.equality(actual.json, table.concat(vim.fn.readfile(base .. '.json'), '\n'))
    expect.equality(actual.text, table.concat(vim.fn.readfile(base .. '.txt'), '\n'))
    local command = 'Plait inspect ' .. section .. ' --json'
    local rendered = child.cmd_capture(command)
    expect.equality(vim.json.decode(rendered:sub(#section + 3)), child.lua_get(([[M.inspect(%q)]]):format(section)))
    expect.equality(child.cmd_capture(command), rendered)
    child.lua(([[local original, copy = M.inspect(%q), M.inspect(%q)
      local function mutate(value)
        for key, item in pairs(value) do
          if type(item) == 'table' then mutate(item) else value[key] = 'mutated' end
        end
      end
      mutate(copy)
      daily_record_detached = vim.deep_equal(original, M.inspect(%q))
    ]]):format(section, section, section))
    expect.equality(child.lua_get([[daily_record_detached]]), true)
  end
end

local function assert_action_rendered(mode)
  child.lua([[daily_renderer = dofile('tests/fixtures/daily/render.lua')]])
  for _, section in ipairs({ 'operations', 'diagnostics' }) do
    local actual = child.lua_get(([[daily_renderer.capture(%q)]]):format(section))
    local base = 'tests/fixtures/daily/rendered/' .. mode .. '/actions-' .. section
    expect.equality(actual.json, table.concat(vim.fn.readfile(base .. '.json'), '\n'))
    expect.equality(actual.text, table.concat(vim.fn.readfile(base .. '.txt'), '\n'))
    local rendered = child.cmd_capture('Plait inspect ' .. section .. ' --json')
    expect.equality(vim.json.decode(rendered:sub(#section + 3)), child.lua_get(([[M.inspect(%q)]]):format(section)))
  end
  local timestamp = '^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ$'
  for _, operation in ipairs(child.lua_get([[M.inspect('operations')]])) do
    expect.equality(operation.started_at:match(timestamp) ~= nil, true)
    expect.equality(operation.completed_at:match(timestamp) ~= nil, true)
    expect.equality(operation.completed_at >= operation.started_at, true)
    local rendered = child.cmd_capture('Plait inspect operations ' .. operation.identity .. ' --json')
    expect.equality(vim.json.decode(rendered:sub(#'operations: ' + 1)), operation)
  end
end

T['daily configuration uses two spaces and remaps save'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/daily/init.lua' })
  expect.equality(child.lua_get([[daily.validation.status]]), 'valid')
  expect.equality(child.lua_get([[daily.result.status]]), 'performed')
  expect.equality(child.lua_get([[{ vim.bo.expandtab, vim.bo.shiftwidth, vim.bo.tabstop, vim.bo.softtabstop }]]), {
    true,
    2,
    2,
    -1,
  })
  for _, mode in ipairs({ 'n', 'i', 'x', 's' }) do
    expect.equality(child.lua_get(([[vim.fn.maparg('<leader>w', %q, false, true).buffer]]):format(mode)), 0)
    expect.equality(
      child.lua_get(([[type(vim.fn.maparg('<leader>w', %q, false, true).callback)]]):format(mode)),
      'function'
    )
  end
end

T['daily configuration locks the graph and completed effects'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/daily/init.lua' })
  assert_rendered('satisfied')
  local identities = function(section)
    return child.lua_get(([[vim.tbl_map(function(record) return record.identity end, M.inspect(%q))]]):format(section))
  end
  expect.equality(
    identities('modules'),
    { 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' }
  )
  expect.equality(
    identities('capabilities'),
    { 'completion', 'editor', 'formatting', 'lang.lua', 'lang.typescript', 'language', 'tooling' }
  )
  expect.equality(identities('packages'), { 'blink.cmp', 'conform.nvim', 'mason.nvim', 'nvim-lspconfig' })
  expect.equality(identities('tools'), { 'lua-language-server', 'oxfmt', 'stylua', 'tsc' })
  expect.equality(
    child.lua_get(
      [[(function() local values = vim.iter(M.inspect('modules')):filter(function(record) return record.identity:match('^lang%.') end):map(function(record) return record.contributions end):flatten():filter(function(target) return not vim.iter(M.inspect('capabilities', 'formatting').formatter_chains):any(function(record) return 'formatting.by_filetype.' .. record.filetype == target and record.state == 'disabled' end) end):totable(); table.sort(values); return values end)()]]
    ),
    {
      'formatting.by_filetype.javascript',
      'formatting.by_filetype.lua',
      'formatting.by_filetype.typescript',
      'formatting.by_filetype.typescriptreact',
      'formatting.formatters.oxfmt',
      'formatting.formatters.stylua',
      'language.servers.lua_ls',
      'language.servers.tsc',
      'tooling.tools.lua-language-server',
      'tooling.tools.oxfmt',
      'tooling.tools.stylua',
      'tooling.tools.tsc',
    }
  )
  expect.equality(identities('effects'), {
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
    'language/server-definition/tsc',
    'completion/actions-and-mappings',
    'editor/actions',
    'editor/mappings',
    'editor/yank-highlight',
    'formatting/actions-and-mapping',
    'language/actions-and-mappings',
    'tooling/actions',
    'tooling/startup-check',
    'language/service/lua_ls',
    'language/service/tsc',
  })
  for _, section in ipairs({ 'packages', 'tools', 'effects' }) do
    local state = section == 'effects' and 'completed' or 'satisfied'
    expect.equality(
      child.lua_get(
        ([[vim.iter(M.inspect(%q)):all(function(record) return record.state == %q end)]]):format(section, state)
      ),
      true
    )
  end
  expect.equality(child.lua_get([[daily.validation.diagnostics]]), {})
  expect.equality(child.lua_get([[M.inspect('diagnostics')]]), {})
  expect.equality(child.lua_get([[M.inspect('operations')]]), {})
  expect.equality(child.lua_get([[daily.result.details.plan_id]]), child.lua_get([[daily.validation.plan_id]]))
  child.lua([[
    daily.validation.plan.modules[1].identity = 'mutated'
    local a, b = M.inspect('capabilities'), M.inspect('capabilities')
    daily_detached = a ~= b and a[1] ~= b[1] and vim.deep_equal(a, b)
    a[1].configuration.values = {}
    daily_lifecycle_errors = {}
    for _, call in ipairs({ function() daily.config:apply() end, function() daily.config:select({}) end,
      function() daily.config:configure({}) end, function() daily.config:override({}) end,
      function() daily.config:providers({}) end, function() M.config() end }) do
      local ok, err = pcall(call)
      daily_lifecycle_errors[#daily_lifecycle_errors + 1] = { ok, tostring(err):match('plait:.*') }
    end
  ]])
  expect.equality(identities('modules')[1], 'editor')
  expect.equality(child.lua_get([[daily_detached]]), true)
  expect.equality(child.lua_get([[daily_lifecycle_errors]]), {
    { false, 'plait: apply may only be called once' },
    { false, 'plait: configuration collector is sealed' },
    { false, 'plait: configuration collector is sealed' },
    { false, 'plait: configuration collector is sealed' },
    { false, 'plait: configuration collector is sealed' },
    { false, 'plait: a configuration collector already exists' },
  })
end

T['manual formatting survives disabled save formatting and JSX chain'] = function()
  child.restart({ '--clean', '-u', 'tests/fixtures/daily/init.lua' })
  expect.equality(child.lua_get([[conform_setup.format_on_save]]), vim.NIL)
  expect.equality(child.lua_get([[conform_setup.format_after_save]]), vim.NIL)
  expect.equality(child.lua_get([[conform_setup.formatters_by_ft]]), {
    lua = { 'stylua' },
    javascript = { 'oxfmt' },
    typescript = { 'oxfmt' },
    typescriptreact = { 'oxfmt' },
  })
  expect.equality(
    child.lua_get([[vim.lsp.config.tsc.filetypes]]),
    { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }
  )
  expect.equality(child.lua_get([[M.inspect('capabilities', 'formatting').formatter_chains[2].state]]), 'disabled')
  expect.equality(
    child.lua_get([[M.inspect('capabilities', 'formatting').formatter_chains[2].declaration]]),
    'owner override (disable)'
  )
  for _, filetype in ipairs({ 'lua', 'javascript', 'typescript', 'typescriptreact' }) do
    child.lua(
      ([[vim.bo.filetype = %q; formatted = M.actions.formatting.format()
      vim.wait(1000, function() return M.inspect('operations', formatted.operation_id).state ~= 'pending' end)]]):format(
        filetype
      )
    )
    expect.equality(child.lua_get([[formatted.status]]), 'started')
    expect.equality(child.lua_get([[daily_format_options.formatters]]), { filetype == 'lua' and 'stylua' or 'oxfmt' })
    expect.equality(child.lua_get([[daily_format_options.lsp_format]]), 'never')
    expect.equality(child.lua_get([[M.inspect('operations', formatted.operation_id).state]]), 'succeeded')
  end
  child.lua([[vim.bo.filetype = 'javascriptreact'; jsx = M.actions.formatting.format()]])
  expect.equality(child.lua_get([[jsx]]), {
    status = 'unavailable',
    operation = 'formatting.format',
    reason = 'no_formatter',
    details = { buffer = 1 },
  })
  expect.equality(child.lua_get([[M.inspect('tools', 'oxfmt').ownership]]), 'project')
  expect.equality(child.lua_get([[M.inspect('tools', 'oxfmt').source]]), 'workspace')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'saved' })
    vim.fn.maparg('<leader>w', 'n', false, true).callback()]])
  expect.equality(child.lua_get([[vim.fn.readfile(vim.api.nvim_buf_get_name(0))]]), { 'saved' })
  expect.equality(child.lua_get([[#M.inspect('operations')]]), 4)
  assert_action_rendered('satisfied')
end

for _, tool in ipairs({ 'tsc', 'lua-language-server', 'oxfmt', 'stylua', 'node' }) do
  for _, state in ipairs({ 'absent', 'incompatible', 'unprobeable' }) do
    T['daily degradation: ' .. tool .. ' ' .. state] = function()
      child.restart({
        '--clean',
        '--cmd',
        ('lua vim.g.daily_tool = %q; vim.g.daily_tool_state = %q'):format(tool, state),
        '-u',
        'tests/fixtures/daily/init.lua',
      })
      expect.equality(child.lua_get([[daily.result.status]]), 'performed')
      assert_rendered(tool .. '-' .. state)
      local affected = tool == 'node' and { 'oxfmt', 'tsc' } or { tool }
      for _, identity in ipairs(affected) do
        expect.equality(child.lua_get(([[M.inspect('tools', %q).state]]):format(identity)), state)
      end
      child.lua([[dofile('tests/fixtures/daily/exercise.lua')]])
      assert_action_rendered(tool .. '-' .. state)
      expect.equality(child.lua_get([[daily_completion.sources.default]]), { 'lsp', 'path', 'snippets', 'buffer' })
      for filetype, observed in pairs(child.lua_get([[daily_observations]])) do
        local server_tool = filetype == 'lua' and 'lua-language-server' or 'tsc'
        local degraded = tool == server_tool or (tool == 'node' and filetype ~= 'lua')
        for _, action in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
          local details = { buffer = 1, position = { line = 0, character = 0 } }
          if degraded then
            details.capability, details.language, details.filetype =
              'language', filetype == 'lua' and 'lang.lua' or 'lang.typescript', filetype
            details.server, details.tool, details.state = filetype == 'lua' and 'lua_ls' or 'tsc', server_tool, state
          end
          expect.equality(observed.requests[action], {
            status = 'unavailable',
            operation = 'language.' .. action,
            reason = degraded and 'tool_' .. state or 'no_client',
            details = details,
          })
        end
        local formatter = filetype == 'lua' and 'stylua' or 'oxfmt'
        local blocked = tool == formatter or (tool == 'node' and formatter == 'oxfmt')
        if filetype == 'javascriptreact' then
          expect.equality(observed.format, {
            status = 'unavailable',
            operation = 'formatting.format',
            reason = 'no_formatter',
            details = { buffer = 1 },
          })
        elseif blocked then
          local unavailable = { { formatter = formatter, tool = formatter, state = state } }
          expect.equality(observed.format, {
            status = 'unavailable',
            operation = 'formatting.format',
            reason = 'formatter_chain_unavailable',
            details = { buffer = 1, unavailable = unavailable },
          })
          expect.equality(observed.format_diagnostic, { filetype = filetype, unavailable = unavailable })
        else
          expect.equality(observed.format.status, 'started')
          expect.equality(observed.operation.state, 'succeeded')
        end
        for _, action in ipairs({ 'previous_diagnostic', 'next_diagnostic' }) do
          local result = action == 'previous_diagnostic' and observed.previous or observed.next_diagnostic
          expect.equality(result, {
            status = 'unavailable',
            operation = 'language.' .. action,
            reason = 'no_diagnostics',
            details = { buffer = 1 },
          })
        end
        expect.equality(
          observed.completion,
          { status = 'performed', operation = 'completion.trigger', details = { buffer = 1 } }
        )
        expect.equality(
          observed.native_navigation,
          { status = 'performed', operation = 'language.next_diagnostic', details = { buffer = 1 } }
        )
      end
    end
  end
end

T['project-owned oxfmt retains its closed declaration and provider escape hatch'] = function()
  child.lua([[
    local config = M.config()
    config:select({ 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' })
    config:override({ tooling = { tools = { oxfmt = M.replace({ executable = 'oxfmt', version = '=0.66.0',
      ownership = 'project', workspace_paths = { 'node_modules/.bin/oxfmt' } }) } } })
    config:providers({ formatting = { ['conform.nvim'] = { formatters = { oxfmt = { prepend_args = { '--check' } } } } } })
    owner_validation = config:validate()
    owner_history = vim.iter(M.inspect('capabilities', 'tooling').contribution_history):find(function(record)
      return record.target == 'tooling.tools.oxfmt'
    end)
  ]])
  expect.equality(child.lua_get([[owner_validation.status]]), 'valid')
  expect.equality(child.lua_get([[owner_history.overrides[1].operation]]), {
    kind = 'replace',
    value = {
      executable = 'oxfmt',
      version = '=0.66.0',
      ownership = 'project',
      workspace_paths = { 'node_modules/.bin/oxfmt' },
    },
  })
  expect.equality(child.lua_get([[owner_history.declarations[1].module]]), 'lang.typescript')
  expect.equality(child.lua_get([[owner_history.overrides[1].source.path]]), 'override')
  expect.equality(
    child.lua_get([[M.inspect('capabilities', 'formatting').configuration.providers[1].value]]),
    { prepend_args = { '--check' } }
  )
end

for _, extra in ipairs({ 'unknown = true', "mason = 'oxfmt'", "workspace_paths = { '../oxfmt' }" }) do
  T['project-owned oxfmt rejects invalid declaration: ' .. extra] = function()
    child.lua(([[local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.typescript' })
      config:override({ tooling = { tools = { oxfmt = M.replace({ executable = 'oxfmt', version = '=0.66.0',
        ownership = 'project', workspace_paths = { 'node_modules/.bin/oxfmt' }, %s }) } } })
      invalid_owner = config:validate()
    ]]):format(extra))
    expect.equality(child.lua_get([[invalid_owner.status]]), 'invalid')
    expect.equality(child.lua_get([[invalid_owner.plan]]), vim.NIL)
    expect.equality(child.lua_get([[#invalid_owner.diagnostics > 0]]), true)
    for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools', 'operations' }) do
      expect.equality(child.lua_get(([[M.inspect(%q)]]):format(section)), {})
    end
  end
end

return T
