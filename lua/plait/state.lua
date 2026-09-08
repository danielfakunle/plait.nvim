---@class PlaitState
---@field collector PlaitCollector|nil
---@field snapshot table|nil
---@field bootstrap_diagnostics table[]
---@field bootstrap_initialized boolean
local state = {
  collector = nil,
  snapshot = nil,
  bootstrap_diagnostics = {},
  bootstrap_initialized = false,
}

return state
