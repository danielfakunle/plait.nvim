local presentation = require('plait.presentation')

local M = {}

--- Return whether an optional report value has no visible content.
---@param value any
---@return boolean
local function empty(value) return value == '' or (type(value) == 'table' and next(value) == nil) end

local append_value

--- Append one map, optionally attaching its first field to a list bullet.
---@param lines string[]
---@param value table
---@param indent integer
---@param bullet? boolean
local function append_map(lines, value, indent, bullet)
  local keys = vim.tbl_keys(value)
  table.sort(keys)
  local first = bullet
  for _, key in ipairs(keys) do
    local child = value[key]
    if not empty(child) then
      local prefix = first and '- ' or ''
      local line_indent = first and indent or indent + (bullet and 2 or 0)
      if type(child) == 'table' then
        lines[#lines + 1] = string.rep(' ', line_indent) .. prefix .. key .. ':'
        append_value(lines, child, line_indent + 2)
      else
        lines[#lines + 1] = string.rep(' ', line_indent) .. prefix .. key .. ': ' .. presentation.value(child)
      end
      first = false
    end
  end
end

--- Append one recursively structured report value.
---@param lines string[]
---@param value any
---@param indent integer
append_value = function(lines, value, indent)
  if value == nil or value == vim.NIL then
    lines[#lines + 1] = string.rep(' ', indent) .. 'none'
  elseif type(value) ~= 'table' then
    lines[#lines + 1] = string.rep(' ', indent) .. tostring(value)
  elseif vim.islist(value) then
    for _, item in ipairs(value) do
      if type(item) == 'table' then
        append_map(lines, item, indent, true)
      else
        lines[#lines + 1] = string.rep(' ', indent) .. '- ' .. presentation.value(item)
      end
    end
  else
    append_map(lines, value, indent)
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
      { 'Problems', 'degradation_details' },
      { 'Formatter chains', 'formatter_chains' },
      { 'LSP fallback', 'lsp_fallback' },
      { 'Configuration', 'configuration' },
      { 'Overrides', 'overrides' },
      { 'Contributions', 'contributions' },
      { 'Contribution history', 'contribution_history' },
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
  language_servers = {
    heading = 'Language servers (current buffer)',
    empty = 'No managed language servers for this buffer.',
    fields = {
      { 'Tool state', 'tool_state' },
      { 'Buffer', 'buffer' },
      { 'Workspace root', 'workspace_root' },
      { 'Note', 'note' },
      { 'Repair', 'repair' },
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
      { 'Runtime', 'runtime' },
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
---@param verbose? boolean
---@return string[]
function M.section(section, records, verbose)
  local definition = assert(definitions[section])
  local items = records
  if records.identity or records.code then items = { records } end
  local lines = { definition.heading }
  if section == 'capabilities' then
    lines[#lines + 1] =
      '  Configuration-wide health (completed snapshot); use language_servers for current-buffer readiness.'
  end
  if #items == 0 then
    lines[#lines + 1] = '  ' .. definition.empty
    return lines
  end
  for _, item in ipairs(items) do
    local identity = item.identity or item.code
    local state = item.state or item.severity or 'reported'
    lines[#lines + 1] = ('  [%s] %s'):format(tostring(state):upper(), identity)
    for _, field in ipairs(definition.fields) do
      ---@type any
      local value = item[field[2]]
      if section == 'capabilities' and not verbose then
        if field[2] == 'configuration' then
          value = { values = value and value.values, providers = value and value.providers }
          if value.providers then
            value.providers = vim.tbl_map(
              function(provider)
                return { identity = provider.identity, target = provider.target, value = provider.value }
              end,
              value.providers
            )
          end
        elseif field[2] == 'degradation_reasons' and item.degradation_details then
          value = vim.tbl_filter(function(code)
            return not vim.iter(item.degradation_details):any(function(problem) return problem.code == code end)
          end, value or {})
        elseif field[2] == 'degradation_details' then
          value = vim.tbl_map(
            function(problem)
              return {
                tool = problem.tool,
                filetypes = problem.filetypes,
                summary = problem.summary,
                Repair = problem.repair,
              }
            end,
            value or {}
          )
        elseif field[2] == 'contributions' or field[2] == 'contribution_history' then
          value = nil
        end
      end
      if field[2] == 'formatter_chains' and value and not verbose then
        value = vim.tbl_map(
          function(chain)
            return ('%s: %s [%s]; %s; %s'):format(
              chain.filetype,
              presentation.value(chain.chain),
              chain.state,
              chain.declaration,
              chain.reason
            )
          end,
          value
        )
      end
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
---@param verbose? boolean
---@return string[]
function M.render(selected, sections, verbose)
  local lines = { 'Plait inspection', '' }
  for index, section in ipairs(sections) do
    vim.list_extend(lines, M.section(section, selected[section], verbose))
    if index < #sections then lines[#lines + 1] = '' end
  end
  return lines
end

return M
