local M = {}

local array_fields = {
  actions = true,
  capabilities = true,
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
  requires = true,
  selection_sources = true,
  sources = true,
  tools = true,
}

--- Encode a JSON-like value recursively with schema-aware array handling.
---@param value any
---@param declared_array? boolean
---@return string
local function encode(value, declared_array)
  local value_type = type(value)
  if value_type == 'nil' then return 'null' end
  if value_type == 'boolean' or value_type == 'number' then return tostring(value) end
  if value_type == 'string' then return vim.json.encode(value) end

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

  if array and ((count > 0 and maximum == count) or declared_array) then
    local values = {}
    for index = 1, count do
      values[index] = encode(value[index])
    end
    return '[' .. table.concat(values, ',') .. ']'
  end

  local keys = vim.tbl_keys(value)
  table.sort(keys)
  local fields = {}
  for index, key in ipairs(keys) do
    fields[index] = vim.json.encode(key) .. ':' .. encode(value[key], array_fields[key])
  end
  return '{' .. table.concat(fields, ',') .. '}'
end

--- Encode a JSON-like value with bytewise-sorted map keys.
---@param value any
---@return string
function M.encode(value) return encode(value) end

--- Encode a value known by its schema to be an array, including an empty array.
---@param value any[]
---@return string
function M.encode_array(value)
  local values = {}
  for index, item in ipairs(value) do
    values[index] = encode(item)
  end
  return '[' .. table.concat(values, ',') .. ']'
end

return M
