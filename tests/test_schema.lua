local MiniTest = require('mini.test')
local helpers = dofile('tests/helpers.lua')
local child = helpers.new_clean_neovim()
local T = MiniTest.new_set({ hooks = { pre_case = child.setup, post_once = child.stop } })

T['public reference facts are executable and generated'] = function()
  child.lua([[facts = vim.json.decode(table.concat(vim.fn.readfile('site/public/plait-schema.json'), '\n'))]])
  MiniTest.expect.equality(child.lua_get([[facts.records.PlaitPosition.fields.character]]), 'integer')
  MiniTest.expect.equality(child.lua_get([[facts.compatibility.version]]), '0.1.0-dev')
  MiniTest.expect.equality(child.lua_get([[facts.records.PlaitModuleRecord.fields.identity]]), 'string')
end

T['closed results reject unsupported fields and result forms'] = function()
  child.lua([[contract = require('plait.public_contract')]])
  MiniTest.expect.equality(
    child.lua_get(
      [[contract.action_result({ status = 'performed', operation = 'editor.save', details = { buffer = 1, alias = true } })]]
    ),
    false
  )
  MiniTest.expect.equality(
    child.lua_get(
      [[contract.action_result({ status = 'failed', operation = 'editor.save', reason = 'execution_failed', details = {} })]]
    ),
    false
  )
  MiniTest.expect.equality(
    child.lua_get(
      [[contract.action_result({ status = 'performed', operation = 'editor.save', details = { buffer = 1 } })]]
    ),
    true
  )
end

T['public rendering rejects aliases and extra result fields'] = function()
  MiniTest.expect.equality(
    child.lua_get(
      [[pcall(M.render, { status = 'performed', operation = 'editor.save', details = { buffer = 1 }, alias = true })]]
    ),
    false
  )
end

T['unavailable reasons belong to their operation'] = function()
  MiniTest.expect.equality(
    child.lua_get(
      [[pcall(M.render, { status = 'unavailable', operation = 'editor.save', reason = 'no_candidate', details = { buffer = 1 } })]]
    ),
    false
  )
end

T['local contribution declarations are closed'] = function()
  child.lua([[local config = M.config()
    config:select({ 'language', 'tooling', M.module({ name = 'local.lang.python', provides = { 'local.lang.python' }, requires = { 'language', 'tooling' }, contribute = { language = { servers = { basedpyright = { filetypes = { 'python' }, tool = 'basedpyright', alias = true } } } } }) })
    schema_validation = config:validate()
  ]])
  MiniTest.expect.equality(child.lua_get([[schema_validation.status]]), 'invalid')
end

T['public rendering rejects mixed sparse and cyclic provider values'] = function()
  child.lua([[local config = M.config(); config:select({ 'editor' }); schema_result = config:validate()
    schema_result.plan.capabilities[1].configuration.providers = { { identity = 'vim.lsp', target = 'global', value = {}, sources = {}, opaque = true, revision_coupled = true } }
  ]])
  for _, expression in ipairs({ [[{ [2] = 'sparse' }]], [[{ [1] = 'array', hidden = 'map' }]] }) do
    child.lua(([[schema_result.plan.capabilities[1].configuration.providers[1].value = %s]]):format(expression))
    MiniTest.expect.equality(child.lua_get([[pcall(M.render, schema_result)]]), false)
  end
  child.lua(
    [[local cyclic = {}; cyclic.self = cyclic; schema_result.plan.capabilities[1].configuration.providers[1].value = cyclic]]
  )
  MiniTest.expect.equality(child.lua_get([[pcall(M.render, schema_result)]]), false)
end

return T
