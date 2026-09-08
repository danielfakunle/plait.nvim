---@class PlaitState
---@field collector PlaitCollector|nil
---@field snapshot table|nil
---@field bootstrap_diagnostics table[]
---@field bootstrap_initialized boolean
---@field applied_plan_id string|nil
---@field applied_effects table|nil
---@field editor_active boolean
---@field operation_diagnostics table[]
local state = {
  collector = nil,
  snapshot = nil,
  bootstrap_diagnostics = {},
  bootstrap_initialized = false,
  applied_plan_id = nil,
  applied_effects = nil,
  editor_active = false,
  operation_diagnostics = {},
}

return state
