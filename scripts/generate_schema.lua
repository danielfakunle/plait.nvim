vim.opt.runtimepath:prepend(vim.fn.getcwd())

local schema = require('plait.schema')

--- Return deterministic keys for generated output.
---@param value table
---@return any[]
local function sorted_keys(value)
  local keys = vim.tbl_keys(value)
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  return keys
end

--- Serialize schema metadata as deterministic Lua source.
---@param value any
---@param indentation integer
---@return string
local function serialize(value, indentation)
  local value_type = type(value)
  if value_type == 'string' then return "'" .. value:gsub('\\', '\\\\'):gsub("'", "\\'") .. "'" end
  if value_type ~= 'table' then return tostring(value) end
  local lines = { '{' }
  for _, key in ipairs(sorted_keys(value)) do
    local rendered_key = type(key) == 'string' and key:match('^[%a_][%w_]*$') and key or '[' .. serialize(key, 0) .. ']'
    lines[#lines + 1] = string.rep(' ', indentation + 2)
      .. rendered_key
      .. ' = '
      .. serialize(value[key], indentation + 2)
      .. ','
  end
  lines[#lines + 1] = string.rep(' ', indentation) .. '}'
  return table.concat(lines, '\n')
end

--- Render enum values as a LuaLS literal union.
---@param values string[]
---@return string
local function quoted_union(values)
  local rendered = {}
  for index, value in ipairs(values) do
    rendered[index] = string.format('%q', value)
  end
  return table.concat(rendered, '|')
end

--- Render the LuaLS type represented by a schema node.
---@param node table
---@return string
local function annotation_type(node)
  if node.type == 'enum' then return quoted_union(node.values) end
  if node.type == 'integer' then return 'integer' end
  if node.type == 'boolean' then return 'boolean' end
  if node.type == 'mapping' then return 'string|false' end
  if node.type == 'array' then return '(' .. annotation_type(node.item) .. ')[]' end
  local fields = {}
  for _, name in ipairs(sorted_keys(node.fields)) do
    fields[#fields + 1] = name .. '?: ' .. annotation_type(node.fields[name])
  end
  return '{ ' .. table.concat(fields, ', ') .. ' }'
end

--- Generate runtime validation metadata and LuaLS annotations.
---@return string
local function runtime_artifact()
  local lines = {
    '-- Generated from lua/plait/schema.lua. Do not edit.',
    '',
  }
  for _, capability in ipairs(sorted_keys(schema)) do
    local class_name = 'Plait' .. capability:gsub('^%l', string.upper) .. 'Configuration'
    lines[#lines + 1] = '---@class ' .. class_name
    for _, name in ipairs(sorted_keys(schema[capability].fields)) do
      lines[#lines + 1] = '---@field ' .. name .. '? ' .. annotation_type(schema[capability].fields[name])
    end
    lines[#lines + 1] = ''
  end
  lines[#lines + 1] = 'return ' .. serialize(schema, 0)
  lines[#lines + 1] = ''
  return table.concat(lines, '\n')
end

--- Render a schema node for the generated reference table.
---@param node table
---@return string
local function describe(node)
  if node.type == 'enum' then return table.concat(node.values, ' \\| ') end
  if node.type == 'integer' then return ('integer %d..%d'):format(node.minimum, node.maximum) end
  if node.type == 'mapping' then return 'non-empty key string \\| false' end
  if node.type == 'array' then return 'dense array of ' .. describe(node.item) end
  return node.type
end

--- Render a schema default as inline code.
---@param value any
---@return string
local function display_default(value)
  if type(value) == 'string' then return '`' .. value .. '`' end
  if type(value) == 'table' then
    local items = {}
    for index, item in ipairs(value) do
      items[index] = type(item) == 'string' and string.format('%q', item) or tostring(item)
    end
    return '`{ ' .. table.concat(items, ', ') .. ' }`'
  end
  return '`' .. tostring(value) .. '`'
end

--- Collect leaf configuration points for reference generation.
---@param node table
---@param prefix string
---@param rows table[]
local function reference_rows(node, prefix, rows)
  for _, name in ipairs(sorted_keys(node.fields)) do
    local child = node.fields[name]
    local path = prefix .. name
    if child.type == 'map' then
      reference_rows(child, path .. '.', rows)
    else
      rows[#rows + 1] = { '`' .. path .. '`', '`' .. describe(child) .. '`', display_default(child.default) }
    end
  end
end

--- Render aligned Markdown table rows.
---@param rows table[]
---@return string
local function markdown_table(rows)
  local all_rows = { { 'Configuration point', 'Accepted value', 'Default' } }
  vim.list_extend(all_rows, rows)
  local widths = { 3, 3, 3 }
  for _, row in ipairs(all_rows) do
    for column, value in ipairs(row) do
      widths[column] = math.max(widths[column], #value)
    end
  end
  local lines = {}
  ---@param row string[]
  ---@return string
  local function line(row)
    return ('| %-' .. widths[1] .. 's | %-' .. widths[2] .. 's | %-' .. widths[3] .. 's |'):format(unpack(row))
  end
  lines[#lines + 1] = line(all_rows[1])
  lines[#lines + 1] = '| '
    .. string.rep('-', widths[1])
    .. ' | '
    .. string.rep('-', widths[2])
    .. ' | '
    .. string.rep('-', widths[3])
    .. ' |'
  for _, row in ipairs(rows) do
    lines[#lines + 1] = line(row)
  end
  return table.concat(lines, '\n')
end

--- Generate public capability-configuration schema reference facts.
---@return string
local function reference_artifact()
  local rows = {}
  for _, capability in ipairs(sorted_keys(schema)) do
    reference_rows(schema[capability], capability .. '.', rows)
  end
  return table.concat({
    '---',
    'title: Capability Configuration Schema',
    'description: Generated facts for supported capability configuration.',
    '---',
    '',
    markdown_table(rows),
    '',
  }, '\n')
end

local artifacts = {
  ['lua/plait/schema_generated.lua'] = runtime_artifact(),
  ['site/content/reference/capability-configuration-schema.mdx'] = reference_artifact(),
}

local check = vim.tbl_contains(vim.v.argv, '--check')
local stale = {}
for path, content in pairs(artifacts) do
  local file = io.open(path, 'r')
  local existing = file and file:read('*a') or nil
  if file then file:close() end
  if check then
    if existing ~= content then stale[#stale + 1] = path end
  else
    local output = assert(io.open(path, 'w'))
    output:write(content)
    output:close()
  end
end

if #stale > 0 then
  table.sort(stale)
  error('generated schema artifacts are stale: ' .. table.concat(stale, ', '), 0)
end
