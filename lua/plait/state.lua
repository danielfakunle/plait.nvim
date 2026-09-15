---@class PlaitState
---@field collector PlaitCollector|nil
---@field snapshot table|nil
---@field bootstrap_diagnostics table[]
---@field bootstrap_initialized boolean
---@field applied_plan_id string|nil
---@field applied_effects table|nil
---@field editor_active boolean
---@field language_active boolean
---@field language_servers table<string, table>
---@field completion_active boolean
---@field formatting_active boolean
---@field formatting_configuration table
---@field formatting_formatters table<string, table>
---@field formatting_by_filetype table<string, string[]>
---@field tooling_active boolean
---@field tool_requirements table<string, table>
---@field operation_diagnostics table[]
---@field package_restart_required table<string, boolean>
---@field package_interrupted table<string, { operation_id?: string, message?: string }>
---@field operations table[]
---@field next_operation_id integer
---@field operation_feedback 'errors'|'all'|'silent'
local state = {
  collector = nil,
  snapshot = nil,
  bootstrap_diagnostics = {},
  bootstrap_initialized = false,
  applied_plan_id = nil,
  applied_effects = nil,
  editor_active = false,
  language_active = false,
  language_servers = {},
  completion_active = false,
  formatting_active = false,
  formatting_configuration = {},
  formatting_formatters = {},
  formatting_by_filetype = {},
  tooling_active = false,
  tool_requirements = {},
  operation_diagnostics = {},
  package_restart_required = {},
  package_interrupted = {},
  operations = {},
  next_operation_id = 0,
  operation_feedback = 'errors',
}

return state
