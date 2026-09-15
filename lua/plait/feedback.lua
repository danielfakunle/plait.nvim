local state = require('plait.state')

local M = {}

--- Return whether the configured policy automatically presents an action result.
---@param result table
---@return boolean
function M.present_result(result)
  if state.operation_feedback == 'silent' then return false end
  if state.operation_feedback == 'all' then return true end
  return result.status == 'failed' or result.status == 'unavailable'
end

--- Return whether the configured policy presents an asynchronous completion.
---@param succeeded boolean
---@return boolean
function M.present_completion(succeeded)
  if state.operation_feedback == 'silent' then return false end
  return state.operation_feedback == 'all' or not succeeded
end

return M
