local M = {}

local function_tokens = setmetatable({}, { __mode = 'k' })
local semantic_arrays = setmetatable({}, { __mode = 'k' })
local next_function_token = 0

local array_fields = {
  actions = true,
  affected_operations = true,
  capabilities = true,
  candidates = true,
  contributions = true,
  degradation_reasons = true,
  dependencies = true,
  dependents = true,
  diagnostics = true,
  effects = true,
  modules = true,
  operations = true,
  ordering_edges = true,
  packages = true,
  providers = true,
  provides = true,
  related_sources = true,
  responsible_capabilities = true,
  requires = true,
  selection_sources = true,
  sources = true,
  tools = true,
}

--- Return the stable process-local token for a function object.
---@param value function
---@return string
local function function_token(value)
  local token = function_tokens[value]
  if token then return token end
  next_function_token = next_function_token + 1
  token = ('fn-%08d'):format(next_function_token)
  function_tokens[value] = token
  return token
end

--- Frame one semantic scalar so unlike Lua types cannot collide.
---@param tag string
---@param value string
---@return string
local function frame(tag, value) return tag .. #value .. ':' .. value end

--- Encode a semantic value recursively with schema-aware array handling.
---@param value any
---@param declared_array? boolean
---@param ancestors? table<table, boolean>
---@param allow_functions? boolean
---@return string
local function encode(value, declared_array, ancestors, allow_functions)
  local value_type = type(value)
  if allow_functions and value_type == 'nil' then return 'n' end
  if value_type == 'nil' then return 'null' end
  if allow_functions and value_type == 'boolean' then return value and 'b1' or 'b0' end
  if value_type == 'boolean' then return tostring(value) end
  if value_type == 'number' then
    if value ~= value or value == math.huge or value == -math.huge then error('cannot encode a non-finite number') end
    local encoded = value == 0 and '0' or vim.json.encode(value)
    return allow_functions and frame('d', encoded) or encoded
  end
  if value_type == 'string' then return allow_functions and frame('s', value) or vim.json.encode(value) end
  if value_type == 'function' then
    if not allow_functions then error('cannot encode a value of type function') end
    return frame('f', function_token(value))
  end
  if value_type ~= 'table' then error('cannot encode a value of type ' .. value_type) end
  if getmetatable(value) ~= nil then error('cannot encode a table with a metatable') end

  ancestors = ancestors or {}
  if ancestors[value] then error('cannot encode a cyclic table') end
  ancestors[value] = true

  local count = 0
  local maximum = 0
  local array = true
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      array = false
    else
      maximum = math.max(maximum, key)
    end
  end

  if array and ((count > 0 and maximum == count) or declared_array or semantic_arrays[value]) then
    local values = {}
    for index = 1, count do
      values[index] = encode(value[index], nil, ancestors, allow_functions)
    end
    ancestors[value] = nil
    if allow_functions then return frame('a', table.concat(values)) end
    return '[' .. table.concat(values, ',') .. ']'
  end

  if array and count > 0 then error('cannot encode a sparse array') end

  local keys = vim.tbl_keys(value)
  for _, key in ipairs(keys) do
    if type(key) ~= 'string' then error('cannot encode a map with non-string keys') end
  end
  table.sort(keys)
  local fields = {}
  for index, key in ipairs(keys) do
    local encoded_key = allow_functions and frame('k', key) or vim.json.encode(key) .. ':'
    fields[index] = encoded_key .. encode(value[key], array_fields[key], ancestors, allow_functions)
  end
  ancestors[value] = nil
  if allow_functions then return frame('m', table.concat(fields)) end
  return '{' .. table.concat(fields, ',') .. '}'
end

--- Encode a JSON-like value with bytewise-sorted map keys.
---@param value any
---@return string
function M.encode(value) return encode(value) end

--- Encode a canonical semantic plan, assigning stable tokens to functions.
---@param value table
---@return string
function M.encode_plan(value) return encode(value, nil, nil, true) end

--- Mark an internal table as a semantically declared array.
---@param value table
---@return table
function M.mark_array(value)
  semantic_arrays[value] = true
  return value
end

--- Encode a value known by its schema to be an array, including an empty array.
---@param value any[]
---@return string
function M.encode_array(value)
  if type(value) ~= 'table' or getmetatable(value) ~= nil then error('cannot encode a non-array value') end
  local values = {}
  for index, item in ipairs(value) do
    values[index] = encode(item, nil, { [value] = true })
  end
  for key in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or key > #values then error('cannot encode a sparse array') end
  end
  return '[' .. table.concat(values, ',') .. ']'
end

return M
