local presentation = require('plait.presentation')

local M = {}

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
      if value ~= nil and value ~= vim.NIL then
        local rendered = presentation.value(value)
        local line = ('    %s: %s'):format(field[1], rendered)
        if #line <= 88 then
          lines[#lines + 1] = line
        else
          lines[#lines + 1] = ('    %s:'):format(field[1])
          local separator = rendered:find('; ', 1, true) and '; ' or ', '
          for part in vim.gsplit(rendered, separator, { plain = true }) do
            lines[#lines + 1] = '      - ' .. part
          end
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
