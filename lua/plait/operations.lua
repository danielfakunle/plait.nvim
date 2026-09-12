local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

--- Return a UTC RFC 3339 timestamp with millisecond precision.
---@return string
local function timestamp()
  local seconds, microseconds = vim.uv.gettimeofday()
  return os.date('!%Y-%m-%dT%H:%M:%S', seconds) .. ('.%03dZ'):format(math.floor(microseconds / 1000))
end

--- Accept asynchronous work in the process-lifetime operation ledger.
---@param operation_name string
---@param targets string[]
---@param work fun(done: fun(ok: boolean, message?: string))
---@param success_details fun(): table
---@param started_details? table
---@return table
function M.start(operation_name, targets, work, success_details, started_details)
  table.sort(targets)
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
  local function done(ok, message)
    if completed then return end
    completed = true
    record.completed_at = timestamp()
    local diagnostic
    if ok then
      record.state = 'succeeded'
      record.result = { status = 'performed', operation = operation_name, details = vim.deepcopy(success_details()) }
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
      message = require('plait.text').normalize(message or 'Operation failed.'):sub(1, 240)
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
    vim.notify(
      ('Plait operation %s %s (%s)'):format(operation_name, ok and 'succeeded' or 'failed', operation_id),
      ok and vim.log.levels.INFO or vim.log.levels.ERROR
    )
  end
  vim.schedule(function()
    local ok, error_message = pcall(work, done)
    if not ok then done(false, error_message) end
  end)
  return {
    status = 'started',
    operation = operation_name,
    operation_id = operation_id,
    details = vim.deepcopy(started_details or { targets = targets }),
  }
end

return M
