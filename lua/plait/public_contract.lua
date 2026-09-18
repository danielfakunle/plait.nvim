local authority = require('plait.authority')
local text = require('plait.text')
local M = {}
local matches

--- Check complete effective capability values against the configuration authority.
---@param node table
---@param value any
---@return boolean
local function configuration(node, value)
  if node.type == 'map' then
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    for key in pairs(value) do
      if not node.fields[key] then return false end
    end
    for key, child in pairs(node.fields) do
      if not configuration(child, value[key]) then return false end
    end
    return true
  end
  if node.type == 'enum' then return vim.tbl_contains(node.values, value) end
  if node.type == 'integer' then
    return type(value) == 'number' and value % 1 == 0 and value >= node.minimum and value <= node.maximum
  end
  if node.type == 'mapping' then
    return value == false or (type(value) == 'string' and value ~= '' and text.valid_utf8(value))
  end
  if node.type == 'array' then
    if type(value) ~= 'table' or not vim.islist(value) then return false end
    for _, item in ipairs(value) do
      if not configuration(node.item, item) then return false end
    end
    return true
  end
  return type(value) == node.type
end

--- Check a closed record against the executable public contract.
---@param schema table
---@param value any
---@return boolean
function M.record(schema, value)
  if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
  for key in pairs(value) do
    if not schema.fields[key] then return false end
  end
  for key, kind in pairs(schema.fields) do
    local optional = vim.tbl_contains(schema.optional or {}, key)
    if value[key] == nil and not optional then return false end
    if value[key] ~= nil or not optional then
      if not matches(kind, value[key]) then return false end
    end
  end
  for key, minimum in pairs(schema.minimum or {}) do
    if value[key] ~= nil and value[key] < minimum then return false end
  end
  for _, key in ipairs(schema.nonempty or {}) do
    if value[key] == '' or (type(value[key]) == 'table' and #value[key] == 0) then return false end
  end
  for _, key in ipairs(schema.unique or {}) do
    local seen = {}
    for _, item in ipairs(value[key] or {}) do
      if item == '' or seen[item] then return false end
      seen[item] = true
    end
  end
  return true
end

--- Match a public type expression, including nested records and dense arrays.
---@param kind string
---@param value any
---@param ancestors? table<table, boolean>
---@return boolean
matches = function(kind, value, ancestors)
  local map_item = kind:match('^table<string, (.+)>$')
  if map_item then
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    for key, item in pairs(value) do
      if type(key) ~= 'string' or not matches(map_item, item) then return false end
    end
    return true
  end
  if kind:find('|', 1, true) then
    for item in kind:gmatch('[^|]+') do
      if matches(item, value) then return true end
    end
    return false
  end
  if kind == 'nil' then return value == nil or value == vim.NIL end
  local item = kind:match('^(.+)%[%]$')
  if item then
    if type(value) ~= 'table' or getmetatable(value) ~= nil or not vim.islist(value) then return false end
    for _, child in ipairs(value) do
      if not matches(item, child) then return false end
    end
    return true
  end
  if kind == 'string' then return type(value) == 'string' and text.valid_utf8(value) end
  if kind == 'integer' then
    return type(value) == 'number' and value ~= math.huge and value ~= -math.huge and value % 1 == 0
  end
  if kind == 'boolean' then return type(value) == 'boolean' end
  if kind == 'table' then return type(value) == 'table' and getmetatable(value) == nil end
  if kind == 'PlaitValue' then
    local value_type = type(value)
    if value_type == 'string' then return text.valid_utf8(value) end
    if value_type == 'number' then return value == value and value ~= math.huge and value ~= -math.huge end
    if value_type == 'boolean' then return true end
    if value_type ~= 'table' or getmetatable(value) ~= nil then return false end
    ancestors = ancestors or {}
    if ancestors[value] then return false end
    local numeric, strings = false, false
    for key in pairs(value) do
      numeric = numeric or type(key) == 'number'
      strings = strings or type(key) == 'string'
      if type(key) ~= 'number' and type(key) ~= 'string' then return false end
      if type(key) == 'string' and not text.valid_utf8(key) then return false end
    end
    if numeric and (strings or not vim.islist(value)) then return false end
    ancestors[value] = true
    for _, child in pairs(value) do
      if not matches('PlaitValue', child, ancestors) then
        ancestors[value] = nil
        return false
      end
    end
    ancestors[value] = nil
    return true
  end
  if kind:sub(1, 1) == '"' then return value == kind:sub(2, -2) end
  if authority.enums[kind] then return vim.tbl_contains(authority.enums[kind], value) end
  if authority.records[kind] then
    if not M.record(authority.records[kind], value) then return false end
    if kind == 'PlaitCapabilityRecord' then
      local schema = authority.configuration[value.identity]
      if schema then return configuration(schema, value.configuration.values) end
      return next(value.configuration.values) == nil
    end
    if kind == 'PlaitRange' then
      return value.end_.line > value.start.line
        or (value.end_.line == value.start.line and value.end_.character >= value.start.character)
    end
    return true
  end
  return false
end

--- Validate one public record by its canonical name.
---@param name string
---@param value any
---@return boolean
function M.matches(name, value)
  local ok, result = pcall(matches, name, value)
  if not ok or not result then return false end
  return true
end

--- Validate the operation-specific closed action result and details.
---@param value any
---@return boolean
function M.action_result(value)
  if type(value) ~= 'table' then return false end
  local names =
    { performed = 'PlaitPerformedResult', started = 'PlaitStartedResult', unavailable = 'PlaitUnavailableResult' }
  if not names[value.status] or not M.matches(names[value.status], value) then return false end
  local action = authority.actions[value.operation]
  if not action then return false end
  if value.status == 'unavailable' and not vim.tbl_contains(action.unavailable, value.reason) then return false end
  local schema = value.status == 'unavailable' and authority.reasons[value.reason] or action[value.status]
  if not schema or not M.record(schema, value.details) then return false end
  if value.details.range and value.details.range ~= vim.NIL and not M.matches('PlaitRange', value.details.range) then
    return false
  end
  if value.reason and value.reason:match('^tool_') then
    return value.operation:match('^language%.') ~= nil and action.started ~= nil
  end
  return true
end

--- Validate the diagnostic catalog's exact detail fields and severity.
---@param value any
---@return boolean
function M.diagnostic(value)
  if not M.matches('PlaitDiagnostic', value) then return false end
  local schema = authority.diagnostics[value.code]
  return schema ~= nil and schema.severity == value.severity and M.record(schema, value.details)
end

return M
