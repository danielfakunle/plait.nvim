---@class PlaitState
---@field collector PlaitCollector|nil
---@field snapshot table|nil
---@field bootstrap_diagnostics table[]
local state = {
  collector = nil,
  snapshot = nil,
  bootstrap_diagnostics = {},
}

return state
