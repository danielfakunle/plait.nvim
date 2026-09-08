local editor = require('plait.editor')
local plan = require('plait.plan')
local snapshot = require('plait.snapshot')
local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

--- Return the closed apply result for an invalid re-resolution.
---@param diagnostics table[]
---@return table
function M.invalid(diagnostics)
  local codes = {}
  for _, diagnostic in ipairs(diagnostics) do
    if not vim.list_contains(codes, diagnostic.code) then codes[#codes + 1] = diagnostic.code end
  end
  snapshot.publish_empty('invalid', diagnostics)
  return {
    status = 'unavailable',
    operation = 'apply',
    reason = 'invalid_plan',
    details = { diagnostic_codes = codes },
  }
end

--- Return a bounded failure message without reflecting provider or environment data.
---@param _ any
---@return string
local function failure_message(_) return 'Managed editor effect failed.' end

--- Publish the diagnostic and error projection for one failed effect.
---@param effect table
---@param failure any
---@param partition table
---@param diagnostics table[]
local function record_failure(effect, failure, partition, diagnostics)
  local details = {
    operation_id = 'apply',
    stage = effect.stage,
    effect = effect.identity,
    capability = effect.responsible_capability,
    provider = effect.provider or vim.NIL,
    completed = vim.deepcopy(partition.completed),
    failed = vim.deepcopy(partition.failed),
    skipped = vim.deepcopy(partition.skipped),
    message = failure_message(failure),
  }
  local diagnostic = {
    code = 'effect.failed',
    severity = 'error',
    summary = 'Effect ' .. effect.identity .. ' failed.',
    repair = 'Repair the named effect/provider, restart, and apply once.',
    source = vim.deepcopy(effect.sources[1]),
    related_sources = {},
    details = details,
  }
  effect.error = {
    code = diagnostic.code,
    summary = diagnostic.summary,
    responsible_capability = effect.responsible_capability,
    provider = effect.provider,
    operation_id = 'apply',
    details = vim.deepcopy(details),
  }
  diagnostics[#diagnostics + 1] = diagnostic
  state.operation_diagnostics[#state.operation_diagnostics + 1] = vim.deepcopy(diagnostic)
  validation.sort_diagnostics(diagnostics)
end

--- Apply every planned editor effect in order and publish the completed snapshot.
---@param effective_plan table
---@param diagnostics table[]
---@param schema table
---@return table
function M.run(effective_plan, diagnostics, schema)
  local configuration
  for _, capability in ipairs(effective_plan.capabilities) do
    if capability.identity == 'editor' then configuration = capability.configuration.values end
  end
  local partition = { completed = {}, failed = {}, skipped = {} }
  local failed_effect
  local failure
  for _, effect in ipairs(effective_plan.effects) do
    if failed_effect then
      effect.state = 'skipped'
      partition.skipped[#partition.skipped + 1] = effect.identity
    else
      local ok
      ok, failure = pcall(editor.apply_effect, effect.identity, configuration)
      if ok then
        effect.state = 'completed'
        partition.completed[#partition.completed + 1] = effect.identity
      else
        failed_effect = effect
        effect.state = 'failed'
        partition.failed[#partition.failed + 1] = effect.identity
      end
    end
  end

  local plan_id = plan.id(effective_plan, schema)
  effective_plan.snapshot_state = failed_effect and 'failed' or 'applied'
  if failed_effect then record_failure(failed_effect, failure, partition, diagnostics) end
  snapshot.publish(effective_plan, diagnostics)
  if configuration and vim.list_contains(partition.completed, 'editor/actions') then
    state.applied_plan_id = plan_id
    state.applied_effects = vim.deepcopy(partition)
    state.editor_active = true
  end
  if failed_effect then
    return {
      status = 'unavailable',
      operation = 'apply',
      reason = 'execution_failed',
      details = { diagnostic_codes = { 'effect.failed' }, plan_id = plan_id, effects = partition },
    }
  end
  return { status = 'performed', operation = 'apply', details = { plan_id = plan_id, effects = partition } }
end

return M
