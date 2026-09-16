local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function()
  child.restart({ '--clean', '-u', 'tests/fixtures/language_apply/init.lua' })
  child.lua([[
    clients = {}
    vim.lsp.get_clients = function(options) return clients[options.bufnr] or {} end
    function client(id, methods)
      return { id = id, supports_method = function(_, method) return vim.list_contains(methods, method) end }
    end
    function event(name, buffer, id)
      vim.api.nvim_exec_autocmds(name, { buffer = buffer, data = { client_id = id } })
    end
    function mapping(buffer, lhs, mode)
      return vim.api.nvim_buf_call(buffer, function() return vim.fn.maparg(lhs, mode or 'n', false, true) end)
    end
    buffer = vim.api.nvim_get_current_buf()
  ]])
end)
teardown(function() child.stop() end)

describe('language mapping lifecycle', function()
  it('reconciles each action against clients remaining during detach', function()
    child.lua([[
      clients[buffer] = {
        client(1, { 'textDocument/references', 'textDocument/definition' }),
        client(2, { 'textDocument/references' }),
      }
      event('LspAttach', buffer, 1)
      event('LspDetach', buffer, 1)
      retained = mapping(buffer, 'gr')
      removed = mapping(buffer, 'gd')
      clients[buffer] = { clients[buffer][2] }
      event('LspDetach', buffer, 2)
      final = mapping(buffer, 'gr')
    ]])
    expect.equality(child.lua_get([[retained.buffer]]), 1)
    expect.equality(child.lua_get([[next(removed)]]), vim.NIL)
    expect.equality(child.lua_get([[next(final)]]), vim.NIL)
  end)
  it('preserves replacements and publishes actionable late collisions', function()
    child.lua([[
      clients[buffer] = { client(1, { 'textDocument/references', 'textDocument/codeAction' }) }
      event('LspAttach', buffer, 1)
      owner = function() end
      plugin = function() end
      vim.keymap.set('n', 'gr', owner, { buffer = buffer })
      vim.keymap.set('x', '<leader>ca', plugin, { buffer = buffer })
      event('LspAttach', buffer, 1)
      replacement_preserved = mapping(buffer, 'gr').callback == owner
      event('LspDetach', buffer, 1)
      detach_preserved = mapping(buffer, 'gr').callback == owner
      collisions = M.inspect('diagnostics', 'language.mapping_collision')
      vim.cmd.enew()
      late_buffer = vim.api.nvim_get_current_buf()
      vim.keymap.set('n', 'gr', plugin, { buffer = late_buffer })
      clients[late_buffer] = { client(2, { 'textDocument/references' }) }
      event('LspAttach', late_buffer, 2)
      late_preserved = mapping(late_buffer, 'gr').callback == plugin
      late_collisions = M.inspect('diagnostics', 'language.mapping_collision')
    ]])
    expect.equality(child.lua_get([[replacement_preserved and detach_preserved and late_preserved]]), true)
    expect.equality(child.lua_get([[#collisions]]), 2)
    expect.equality(child.lua_get([[#late_collisions]]), 3)
    expect.equality(
      child.lua_get([[vim.tbl_filter(function(item)
      return item.details.buffer == late_buffer and item.details.mode == 'n'
        and item.details.key == 'gr' and item.details.action == 'language.references'
        and item.repair ~= ''
    end, late_collisions)[1] ~= nil]]),
      true
    )
  end)
  it('reconciles already attached Lua and TypeScript buffers during application', function()
    child.restart({ '--clean', '-u', 'tests/fixtures/language_lifecycle_apply.lua' })
    expect.equality(child.lua_get([[lifecycle_applied.status]]), 'performed')
    for index = 1, 2 do
      expect.equality(
        child.lua_get(([[vim.api.nvim_buf_call(initial_buffers[%d], function()
        return vim.fn.maparg('gr', 'n', false, true).buffer
      end)]]):format(index)),
        1
      )
    end
  end)

  it('releases owned callbacks when a managed buffer is wiped', function()
    child.lua([[
      clients[buffer] = { client(1, { 'textDocument/references' }) }
      event('LspAttach', buffer, 1)
      weak_callback = setmetatable({ mapping(buffer, 'gr').callback }, { __mode = 'v' })
      vim.api.nvim_buf_delete(buffer, { force = true })
      collectgarbage('collect')
      collectgarbage('collect')
      callback_released = weak_callback[1] == nil
      lifecycle_events = vim.api.nvim_get_autocmds({ group = 'plait.language.lifecycle' })
    ]])
    expect.equality(child.lua_get([[callback_released]]), true)
    expect.equality(child.lua_get([[vim.tbl_map(function(item) return item.event end, lifecycle_events)]]), {
      'BufWipeout',
      'LspAttach',
      'LspDetach',
    })
  end)
  it('dispatches gr immediately in a new Lua buffer and retains global defaults outside it', function()
    child.lua([[
      vim.cmd.enew()
      buffer = vim.api.nvim_get_current_buf()
      vim.bo.filetype = 'lua'
      require('plait.state').language_servers = {}
      clients[buffer] = { client(1, { 'textDocument/references' }) }
      event('LspAttach', buffer, 1)
      references_called = 0
      vim.lsp.buf.references = function() references_called = references_called + 1 end
      vim.o.timeoutlen = 10000
    ]])
    child.type_keys('gr')
    child.lua([[vim.wait(1000, function() return references_called == 1 end)]])
    expect.equality(child.lua_get([[references_called]]), 1)
    child.lua([[
      vim.cmd.enew()
      outside = vim.fn.maparg('grr', 'n', false, true)
      outside_gr = vim.fn.maparg('gr', 'n', false, true)
    ]])
    expect.equality(child.lua_get([[outside.buffer]]), 0)
    expect.equality(child.lua_get([[type(outside.callback)]]), 'function')
    expect.equality(child.lua_get([[next(outside_gr)]]), vim.NIL)
  end)
end)
