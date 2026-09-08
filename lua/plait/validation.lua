local canonical = require('plait.canonical')
local text = require('plait.text')

local M = {}

--- Describe a value without publishing unsafe contents.
---@param value any
---@return string
local function observed(value)
  local value_type = type(value)
  if value_type == 'string' then
    if not text.valid_utf8(value) then return 'invalid UTF-8 string' end
    return canonical.encode(value)
  end
  if value_type == 'number' and (value ~= value or value == math.huge or value == -math.huge) then
    return 'non-finite number'
  end
  if value_type == 'table' and getmetatable(value) ~= nil then return 'table with metatable' end
  return value_type
end

--- Describe the accepted form of a schema node.
---@param node table
---@return string
local function expected(node)
  if node.type == 'map' then return 'a plain map' end
  if node.type == 'boolean' then return 'a boolean' end
  if node.type == 'integer' then return ('an integer from %d through %d'):format(node.minimum, node.maximum) end
  if node.type == 'mapping' then return 'a non-empty UTF-8 key string or false' end
  local values = {}
  for index, value in ipairs(node.values) do
    values[index] = canonical.encode(value)
  end
  return 'one of ' .. table.concat(values, ', ')
end

--- Build a closed source-aware config.invalid diagnostic.
---@param path string
---@param expected_value string
---@param value any
---@param declaration_source table
---@return table
local function diagnostic(path, expected_value, value, declaration_source)
  path = text.normalize(path)
  local diagnostic_source = vim.deepcopy(declaration_source)
  diagnostic_source.file = text.normalize(diagnostic_source.file)
  diagnostic_source.path = path
  return {
    code = 'config.invalid',
    severity = 'error',
    summary = text.truncate_sentence('Invalid value at ' .. path .. '.', 160),
    repair = 'Use one value/form named by `expected`.',
    source = diagnostic_source,
    related_sources = {},
    details = {
      path = path,
      expected = expected_value,
      observed = observed(value),
    },
  }
end

--- Resolve defaults recursively from the executable schema.
---@param node table
---@return any
local function default_value(node)
  if node.type ~= 'map' then return node.default end
  local result = {}
  for name, child in pairs(node.fields) do
    result[name] = default_value(child)
  end
  return result
end

