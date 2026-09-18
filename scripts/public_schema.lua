local authority = require('plait.authority')
local canonical = require('plait.canonical')
local M = {}

--- Reject independently represented version drift before generating any artifact.
function M.check_versions()
  local version = table.concat(vim.fn.readfile('version.txt'), '\n')
  assert(version == authority.compatibility.version, 'version.txt disagrees with the public compatibility version')
  local manifest = '.release-please-manifest.json'
  if vim.fn.filereadable(manifest) == 1 then
    local releases = vim.json.decode(table.concat(vim.fn.readfile(manifest), '\n'))
    assert(releases['.'] == version, 'release manifest disagrees with the public compatibility version')
  end
end

--- Reject extra or missing public exports independently of generated-file drift.
function M.check_exports()
  local public = require('plait')
  for key in pairs(public) do
    assert(vim.tbl_contains(authority.api, key), 'unsupported public export: ' .. key)
  end
  for _, key in ipairs(authority.api) do
    assert(public[key] ~= nil, 'missing public export: ' .. key)
  end
  local seen = {}
  for capability, actions in pairs(public.actions) do
    for name, action in pairs(actions) do
      local operation = capability .. '.' .. name
      assert(type(action) == 'function' and authority.actions[operation], 'unsupported public action: ' .. operation)
      seen[operation] = true
    end
  end
  for operation in pairs(authority.actions) do
    if operation ~= 'apply' and operation ~= 'formatting.on_save' then
      assert(seen[operation], 'missing public action: ' .. operation)
    end
  end
end

--- Return sorted public model keys.
---@param value table
---@return string[]
local function keys(value)
  local result = vim.tbl_keys(value)
  table.sort(result)
  return result
end

--- Render annotations from the same closed records used by consistency checks.
---@param group_name string
---@return string
function M.annotations(group_name)
  local lines = { '-- Generated from lua/plait/authority.lua. Do not edit.' }
  if group_name == 'records' then
    lines[#lines + 1] = ''
    for _, name in ipairs(keys(authority.enums)) do
      local literals = {}
      for _, value in ipairs(authority.enums[name]) do
        literals[#literals + 1] = string.format('%q', value)
      end
      lines[#lines + 1] = '---@alias ' .. name .. ' ' .. table.concat(literals, '|')
    end
    lines[#lines + 1] =
      '---@alias PlaitValue string|boolean|number|PlaitFunction|table<string, PlaitValue>|PlaitValue[]'
    for _, name in ipairs(keys(authority.records)) do
      local record = authority.records[name]
      lines[#lines + 1] = ''
      lines[#lines + 1] = '---@class ' .. name
      for _, field in ipairs(keys(record.fields)) do
        local optional = vim.tbl_contains(record.optional or {}, field) and '?' or ''
        lines[#lines + 1] = '---@field ' .. field .. optional .. ' ' .. record.fields[field]
      end
    end
  end
  for _, group in ipairs(group_name == 'records' and {} or { group_name }) do
    for _, name in ipairs(keys(authority[group])) do
      local entry = authority[group][name]
      local schemas = group == 'actions' and entry or { details = entry }
      for _, status in ipairs(keys(schemas)) do
        local schema = schemas[status]
        if type(schema) == 'table' and schema.fields then
          lines[#lines + 1] = ''
          local class = 'Plait' .. group .. '_' .. name:gsub('[^%w]', '_') .. '_' .. status
          lines[#lines + 1] = '---@class ' .. class
          for _, field in ipairs(keys(schema.fields)) do
            local optional = vim.tbl_contains(schema.optional or {}, field) and '?' or ''
            lines[#lines + 1] = '---@field ' .. field .. optional .. ' ' .. schema.fields[field]
          end
        end
      end
    end
  end
  if group_name == 'actions' then
    lines[#lines + 1] = ''
    lines[#lines + 1] = '---@class PlaitActions'
    for _, operation in ipairs(keys(authority.actions)) do
      local arguments = {}
      for index, kind in ipairs(authority.actions[operation].arguments) do
        arguments[#arguments + 1] = 'arg' .. index .. ': ' .. kind
      end
      lines[#lines + 1] = '---@field '
        .. operation:gsub('%.', '_')
        .. ' fun('
        .. table.concat(arguments, ', ')
        .. '): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult'
    end
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'return {}'
  lines[#lines + 1] = ''
  return table.concat(lines, '\n')
end

--- Render static machine-readable public facts without observing the environment.
---@return string
function M.facts()
  local facts = vim.deepcopy(authority)
  --- Preserve empty schema lists as JSON arrays while leaving empty field maps as objects.
  ---@param value table
  local function arrays(value)
    for key, child in pairs(value) do
      if type(child) == 'table' then
        if key == 'optional' or key == 'arguments' or key == 'unavailable' or key == 'values' then
          canonical.mark_array(child)
        end
        arrays(child)
      end
    end
  end
  arrays(facts)
  return canonical.encode(facts) .. '\n'
end

--- Render compatibility reference facts from the executable manifest.
---@return string
function M.reference()
  local manifest = authority.compatibility
  local lines = {
    '---',
    'title: Public Contract',
    'description: Generated public schemas and compatibility facts.',
    '---',
    '',
    'This reference is generated from the executable public authority.',
    '[Machine-readable public contract](/plait-schema.json) includes all record, declaration, action, reason, and diagnostic schemas.',
    '',
    'Plait version: `' .. manifest.version .. '`.',
    'Neovim: `' .. manifest.neovim.constraint .. '`.',
    'Mason registry: `' .. manifest.registry.release .. '` (`' .. manifest.registry.commit .. '`).',
    '',
    '| Provider | Source | Qualified commit |',
    '| --- | --- | --- |',
  }
  for _, provider in ipairs(manifest.providers) do
    lines[#lines + 1] = '| `' .. provider.identity .. '` | ' .. provider.source .. ' | `' .. provider.commit .. '` |'
  end
  for _, name in ipairs(keys(authority.records)) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = '### ' .. name
    lines[#lines + 1] = ''
    lines[#lines + 1] = '| Field | Type |'
    lines[#lines + 1] = '| --- | --- |'
    for _, field in ipairs(keys(authority.records[name].fields)) do
      lines[#lines + 1] = '| `' .. field .. '` | `' .. authority.records[name].fields[field]:gsub('|', '\\|') .. '` |'
    end
  end
  lines[#lines + 1] = ''
  return table.concat(lines, '\n')
end

return M
