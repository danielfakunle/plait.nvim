local compatibility = require('plait.compatibility')
local operations = require('plait.operations')
local state = require('plait.state')
local effect_record = require('plait.effects')

local M = {}

local registry_source = 'github:mason-org/mason-registry@' .. compatibility.registry.release

--- Build one closed tooling effect record.
---@param identity string
---@param stage integer
---@param provider string|nil
---@param dependencies string[]
---@param sources table[]
---@return table
local function effect(identity, stage, provider, dependencies, sources)
  return effect_record.new('tooling', identity, stage, provider, dependencies, sources)
end

--- Declare the complete effect family owned by the tooling capability.
---@param configuration table
---@param sources table[]
---@return table[]
function M.effects(configuration, sources)
  local effects = {
    effect('tooling/package/mason.nvim', 2, 'vim.pack', {}, sources),
    effect('tooling/provider-setup', 3, 'mason.nvim', { 'tooling/package/mason.nvim' }, sources),
    effect('tooling/tool-resolution', 3, nil, { 'tooling/package/mason.nvim' }, sources),
    effect('tooling/actions', 4, 'mason.nvim', { 'tooling/tool-resolution' }, sources),
  }
  if configuration.check_on_startup then
    effects[#effects + 1] = effect('tooling/startup-check', 5, nil, { 'tooling/tool-resolution' }, sources)
  end
  return effects
end

--- Return an unavailable action result.
---@param operation string
---@param reason string
---@param details table
---@return table
local function unavailable(operation, reason, details)
  return { status = 'unavailable', operation = operation, reason = reason, details = vim.deepcopy(details) }
end

--- Verify that tooling has a valid active snapshot.
---@param operation string
---@return table|nil, table|nil
local function current(operation)
  if not state.snapshot then return nil, unavailable(operation, 'not_configured', {}) end
  if state.snapshot.snapshot_state == 'invalid' then
    local codes = {}
    for _, item in ipairs(state.snapshot.diagnostics) do
      if not vim.list_contains(codes, item.code) then codes[#codes + 1] = item.code end
    end
    return nil, unavailable(operation, 'invalid_plan', { diagnostic_codes = codes })
  end
  local active = false
  for _, capability in ipairs(state.snapshot.capabilities) do
    if capability.identity == 'tooling' then active = true end
  end
  if not active then return nil, unavailable(operation, 'capability_inactive', { capability = 'tooling' }) end
  return state.snapshot
end

--- Project tool records into canonical identity and state details.
---@param records table[]
---@return string[], table<string, string>
local function states(records)
  local identities, result = {}, {}
  for _, record in ipairs(records) do
    identities[#identities + 1], result[record.identity] = record.identity, record.state
  end
  table.sort(identities)
  return identities, result
end

--- Re-observe the current effective plan without refreshing registries or mutating tools.
---@return table
local function refresh()
  if state.collector then
    -- Tool actions are explicit observation boundaries after the environment may have changed.
    state.collector:_refresh()
  end
  return assert(state.snapshot)
end

--- Check all effective external tools without mutation.
---@return table
function M.check()
  local snapshot, failure = current('tooling.check')
  if not snapshot then return assert(failure) end
  snapshot = refresh()
  local identities, observed = states(snapshot.tools)
  return { status = 'performed', operation = 'tooling.check', details = { tools = identities, states = observed } }
end

--- Find one effective tool record or raise public misuse.
---@param snapshot table
---@param identity any
---@param operation string
---@return table
local function require_tool(snapshot, identity, operation)
  if type(identity) ~= 'string' or identity == '' then
    error('plait: ' .. operation .. ' requires an effective tool identity', 3)
  end
  for _, record in ipairs(snapshot.tools) do
    if record.identity == identity then return record end
  end
  error('plait: ' .. operation .. ' requires an effective tool identity', 3)
end

--- Check local prerequisites for a Mason mutation.
---@param records table[]
---@return boolean
local function prerequisites(records)
  if vim.fn.executable('curl') ~= 1 and vim.fn.executable('wget') ~= 1 then return false end
  for _, record in ipairs(records) do
    if
      record.identity == 'lua-language-server' and (vim.fn.executable('tar') ~= 1 or vim.fn.executable('gzip') ~= 1)
    then
      return false
    end
    if record.identity == 'stylua' and vim.fn.executable('unzip') ~= 1 then return false end
    if record.identity == 'oxfmt' and (vim.fn.executable('node') ~= 1 or vim.fn.executable('npm') ~= 1) then
      return false
    end
  end
  return vim.fn.filewritable(vim.fn.stdpath('data')) == 2
end

--- Resolve a Mason registry package name for an effective requirement.
---@param identity string
---@return string|nil
local function mason_name(identity)
  local requirement = state.tool_requirements[identity]
  return requirement and requirement.mason or nil
end

--- Return canonical diagnostic evidence for unavailable mutation targets.
---@param operation string
---@param records table[]
---@return table
local function environment_unavailable(operation, records)
  local targets, codes = {}, {}
  for _, record in ipairs(records) do
    targets[record.identity] = true
  end
  for _, item in ipairs(state.snapshot and state.snapshot.diagnostics or {}) do
    if item.details and targets[item.details.tool] and not vim.list_contains(codes, item.code) then
      codes[#codes + 1] = item.code
    end
  end
  return unavailable(operation, 'environment_unavailable', { diagnostic_codes = codes })
end

--- Start a pinned Mason installation operation.
---@param operation string
---@param records table[]
---@return table
local function mutate(operation, records)
  local targets = vim.tbl_map(function(record) return record.identity end, records)
  if not prerequisites(records) then return environment_unavailable(operation, records) end
  local terminal_states = {}
  return operations.start({
    operation = operation,
    targets = targets,
    work = function(done)
      local ok, registry = pcall(require, 'mason-registry')
      if not ok then
        done(false)
        return
      end
      local remaining, failed = #records, false
      local function finish(okay)
        failed = failed or not okay
        remaining = remaining - 1
        if remaining == 0 then
          if failed then
            done(false)
            return
          end
          local observed = refresh()
          local satisfied = true
          for _, record in ipairs(observed.tools) do
            if vim.list_contains(targets, record.identity) then
              terminal_states[record.identity] = record.state
              if record.state ~= 'satisfied' then satisfied = false end
            end
          end
          done(satisfied)
        end
      end
      for _, record in ipairs(records) do
        local package_ok, package = pcall(registry.get_package, mason_name(record.identity))
        if not package_ok or not package then
          finish(false)
        else
          local install_ok, receipt = pcall(package.install, package, {})
          if not install_ok or not receipt or type(receipt.once) ~= 'function' then
            finish(false)
          else
            receipt:once('closed', function()
              local callback_ok = pcall(function() finish(package:is_installed()) end)
              if not callback_ok then done(false) end
            end)
          end
        end
      end
    end,
    success_details = function() return { targets = vim.deepcopy(targets), states = vim.deepcopy(terminal_states) } end,
    failure_message = 'Mason tool mutation failed.',
  })
end

--- Ensure every unmet mutable effective tool is installed.
---@return table
function M.ensure()
  local snapshot, failure = current('tooling.ensure')
  if not snapshot then return assert(failure) end
  local targets = {}
  for _, record in ipairs(snapshot.tools) do
    if record.state ~= 'satisfied' then
      if record.ownership == 'project' then return environment_unavailable('tooling.ensure', { record }) end
      targets[#targets + 1] = record
    end
  end
  if #targets == 0 then
    local ids, observed = states(snapshot.tools)
    return { status = 'performed', operation = 'tooling.ensure', details = { targets = ids, states = observed } }
  end
  return mutate('tooling.ensure', targets)
end

--- Install one effective Mason-owned or hybrid tool.
---@param identity string
---@return table
function M.install(identity)
  local snapshot, failure = current('tooling.install')
  if not snapshot then return assert(failure) end
  local record = require_tool(snapshot, identity, 'tooling.install')
  if record.ownership == 'project' then return environment_unavailable('tooling.install', { record }) end
  if record.state == 'satisfied' then
    return {
      status = 'performed',
      operation = 'tooling.install',
      details = { targets = { identity }, states = { [identity] = record.state } },
    }
  end
  return mutate('tooling.install', { record })
end

--- Update one or all mutable effective tools while retaining exact pins.
---@param identity? string
---@return table
function M.update(identity)
  local snapshot, failure = current('tooling.update')
  if not snapshot then return assert(failure) end
  local selected = {}
  if identity ~= nil then
    selected[1] = require_tool(snapshot, identity, 'tooling.update')
  else
    selected = snapshot.tools
  end
  local mutable = {}
  for _, record in ipairs(selected) do
    if record.ownership == 'project' then return environment_unavailable('tooling.update', { record }) end
    if record.state ~= 'satisfied' then mutable[#mutable + 1] = record end
  end
  if #mutable == 0 then
    local ids, observed = states(selected)
    return { status = 'performed', operation = 'tooling.update', details = { targets = ids, states = observed } }
  end
  return mutate('tooling.update', mutable)
end

--- Apply one tooling lifecycle effect.
---@param identity string
---@param configuration table
---@param effective_plan? table
function M.apply_effect(identity, configuration, effective_plan)
  if identity == 'tooling/provider-setup' then
    local setup = { PATH = 'skip', registries = { registry_source }, firewall = { auto_managed = false } }
    for _, provider in ipairs(configuration.providers or {}) do
      if provider.identity == 'mason.nvim' and provider.target == 'setup' then
        setup = vim.tbl_deep_extend('force', setup, provider.value)
      end
    end
    setup.PATH = 'skip'
    setup.registries = { registry_source }
    setup.firewall = setup.firewall or {}
    setup.firewall.auto_managed = false
    require('mason').setup(setup)
  elseif identity == 'tooling/actions' then
    state.tooling_active = true
  elseif identity == 'tooling/tool-resolution' then
    if not effective_plan then refresh() end
  elseif identity == 'tooling/startup-check' and configuration.check_on_startup then
    if not effective_plan then M.check() end
  end
end

--- Tooling effects do not own collision-bearing Neovim identities.
---@return table[]
function M.preflight_effect() return {} end

M.actions = { check = M.check, ensure = M.ensure, install = M.install, update = M.update }
M.integration = {
  implementation = M,
  failure_message = 'Managed tooling effect failed.',
  activation_effect = 'tooling/actions',
  activate = function() state.tooling_active = true end,
}

return M
