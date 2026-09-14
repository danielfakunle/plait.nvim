local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

--- Return a UTC RFC 3339 timestamp with millisecond precision.
---@return string
local function timestamp()
  local seconds, microseconds = vim.uv.gettimeofday()
  return os.date('!%Y-%m-%dT%H:%M:%S', seconds) .. ('.%03dZ'):format(math.floor(microseconds / 1000))
end

---@class PlaitOperationDefinition
---@field operation string
---@field targets string[]
---@field work fun(done: fun(ok: boolean))
---@field success_details fun(): table
---@field started_details? table
---@field failure_message string
---@field on_success? fun(operation_id: string)
---@field on_failure? fun(operation_id: string, message: string)

--- Accept asynchronous work in the process-lifetime operation ledger.
---@param definition PlaitOperationDefinition
---@return table
function M.start(definition)
  local operation_name = definition.operation
  local targets = vim.deepcopy(definition.targets)
  table.sort(targets)
  local failure_message = definition.failure_message
  state.next_operation_id = state.next_operation_id + 1
  local operation_id = ('op-%08d'):format(state.next_operation_id)
  local record = {
    identity = operation_id,
    operation = operation_name,
    state = 'pending',
    started_at = timestamp(),
    completed_at = vim.NIL,
    targets = vim.deepcopy(targets),
    result = vim.NIL,
    error = vim.NIL,
    diagnostic_codes = {},
  }
  state.operations[#state.operations + 1] = record
  if state.snapshot then state.snapshot.operations = state.operations end

  local completed = false
  local function done(ok)
    if completed then return end
    local details
    if ok then
      local details_ok
      details_ok = pcall(function()
        if definition.on_success then definition.on_success(operation_id) end
        details = vim.deepcopy(definition.success_details())
      end)
      ok = details_ok
    end
    local message = require('plait.text').normalize(failure_message):sub(1, 240)
    if not ok and definition.on_failure then pcall(definition.on_failure, operation_id, message) end
    completed = true
    record.completed_at = timestamp()
    local diagnostic
    if ok then
      record.state = 'succeeded'
      record.result = { status = 'performed', operation = operation_name, details = details }
      record.error = vim.NIL
      record.diagnostic_codes = { 'operation.succeeded' }
      diagnostic = {
        code = 'operation.succeeded',
        severity = 'info',
        summary = 'Operation ' .. operation_id .. ' succeeded.',
        repair = '',
        source = nil,
        related_sources = {},
        details = { operation_id = operation_id, operation = operation_name, targets = vim.deepcopy(targets) },
      }
    else
      record.state = 'failed'
      record.result = vim.NIL
      record.error = { reason = 'execution_failed', message = message }
      record.diagnostic_codes = { 'operation.failed' }
      diagnostic = {
        code = 'operation.failed',
        severity = 'error',
        summary = 'Operation ' .. operation_id .. ' failed.',
        repair = 'Repair the reported target/environment and invoke a new operation.',
        source = nil,
        related_sources = {},
        details = {
          operation_id = operation_id,
          operation = operation_name,
          targets = vim.deepcopy(targets),
          message = message,
        },
      }
    end
    state.operation_diagnostics[#state.operation_diagnostics + 1] = diagnostic
    if state.snapshot then
      state.snapshot.operations = state.operations
      state.snapshot.diagnostics[#state.snapshot.diagnostics + 1] = vim.deepcopy(diagnostic)
      validation.sort_diagnostics(state.snapshot.diagnostics)
    end
    pcall(
      vim.notify,
      ('Plait operation %s %s (%s)'):format(operation_name, ok and 'succeeded' or 'failed', operation_id),
      ok and vim.log.levels.INFO or vim.log.levels.ERROR
    )
  end
  vim.schedule(function()
    local ok = pcall(definition.work, done)
    if not ok then done(false) end
  end)
  return {
    status = 'started',
    operation = operation_name,
    operation_id = operation_id,
    details = vim.deepcopy(definition.started_details or { targets = targets }),
  }
end

return M
