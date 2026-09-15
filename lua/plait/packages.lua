local compatibility = require('plait.compatibility')
local operations = require('plait.operations')
local state_store = require('plait.state')

local M = {}

local states = {
  partial_unknown = {
    priority = 1,
    repair = 'Run `:Plait packages sync!`, inspect, then restart.',
    summary = 'Package state is partially unknown.',
  },
  source_collision = {
    priority = 2,
    repair = 'Migrate/remove the conflicting owner package, then restart.',
    summary = 'Package %s has a source collision.',
    apply_reason = 'package_source_collision',
  },
  drifted = {
    priority = 3,
    repair = 'Run package sync, then restart.',
    summary = 'Package %s has drifted.',
    apply_reason = 'package_drifted',
  },
  restart_required = {
    priority = 4,
    repair = 'Restart Neovim.',
    diagnostic_repair = 'Restart Neovim before apply.',
    summary = 'Package changes require restart.',
  },
  absent = {
    priority = 5,
    repair = 'Consent to install during legal interactive apply, or sync then restart.',
    diagnostic_repair = 'Run package sync with consent, then restart.',
    summary = 'Package %s is absent.',
    apply_reason = 'package_absent',
  },
  satisfied = { priority = 6, repair = '' },
}

local function directory(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'directory'
end

local function command_line(arguments)
  local ok, process = pcall(vim.system, arguments, { text = true })
  if not ok then return nil end
  local result = process:wait(2000)
  if result.code ~= 0 then return nil end
  return (result.stdout or ''):match('([^\r\n]+)')
end

local function checkout(identity)
  local matches = {}
  for _, root in ipairs(vim.opt.packpath:get()) do
    vim.list_extend(matches, vim.fn.globpath(root, 'pack/*/opt/' .. identity, false, true))
    vim.list_extend(matches, vim.fn.globpath(root, 'pack/*/start/' .. identity, false, true))
  end
  table.sort(matches)
  if #matches > 1 then return nil, 'duplicate_metadata' end
  if not matches[1] or not directory(matches[1]) then return nil end
  local path = vim.fs.normalize(matches[1])
  local source = command_line({ 'git', '-C', path, 'remote', 'get-url', 'origin' })
  local commit = command_line({ 'git', '-C', path, 'rev-parse', 'HEAD' })
  if not source or not commit then return { present = true }, 'malformed_metadata' end
  return { present = true, source = source, commit = commit }
end

local function lock_entries()
  local path = vim.fn.stdpath('config') .. '/nvim-pack-lock.json'
  local file = io.open(path, 'r')
  if not file then return {} end
  local content = file:read('*a')
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= 'table' then return { __malformed = true } end
  if type(decoded.plugins) ~= 'table' then return { __malformed = true } end
  return decoded.plugins
end

local function lock_entry(entries, identity)
  if entries.__malformed then return nil, 'malformed_metadata' end
  local value = entries[identity]
  if not value then return nil end
  if type(value) ~= 'table' then return { present = true }, 'malformed_metadata' end
  local sources = {}
  for _, field in ipairs({ 'source', 'src', 'url' }) do
    if value[field] ~= nil then sources[#sources + 1] = value[field] end
  end
  local commits = {}
  for _, field in ipairs({ 'commit', 'rev', 'revision' }) do
    if value[field] ~= nil then commits[#commits + 1] = value[field] end
  end
  for _, source in ipairs(sources) do
    if source ~= sources[1] then return { present = true }, 'internal_source_mismatch' end
  end
  for _, commit in ipairs(commits) do
    if commit ~= commits[1] then return { present = true }, 'internal_revision_mismatch' end
  end
  local source = sources[1]
  local commit = commits[1]
  if type(source) ~= 'string' or type(commit) ~= 'string' then return { present = true }, 'malformed_metadata' end
  return { present = true, source = source, commit = commit }
end

local function diagnostic(record)
  if record.state == 'satisfied' then return nil end
  local descriptor = states[record.state]
  local code = 'package.' .. record.state
  local details
  if record.state == 'absent' then
    details =
      { package = record.identity, source = record.source, commit = record.required_commit, interactive = false }
  elseif record.state == 'drifted' then
    details =
      { package = record.identity, required = record.required_commit, observed = record.active_commit or 'unknown' }
  elseif record.state == 'source_collision' then
    details = { package = record.identity, required = record.source, observed = record.active_source or 'unknown' }
  elseif record.state == 'restart_required' then
    details = { packages = { record.identity } }
  else
    local interrupted = state_store.package_interrupted[record.identity]
    details = {
      packages = { record.identity },
      inconsistency = record.inconsistency,
      message = interrupted and interrupted.message or 'Package metadata is inconsistent.',
    }
    if interrupted and interrupted.operation_id then details.operation_id = interrupted.operation_id end
  end
  local source = vim.deepcopy(record.sources[1])
  if record.state == 'partial_unknown' or record.state == 'restart_required' then source = nil end
  return {
    code = code,
    severity = 'error',
    summary = descriptor.summary:format(record.identity),
    repair = descriptor.diagnostic_repair or descriptor.repair,
    source = source,
    related_sources = {},
    details = details,
  }
end

local function observe(requirement, sources, locks)
  local checkout_record, checkout_problem = checkout(requirement.identity)
  local lock_record, lock_problem = lock_entry(locks, requirement.identity)
  local state, inconsistency
  if state_store.package_restart_required[requirement.identity] then
    state = 'restart_required'
  elseif state_store.package_interrupted[requirement.identity] then
    state, inconsistency = 'partial_unknown', 'interrupted_mutation'
  elseif checkout_problem or lock_problem then
    state, inconsistency = 'partial_unknown', checkout_problem or lock_problem
  elseif not checkout_record and not lock_record then
    state = 'absent'
  elseif not checkout_record then
    state, inconsistency = 'partial_unknown', 'lock_without_checkout'
  elseif not lock_record then
    state, inconsistency = 'partial_unknown', 'checkout_without_lock'
  elseif
    checkout_record.source ~= requirement.source
    or lock_record.source ~= requirement.source
    or checkout_record.source ~= lock_record.source
  then
    state = 'source_collision'
  elseif
    checkout_record.commit ~= requirement.commit
    or lock_record.commit ~= requirement.commit
    or checkout_record.commit ~= lock_record.commit
  then
    state = 'drifted'
  else
    state = 'satisfied'
  end
  return {
    identity = requirement.identity,
    source = requirement.source,
    required_commit = requirement.commit,
    active_source = checkout_record and checkout_record.source or vim.NIL,
    active_commit = checkout_record and checkout_record.commit or vim.NIL,
    state = state,
    inconsistency = inconsistency or vim.NIL,
    responsible_capabilities = vim.deepcopy(requirement.capabilities),
    sources = vim.deepcopy(sources),
    repair = states[state].repair,
  }
end

--- Activate exact provider requirements in one native package call and verify them.
---@param records table[]
---@return boolean, string|nil
local function activate(records)
  if #records == 0 then return true end
  local specs = {}
  for _, record in ipairs(records) do
    specs[#specs + 1] = { name = record.identity, src = record.source, version = record.required_commit }
  end
  -- Plait has already obtained consent for this complete operation. Passing it
  -- through prevents vim.pack from asking the owner a second time.
  local ok = pcall(vim.pack.add, specs, { load = false, confirm = false })
  if not ok then return false, 'Provider package activation failed.' end
  local locks = lock_entries()
  for _, record in ipairs(records) do
    local observed = observe({
      identity = record.identity,
      source = record.source,
      commit = record.required_commit,
      capabilities = record.responsible_capabilities,
    }, record.sources, locks)
    if observed.state ~= 'satisfied' then return false, 'Provider package verification failed.' end
  end
  return true
end

local function coalesce_requirements()
  local by_identity = {}
  for _, requirement in ipairs(compatibility.providers) do
    local current = by_identity[requirement.identity]
    if current then
      if current.source ~= requirement.source or current.commit ~= requirement.commit then
        error('plait: compatibility manifest has conflicting package requirement for ' .. requirement.identity)
      end
      for _, capability in ipairs(requirement.capabilities) do
        if not vim.list_contains(current.capabilities, capability) then
          current.capabilities[#current.capabilities + 1] = capability
        end
      end
      table.sort(current.capabilities)
    else
      by_identity[requirement.identity] = vim.deepcopy(requirement)
    end
  end
  local result = vim.tbl_values(by_identity)
  table.sort(result, function(left, right) return left.identity < right.identity end)
  return result
end

--- Resolve and observe exact provider requirements for active capabilities.
---@param resolution table
---@return table[], table[]
function M.resolve(resolution)
  local active = {}
  local capability_sources = {}
  local module_sources = {}
  for _, module in ipairs(resolution.modules) do
    module_sources[module.identity] = module.selection_sources
  end
  for _, capability in ipairs(resolution.capabilities) do
    active[capability.identity] = true
    capability_sources[capability.identity] = module_sources[capability.activator]
  end
  local locks = lock_entries()
  local records, diagnostics = {}, {}
  for _, requirement in ipairs(coalesce_requirements()) do
    local sources = {}
    local responsible = {}
    for _, capability in ipairs(requirement.capabilities) do
      if active[capability] then
        responsible[#responsible + 1] = capability
        vim.list_extend(sources, vim.deepcopy(capability_sources[capability] or {}))
      end
    end
    if #responsible > 0 then
      local copy = vim.deepcopy(requirement)
      copy.capabilities = responsible
      local record = observe(copy, sources, locks)
      records[#records + 1] = record
      local item = diagnostic(record)
      if item then diagnostics[#diagnostics + 1] = item end
    end
  end
  table.sort(records, function(left, right) return left.identity < right.identity end)
  return records, diagnostics
end

--- Return the highest-priority aggregate package state.
---@param records table[]
---@return string
function M.aggregate(records)
  local result = 'satisfied'
  for _, record in ipairs(records) do
    if states[record.state].priority < states[result].priority then result = record.state end
  end
  return result
end

--- Translate a package state to its unavailable apply reason.
---@param package_state string
---@return string
function M.apply_reason(package_state) return states[package_state].apply_reason or package_state end

--- Record that package mutation completed and requires a new process.
---@param identities string[]
function M.mark_restart_required(identities)
  for _, identity in ipairs(identities) do
    state_store.package_restart_required[identity] = true
    state_store.package_interrupted[identity] = nil
  end
end

--- Record that mutation left package consistency unproved.
---@param identity string
---@param evidence { operation_id?: string, message?: string }
function M.mark_interrupted(identity, evidence) state_store.package_interrupted[identity] = vim.deepcopy(evidence) end

--- Install wholly absent packages synchronously for interactive startup apply.
---@param records table[]
---@return boolean, string|nil
function M.install_for_apply(records)
  local absent = {}
  for _, record in ipairs(records) do
    if record.state ~= 'satisfied' then
      if record.state ~= 'absent' then return false, M.apply_reason(record.state) end
      absent[#absent + 1] = record
    end
  end
  if #absent == 0 then return true end
  if vim.fn.has('ttyin') ~= 1 then return false, 'package_absent' end
  if vim.fn.confirm('Install required Plait provider packages?', '&Install\n&Cancel', 2) ~= 1 then
    return false, 'consent_denied'
  end
  -- One normalized activation call includes both reusable satisfied packages
  -- and the wholly absent set being installed.
  local ok = activate(records)
  if not ok then
    for _, record in ipairs(absent) do
      M.mark_interrupted(record.identity, { operation_id = 'apply', message = 'Provider package verification failed.' })
    end
    return false, 'partial_unknown'
  end
  for _, record in ipairs(absent) do
    record.state = 'satisfied'
    record.active_source = record.source
    record.active_commit = record.required_commit
    record.inconsistency = vim.NIL
    record.repair = ''
  end
  return true
end

--- Activate already-satisfied requirements without loading plugin entrypoints.
---@param records table[]
---@return boolean, string|nil
function M.activate_for_apply(records)
  local ok, message = activate(records)
  if ok then return true end
  for _, record in ipairs(records) do
    M.mark_interrupted(record.identity, { operation_id = 'apply', message = message })
  end
  return false, 'partial_unknown'
end

--- Project package records to their closed state map.
---@param records table[]
---@return table<string, string>
local function state_map(records)
  local result = {}
  for _, record in ipairs(records) do
    result[record.identity] = record.state
  end
  return result
end

--- Build an unavailable package synchronization result.
---@param reason string
---@param records table[]
---@return table
local function unavailable(reason, records)
  local identities = {}
  for _, record in ipairs(records) do
    identities[#identities + 1] = record.identity
  end
  return {
    status = 'unavailable',
    operation = 'packages.sync',
    reason = reason,
    details = { packages = identities, states = state_map(records) },
  }
end

--- Replace stale package diagnostics with interrupted-mutation evidence.
---@param records table[]
---@param targets string[]
---@param operation_id string
---@param message string
local function publish_interrupted_diagnostics(records, targets, operation_id, message)
  if not state_store.snapshot then return end
  local retained = {}
  for _, item in ipairs(state_store.snapshot.diagnostics) do
    local package = item.details and item.details.package
    if not (item.code:match('^package%.') and package and vim.list_contains(targets, package)) then
      retained[#retained + 1] = item
    end
  end
  state_store.snapshot.diagnostics = retained
  for _, record in ipairs(records) do
    if vim.list_contains(targets, record.identity) then
      state_store.snapshot.diagnostics[#state_store.snapshot.diagnostics + 1] = {
        code = 'package.partial_unknown',
        severity = 'error',
        summary = 'Package state is partially unknown.',
        repair = states.partial_unknown.repair,
        source = nil,
        related_sources = {},
        details = {
          packages = { record.identity },
          inconsistency = 'interrupted_mutation',
          operation_id = operation_id,
          message = message,
        },
      }
    end
  end
end

--- Synchronize the provider packages in the latest effective snapshot.
---@param consent? boolean
---@return table
function M.sync(consent)
  if consent ~= nil and type(consent) ~= 'boolean' then error('plait: packages.sync consent must be boolean', 2) end
  if not state_store.snapshot then error('plait: package synchronization requires a completed snapshot', 2) end
  local records = state_store.snapshot.packages
  local aggregate = M.aggregate(records)
  if aggregate == 'satisfied' then
    return { status = 'performed', operation = 'packages.sync', details = { changed = {}, states = state_map(records) } }
  end
  for _, record in ipairs(records) do
    if record.state == 'source_collision' then return unavailable('package_source_collision', records) end
    if record.state == 'restart_required' then return unavailable('restart_required', records) end
  end
  if aggregate == 'partial_unknown' and not consent then return unavailable('consent_required', records) end
  if not consent then
    if vim.fn.has('ttyin') ~= 1 then return unavailable('consent_required', records) end
    if vim.fn.confirm('Synchronize Plait provider packages?', '&Synchronize\n&Cancel', 2) ~= 1 then
      return unavailable('consent_denied', records)
    end
  end

  local targets = {}
  local mutable = {}
  for _, record in ipairs(records) do
    if record.state ~= 'satisfied' then
      targets[#targets + 1] = record.identity
      mutable[#mutable + 1] = vim.deepcopy(record)
    end
  end
  return operations.start({
    operation = 'packages.sync',
    targets = targets,
    work = function(done)
      local execution_ok, ok = pcall(activate, mutable)
      done(execution_ok and ok)
    end,
    success_details = function() return { changed = vim.deepcopy(targets), states = state_map(records) } end,
    started_details = { packages = vim.deepcopy(targets) },
    failure_message = 'Provider package synchronization failed.',
    on_success = function()
      M.mark_restart_required(targets)
      for _, record in ipairs(records) do
        if vim.list_contains(targets, record.identity) then
          record.state = 'restart_required'
          record.inconsistency = vim.NIL
          record.repair = states.restart_required.repair
        end
      end
    end,
    on_failure = function(operation_id, message)
      for _, record in ipairs(records) do
        if vim.list_contains(targets, record.identity) then
          M.mark_interrupted(record.identity, { operation_id = operation_id, message = message })
          record.state = 'partial_unknown'
          record.inconsistency = 'interrupted_mutation'
          record.repair = states.partial_unknown.repair
        end
      end
      publish_interrupted_diagnostics(records, targets, operation_id, message)
    end,
  })
end

return M
