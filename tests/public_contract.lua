--- Assert that every published fixture record satisfies the executable contract.
---@param child table
local function check(child)
  local failures = child.lua_get([[ (function()
    local generated = vim.system({ vim.v.progpath, '--headless', '--clean', '-u', 'NONE', '-l', 'scripts/generate_schema.lua', '--', '--check' }):wait()
    assert(generated.code == 0, generated.stderr)
    local plait = require('plait')
    local contract = require('plait.public_contract')
    local facts = vim.json.decode(table.concat(vim.fn.readfile('site/public/plait-schema.json'), '\n'))
    assert(vim.deep_equal(facts.enums, dofile('tests/fixtures/schema_coverage.lua')), 'canonical fixture enum coverage drifted')
    for name, alternatives in pairs(dofile('tests/fixtures/schema_coverage.lua')) do
      for _, alternative in ipairs(alternatives) do
        assert(contract.matches(name, alternative), name .. ' rejects a supported fixture schema alternative')
      end
      assert(not contract.matches(name, '__unsupported__'), name .. ' accepts an unsupported alternative')
    end
    local sections = {
      modules = 'PlaitModuleRecord', capabilities = 'PlaitCapabilityRecord', effects = 'PlaitEffectRecord',
      packages = 'PlaitPackageRecord', tools = 'PlaitToolRecord', operations = 'PlaitOperationRecord',
      language_servers = 'PlaitLanguageServerRecord', diagnostics = 'PlaitDiagnostic',
    }
    local failures = {}
    local inspected = 0
    for section, name in pairs(sections) do
      local ok, records = pcall(plait.inspect, section)
      if ok then
        inspected = inspected + 1
        for _, record in ipairs(records) do
          local valid
          if section == 'diagnostics' then valid = contract.diagnostic(record) else valid = contract.matches(name, record) end
          if not valid then failures[#failures + 1] = section .. ':' .. (record.identity or record.code) end
          local extra = vim.deepcopy(record)
          extra.__unsupported_public_field = true
          assert(not contract.matches(name, extra), 'fixture record accepts an extra public field')
          for field in pairs(record) do
            local schema = require('plait.authority').records[name]
            if not vim.tbl_contains(schema.optional or {}, field) then
              local missing = vim.deepcopy(record)
              missing[field] = nil
              assert(not contract.matches(name, missing), 'fixture record accepts missing field ' .. name .. '.' .. field)
            end
          end
          if section == 'operations' and type(record.result) == 'table' and not contract.action_result(record.result) then
            failures[#failures + 1] = 'operation result:' .. record.identity
          end
        end
      end
    end
    if require('plait.state').snapshot then assert(inspected == vim.tbl_count(sections), 'a public inspection section failed') end
    for _, fixture in ipairs({ _G.daily or {}, _G.extension or {}, _G.lua_quickstart or {} }) do
      if fixture.validation and not contract.matches(fixture.validation.status == 'valid' and 'PlaitValidResult' or 'PlaitInvalidResult', fixture.validation) then
        failures[#failures + 1] = 'validation result'
      end
      if fixture.result and not contract.action_result(fixture.result) then failures[#failures + 1] = 'apply result' end
    end
    table.sort(failures)
    return failures
  end)() ]])
  MiniTest.expect.equality(failures, {})
end

return check
