local presentation = require('plait.presentation')

local M = {}

--- Return whether an optional report value has no visible content.
---@param value any
---@return boolean
local function empty(value) return value == '' or (type(value) == 'table' and next(value) == nil) end

--- Append one recursively structured report value.
---@param lines string[]
---@param value any
---@param indent integer
local function append_value(lines, value, indent)
  if value == nil or value == vim.NIL then
    lines[#lines + 1] = string.rep(' ', indent) .. 'none'
  elseif type(value) ~= 'table' then
    lines[#lines + 1] = string.rep(' ', indent) .. tostring(value)
  elseif vim.islist(value) then
    for _, item in ipairs(value) do
      if type(item) == 'table' then
        lines[#lines + 1] = string.rep(' ', indent) .. '-'
        append_value(lines, item, indent + 2)
      else
        lines[#lines + 1] = string.rep(' ', indent) .. '- ' .. presentation.value(item)
      end
    end
  else
    local keys = vim.tbl_keys(value)
    table.sort(keys)
    for _, key in ipairs(keys) do
      local child = value[key]
      if not empty(child) then
        if type(child) == 'table' then
          lines[#lines + 1] = string.rep(' ', indent) .. key .. ':'
          append_value(lines, child, indent + 2)
        else
          lines[#lines + 1] = string.rep(' ', indent) .. key .. ': ' .. presentation.value(child)
        end
      end
    end
  end
end

local definitions = {
  modules = {
    heading = 'Modules',
    empty = 'No selected modules.',
    fields = {
      { 'Provides', 'provides' },
      { 'Requires', 'requires' },
      { 'Ordering', 'ordering_edges' },
      { 'Contributions', 'contributions' },
      { 'Selected at', 'selection_sources' },
    },
  },
  capabilities = {
    heading = 'Capabilities',
    empty = 'No active capabilities.',
    fields = {
      { 'Integration', 'responsible_integration' },
      { 'Providers', 'providers' },
      { 'Dependents', 'dependents' },
      { 'Actions', 'actions' },
      { 'Degradation', 'degradation_reasons' },
      { 'Configuration', 'configuration' },
      { 'Contributions', 'contributions' },
    },
  },
  effects = {
    heading = 'Managed effects',
    empty = 'No managed effects.',
    fields = {
      { 'Capability', 'responsible_capability' },
      { 'Provider', 'provider' },
      { 'Stage', 'stage' },
      { 'Dependencies', 'dependencies' },
      { 'Error', 'error' },
      { 'Sources', 'sources' },
    },
  },
  packages = {
    heading = 'Packages',
    empty = 'No package requirements.',
    fields = {
      { 'Source', 'source' },
      { 'Required commit', 'required_commit' },
      { 'Active source', 'active_source' },
      { 'Active commit', 'active_commit' },
      { 'Capabilities', 'responsible_capabilities' },
      { 'Repair', 'repair' },
    },
  },
  tools = {
    heading = 'Tools',
    empty = 'No tool requirements.',
    fields = {
      { 'Executable', 'executable' },
      { 'Version constraint', 'constraint' },
      { 'Ownership', 'ownership' },
      { 'Resolved path', 'path' },
      { 'Resolved source', 'source' },
      { 'Resolved version', 'version' },
      { 'Operations', 'affected_operations' },
      { 'Repair', 'repair' },
    },
  },
  diagnostics = {
    heading = 'Diagnostics',
    empty = 'No diagnostics.',
    fields = {
      { 'Summary', 'summary' },
      { 'Repair', 'repair' },
      { 'Source', 'source' },
      { 'Affected', 'details' },
    },
  },
  operations = {
    heading = 'Operations',
    empty = 'No operations.',
    fields = {
      { 'Operation', 'operation' },
      { 'Targets', 'targets' },
      { 'Started', 'started_at' },
      { 'Completed', 'completed_at' },
      { 'Result', 'result' },
      { 'Error', 'error' },
      { 'Diagnostics', 'diagnostic_codes' },
    },
  },
}

--- Render one purpose-specific inspection section.
---@param section string
---@param records table|table[]
---@return string[]
function M.section(section, records)
  local definition = assert(definitions[section])
  local items = records
  if records.identity or records.code then items = { records } end
  local lines = { definition.heading }
  if #items == 0 then
    lines[#lines + 1] = '  ' .. definition.empty
    return lines
  end
  for _, item in ipairs(items) do
    local identity = item.identity or item.code
    local state = item.state or item.severity or 'reported'
    lines[#lines + 1] = ('  [%s] %s'):format(tostring(state):upper(), identity)
    for _, field in ipairs(definition.fields) do
      local value = item[field[2]]
      if value ~= nil and value ~= vim.NIL and not empty(value) then
        if type(value) == 'table' then
          lines[#lines + 1] = ('    %s:'):format(field[1])
          append_value(lines, value, 6)
        else
          lines[#lines + 1] = ('    %s: %s'):format(field[1], presentation.value(value))
        end
      end
    end
  end
  return lines
end

--- Render a complete inspection report in canonical section order.
---@param selected table<string, table|table[]>
---@param sections string[]
---@return string[]
function M.render(selected, sections)
  local lines = { 'Plait inspection', '' }
  for index, section in ipairs(sections) do
    vim.list_extend(lines, M.section(section, selected[section]))
    if index < #sections then lines[#lines + 1] = '' end
  end
  return lines
end

return M