--- Validate and normalize one schema node.
---@param node table
---@param value any
---@param path string
---@param declaration_source table
---@param diagnostics table[]
---@param ancestors table<table, boolean>
---@return any
local function validate_node(node, value, path, declaration_source, diagnostics, ancestors)
  if value == nil then return default_value(node) end
  if node.type == 'map' then
    if type(value) ~= 'table' or getmetatable(value) ~= nil then
      diagnostics[#diagnostics + 1] = diagnostic(path, expected(node), value, declaration_source)
      return default_value(node)
    end
    if ancestors[value] then
      diagnostics[#diagnostics + 1] = diagnostic(path, 'an acyclic plain map', value, declaration_source)
      diagnostics[#diagnostics].details.observed = 'cyclic table'
      return default_value(node)
    end
    ancestors[value] = true
    local result = {}
    for key, child_value in pairs(value) do
      if type(key) ~= 'string' then
        diagnostics[#diagnostics + 1] = diagnostic(path, expected(node), value, declaration_source)
        diagnostics[#diagnostics].details.observed = 'map with non-string key'
      elseif not node.fields[key] then
        diagnostics[#diagnostics + 1] =
          diagnostic(path .. '.' .. key, 'a declared field', child_value, declaration_source)
      end
    end
    for name, child in pairs(node.fields) do
      result[name] =
        validate_node(child, rawget(value, name), path .. '.' .. name, declaration_source, diagnostics, ancestors)
    end
    ancestors[value] = nil
    return result
  end
  if node.type == 'boolean' then
    if type(value) == 'boolean' then return value end
  elseif node.type == 'integer' then
    if
      type(value) == 'number'
      and value == value
      and value ~= math.huge
      and value ~= -math.huge
      and value % 1 == 0
      and value >= node.minimum
      and value <= node.maximum
    then
      return value
    end
  elseif node.type == 'mapping' then
    if value == false then return value end
    if type(value) == 'string' and value ~= '' and text.valid_utf8(value) then return value end
  elseif node.type == 'enum' and type(value) == 'string' and text.valid_utf8(value) then
    for _, allowed in ipairs(node.values) do
      if value == allowed then return value end
    end
  end
  diagnostics[#diagnostics + 1] = diagnostic(path, expected(node), value, declaration_source)
  return default_value(node)
end

--- Validate the dense built-in module selection array.
---@param selections any
---@param declaration_sources table[]
---@param diagnostics table[]
---@return boolean
local function validate_selections(selections, declaration_sources, diagnostics)
  local declaration_source = declaration_sources[1]
  if type(selections) ~= 'table' or getmetatable(selections) ~= nil then
    diagnostics[#diagnostics + 1] =
      diagnostic('select', 'a dense one-based array of module selections', selections, declaration_source)
    return false
  end
  local count = 0
  local maximum = 0
  for key in pairs(selections) do
    count = count + 1
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      diagnostics[#diagnostics + 1] =
        diagnostic('select', 'a dense one-based array of module selections', selections, declaration_source)
      diagnostics[#diagnostics].details.observed = 'mixed or sparse table'
      return false
    end
    maximum = math.max(maximum, key)
  end
  if maximum ~= count then
    diagnostics[#diagnostics + 1] =
      diagnostic('select', 'a dense one-based array of module selections', selections, declaration_source)
    diagnostics[#diagnostics].details.observed = 'mixed or sparse table'
    return false
  end
  local selected = false
  for index = 1, count do
    if selections[index] == 'editor' then
      selected = true
    else
      diagnostics[#diagnostics + 1] =
        diagnostic('select[' .. index .. ']', 'one of "editor"', selections[index], declaration_sources[index])
    end
  end
  if not selected and #diagnostics == 0 then
    diagnostics[#diagnostics + 1] = diagnostic('select', 'an array containing "editor"', selections, declaration_source)
    diagnostics[#diagnostics].details.observed = 'empty array'
  end
  return selected
end

--- Sort diagnostics using the canonical public ordering.
---@param diagnostics table[]
function M.sort_diagnostics(diagnostics)
  local severity = { error = 1, warning = 2, info = 3 }
  table.sort(diagnostics, function(left, right)
    local left_source = left.source or { file = '', line = 0, path = '' }
    local right_source = right.source or { file = '', line = 0, path = '' }
    local left_fields = {
      severity[left.severity],
      left.code,
      left.source and 1 or 0,
      left_source.file,
      left_source.line,
      left_source.path,
      canonical.encode(left.details),
    }
    local right_fields = {
      severity[right.severity],
      right.code,
      right.source and 1 or 0,
      right_source.file,
      right_source.line,
      right_source.path,
      canonical.encode(right.details),
    }
    for index, left_value in ipairs(left_fields) do
      if left_value ~= right_fields[index] then return left_value < right_fields[index] end
    end
    return false
  end)
end

--- Validate collected editor declarations without applying managed effects.
---@param selections any
---@param selection_sources table[]
---@param declaration any
---@param configuration_source table
---@param editor_schema table
---@return table|nil, table[]
function M.validate(selections, selection_sources, declaration, configuration_source, editor_schema)
  local diagnostics = {}
  local selected = validate_selections(selections, selection_sources, diagnostics)
  local root_schema = { type = 'map', fields = { editor = editor_schema } }
  local collected_declaration = declaration == nil and {} or declaration
  local configuration =
    validate_node(root_schema, collected_declaration, 'configure', configuration_source, diagnostics, {})
  M.sort_diagnostics(diagnostics)
  if #diagnostics > 0 or not selected then return nil, diagnostics end
  return configuration.editor, diagnostics
end

return M
