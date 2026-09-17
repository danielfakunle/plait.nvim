local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)
teardown(function() child.stop() end)

describe('capability inspection', function()
  it('shows effective configuration without source lists by default', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { line_numbers = 'off' } })
      config:validate()
      inspection_before = M.inspect('capabilities', 'editor')
      vim.cmd('Plait inspect capabilities editor')
      inspection_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    ]])
    expect.equality(child.lua_get([[inspection_text:find('line_numbers: off', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[inspection_text:find('Configuration-wide health', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[inspection_text:find('completed snapshot', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[inspection_text:find('sources:', 1, true) == nil]]), true)
    expect.equality(child.lua_get([[vim.deep_equal(inspection_before, M.inspect('capabilities', 'editor'))]]), true)
    expect.equality(child.lua_get([[next(inspection_before.configuration.sources) ~= nil]]), true)
  end)
  it('accepts verbose detail and preserves complete JSON evidence', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:configure({ editor = { line_numbers = 'off' } })
      config:validate()
      vim.cmd('Plait inspect capabilities editor --verbose')
      verbose_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    ]])
    expect.equality(child.lua_get([[verbose_text:find('sources:', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[verbose_text:find('file: <nvim>', 1, true) ~= nil]]), true)
    local json = child.cmd_capture('Plait inspect capabilities editor --json')
    expect.equality(json:find('"sources":', 1, true) ~= nil, true)
    expect.equality(child.cmd_capture('Plait inspect capabilities editor --verbose --json'), json)
    child.cmd('Plait inspect --verbose capabilities editor')
    expect.equality(
      child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') == verbose_text]]),
      true
    )
    expect.equality(child.lua_get([[pcall(vim.cmd, 'Plait inspect capabilities editor --unknown')]]), false)
    expect.equality(child.lua_get([[pcall(vim.cmd, 'Plait inspect capabilities editor --verbose --verbose')]]), false)
  end)
  it('keeps configuration-wide degradation visible in a healthy Lua buffer', function()
    child.lua([[
      local root = vim.fn.tempname()
      local bin = root .. '/bin'
      vim.fn.mkdir(bin, 'p')
      for name, version in pairs({ stylua = 'stylua 2.5.2', ['lua-language-server'] = '3.19.1', tsc = 'Version 7.0.2', node = 'v24.0.0' }) do
        local path = bin .. '/' .. name
        vim.fn.writefile({ '#!/bin/sh', 'echo "' .. version .. '"' }, path)
        vim.fn.setfperm(path, 'rwxr-xr-x')
      end
      vim.env.PATH = bin
      vim.cmd.cd(root)
      vim.bo.filetype = 'lua'
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' })
      mixed_result = config:validate()
      mixed_tools = M.inspect('tools')
      vim.cmd('Plait inspect capabilities formatting')
      mixed_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      mixed_capability = M.inspect('capabilities', 'formatting')
      vim.fn.delete(root, 'rf')
    ]])
    expect.equality(child.lua_get([[mixed_result.status]]), 'valid')
    expect.equality(
      child.lua_get([[vim.tbl_map(function(tool) return { tool.identity, tool.state } end, mixed_tools)]]),
      {
        { 'lua-language-server', 'satisfied' },
        { 'oxfmt', 'absent' },
        { 'stylua', 'satisfied' },
        { 'tsc', 'satisfied' },
      }
    )
    expect.equality(child.lua_get([[mixed_capability.state]]), 'degraded')
    expect.equality(child.lua_get([[mixed_text:find('[DEGRADED] formatting', 1, true) ~= nil]]), true)
    expect.equality(
      child.lua_get([[mixed_text:find('oxfmt', 1, true) ~= nil and mixed_text:find('typescript', 1, true) ~= nil]]),
      true
    )
    expect.equality(child.lua_get([[mixed_text:find('Tool oxfmt is absent.', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[mixed_text:find('Repair:', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[mixed_text:find('tool.absent', 1, true) == nil]]), true)
  end)
  it('completes the detail option in each accepted inspection position', function()
    child.lua([[
      local config = M.config()
      config:select({ 'editor' })
      config:validate()
    ]])
    expect.equality(child.lua_get([[vim.fn.getcompletion('Plait inspect --v', 'cmdline')]]), { '--verbose' })
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect capabilities --v', 'cmdline')]]),
      { '--verbose' }
    )
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect capabilities editor --v', 'cmdline')]]),
      { '--verbose' }
    )
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect --verbose capabilities ed', 'cmdline')]]),
      { 'editor' }
    )
    expect.equality(
      child.lua_get([[vim.fn.getcompletion('Plait inspect capabilities editor --verbose ', 'cmdline')]]),
      { '--json' }
    )
  end)
  it('keeps disables and replacements concise and exposes their contribution history', function()
    child.lua([[
      local local_module = M.module({
        name = 'local.formatting.lua', provides = { 'local.formatting.lua' }, requires = { 'formatting', 'tooling' },
        contribute = { formatting = { by_filetype = { lua = { 'stylua' }, python = { 'stylua' } } } },
      })
      local config = M.config()
      config:select({ 'language', 'formatting', 'tooling', 'lang.lua', local_module })
      config:override({
        formatting = { by_filetype = { python = M.disable(), lua = M.replace({ 'stylua' }) } },
        language = { servers = { lua_ls = M.disable() } },
      })
      config:validate()
      vim.cmd('Plait inspect capabilities formatting')
      concise_chains = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      vim.cmd('Plait inspect capabilities language')
      concise_language = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      vim.cmd('Plait inspect capabilities formatting --verbose')
      detailed_chains = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      chain_evidence = M.inspect('capabilities', 'formatting')
    ]])
    expect.equality(
      child.lua_get([[concise_chains:find('python: none [disabled]; owner override (disable)', 1, true) ~= nil]]),
      true
    )
    expect.equality(
      child.lua_get([[concise_chains:find('lua: stylua [effective]; owner override (replace)', 1, true) ~= nil]]),
      true
    )
    expect.equality(child.lua_get([[concise_chains:find('still permit formatting', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[concise_chains:find('file:', 1, true) == nil]]), true)
    expect.equality(
      child.lua_get(
        [[concise_language:find('language.servers.lua_ls: owner disable supersedes module contributions', 1, true) ~= nil]]
      ),
      true
    )
    expect.equality(child.lua_get([[detailed_chains:find('Contribution history:', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[detailed_chains:find('module: local.formatting.lua', 1, true) ~= nil]]), true)
    expect.equality(child.lua_get([[#chain_evidence.contribution_history > 0]]), true)
  end)
end)
