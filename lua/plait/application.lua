local editor = require('plait.editor')
local language = require('plait.language')
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

--- Publish a valid but inapplicable plan without performing managed effects.
---@param effective_plan table
---@param diagnostics table[]
---@param reason string
---@param diagnostic_codes? string[]
---@return table
function M.unavailable(effective_plan, diagnostics, reason, diagnostic_codes)
  effective_plan.snapshot_state = 'unavailable'
  snapshot.publish(effective_plan, diagnostics)
  local details = {}
  if diagnostic_codes then
    details.diagnostic_codes = vim.deepcopy(diagnostic_codes)
  else
    details.packages = {}
    details.states = {}
    for _, package in ipairs(effective_plan.packages) do
      details.packages[#details.packages + 1] = package.identity
      details.states[package.identity] = package.state
    end
  end
  return { status = 'unavailable', operation = 'apply', reason = reason, details = details }
end

--- Return a bounded failure message without reflecting provider or environment data.
---@param capability string
---@param _ any
---@return string
local function failure_message(capability, _)
  if capability == 'editor' then return 'Managed editor effect failed.' end
  return 'Managed language effect failed.'
end

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
    message = failure_message(effect.responsible_capability, failure),
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

--- Return the capability configuration for one effective plan.
---@param effective_plan table
---@param identity string
---@return table|nil
local function capability_configuration(effective_plan, identity)
  for _, capability in ipairs(effective_plan.capabilities) do
    if capability.identity == identity then return capability.configuration.values end
  end
end

--- Preflight every externally-owned identity before any managed effect is applied.
---@param effective_plan table
---@return table[]
function M.preflight(effective_plan)
  local diagnostics = {}
  for _, effect in ipairs(effective_plan.effects) do
    local configuration = capability_configuration(effective_plan, effect.responsible_capability)
    local integration = ({ editor = editor, language = language })[effect.responsible_capability]
    if integration and configuration then
      local collisions = integration.preflight_effect(effect.identity, configuration)
      for _, collision in ipairs(collisions) do
        diagnostics[#diagnostics + 1] = {
          code = 'effect.collision',
          severity = 'error',
          summary = 'Managed identity ' .. collision.identity .. ' already exists.',
          repair = 'Remove or rename the external effect before apply.',
          source = vim.deepcopy(effect.sources[1]),
          related_sources = {},
          details = {
            effect = effect.identity,
            identity = collision.identity,
            observed_owner = collision.observed_owner,
          },
        }
      end
    end
  end
  validation.sort_diagnostics(diagnostics)
  return diagnostics
end

--- Order effects by strict stage barriers and dependency topology.
---@param effects table[]
---@return table[]
local function ordered_effects(effects)
  local result = {}
  local by_identity = {}
  local stages = {}
  local emitted = {}
  for _, effect in ipairs(effects) do
    by_identity[effect.identity] = effect
    stages[effect.stage] = stages[effect.stage] or {}
    stages[effect.stage][#stages[effect.stage] + 1] = effect
  end
  for stage = 1, 5 do
    local pending = stages[stage] or {}
    while #pending > 0 do
      local candidates = {}
      for _, effect in ipairs(pending) do
        local ready = true
        for _, dependency in ipairs(effect.dependencies) do
          if by_identity[dependency] and not emitted[dependency] then ready = false end
        end
        if ready then candidates[#candidates + 1] = effect end
      end
      table.sort(candidates, function(left, right) return left.identity < right.identity end)
      local next_effect = candidates[1]
      if not next_effect then error('plait: effective plan has cyclic effect dependencies') end
      emitted[next_effect.identity] = true
      result[#result + 1] = next_effect
      for index, effect in ipairs(pending) do
        if effect == next_effect then
          table.remove(pending, index)
          break
        end
      end
    end
  end
  return result
end

--- Apply every planned managed effect in order and publish the completed snapshot.
---@param effective_plan table
---@param diagnostics table[]
---@param schema table
---@return table
function M.run(effective_plan, diagnostics, schema)
  local editor_configuration = capability_configuration(effective_plan, 'editor')
  local language_configuration = capability_configuration(effective_plan, 'language')
  local partition = { completed = {}, failed = {}, skipped = {} }
  local failed_effect
  local failure
  for _, effect in ipairs(ordered_effects(effective_plan.effects)) do
    if failed_effect then
      effect.state = 'skipped'
      partition.skipped[#partition.skipped + 1] = effect.identity
    else
      local ok
      local integration = effect.responsible_capability == 'language' and language or editor
      local configuration = effect.responsible_capability == 'language' and language_configuration
        or editor_configuration
      ok, failure = pcall(integration.apply_effect, effect.identity, configuration)
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
  if editor_configuration and vim.list_contains(partition.completed, 'editor/actions') then
    state.applied_plan_id = plan_id
    state.applied_effects = vim.deepcopy(partition)
    state.editor_active = true
  end
  if language_configuration and vim.list_contains(partition.completed, 'language/actions-and-mappings') then
    state.language_active = true
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
