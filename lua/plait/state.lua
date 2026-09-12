---@class PlaitState
---@field collector PlaitCollector|nil
---@field snapshot table|nil
---@field bootstrap_diagnostics table[]
---@field bootstrap_initialized boolean
---@field applied_plan_id string|nil
---@field applied_effects table|nil
---@field editor_active boolean
---@field language_active boolean
---@field operation_diagnostics table[]
---@field package_restart_required table<string, boolean>
---@field package_interrupted table<string, { operation_id?: string, message?: string }>
---@field operations table[]
---@field next_operation_id integer
local state = {
  collector = nil,
  snapshot = nil,
  bootstrap_diagnostics = {},
  bootstrap_initialized = false,
  applied_plan_id = nil,
  applied_effects = nil,
  editor_active = false,
  language_active = false,
  operation_diagnostics = {},
  package_restart_required = {},
  package_interrupted = {},
  operations = {},
  next_operation_id = 0,
}

return state
