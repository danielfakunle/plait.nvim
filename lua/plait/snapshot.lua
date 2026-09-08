local state = require('plait.state')

local M = {}

--- Build the common closed snapshot shape.
---@param snapshot_state string
---@param effective_plan table
---@param diagnostics table[]
---@return table
local function build(snapshot_state, effective_plan, diagnostics)
  return {
    snapshot_state = snapshot_state,
    modules = effective_plan.modules,
    capabilities = effective_plan.capabilities,
    effects = effective_plan.effects,
    packages = effective_plan.packages,
    tools = effective_plan.tools,
    diagnostics = diagnostics,
    operations = {},
  }
end

--- Publish a completed effective-plan snapshot.
---@param effective_plan table
---@param diagnostics table[]
function M.publish(effective_plan, diagnostics)
  state.snapshot = vim.deepcopy(build(effective_plan.snapshot_state, effective_plan, diagnostics))
end

--- Publish a completed snapshot with no valid effective plan.
---@param snapshot_state "invalid"|"unavailable"
---@param diagnostics table[]
function M.publish_empty(snapshot_state, diagnostics)
  state.snapshot = vim.deepcopy(build(snapshot_state, {
    modules = {},
    capabilities = {},
    effects = {},
    packages = {},
    tools = {},
  }, diagnostics))
end

return M
