local application = require('plait.application')
local canonical = require('plait.canonical')
local completion = require('plait.completion')
local editor = require('plait.editor')
local formatting = require('plait.formatting')
local language = require('plait.language')
local environment = require('plait.environment')
local packages = require('plait.packages')
local plan = require('plait.plan')
local providers = require('plait.providers')
local result_renderer = require('plait.result')
local schema = require('plait.schema_generated')
local snapshot = require('plait.snapshot')
local state = require('plait.state')
local startup = require('plait.startup')
local tooling = require('plait.tooling')
local validation = require('plait.validation')

local M = {
  actions = {
    completion = completion.actions,
    editor = editor.actions,
    formatting = formatting.actions,
    language = language.actions,
    packages = { sync = packages.sync },
    tooling = tooling.actions,
  },
}

--- Render one structured Plait validation or action result without editor side effects.
---@param value any
---@return string
function M.render(value) return result_renderer.render(value) end

local inspection_sections = {
  modules = true,
  capabilities = true,
  effects = true,
  language_servers = true,
  packages = true,
  tools = true,
  diagnostics = true,
  operations = true,
}

--- Raise a public API misuse error.
---@param message string
local function misuse(message) error('plait: ' .. message, 3) end

--- Capture provenance for a public collection call.
---@param path string
---@return table
local function source(path)
  local info = debug.getinfo(3, 'Sl') or {}
  return {
    file = info.source and info.source:gsub('^@', '') or 'unknown',
    line = info.currentline or 0,
    path = path,
  }
end

---@class PlaitCollector
---@field collector_source table
---@field selection_calls table[]
---@field configuration_calls table[]
---@field override_calls table[]
---@field provider_calls table[]
---@field sealed boolean
---@field owner_init function|nil
local Collector = {}
Collector.__index = Collector
local resolution_caches = setmetatable({}, { __mode = 'k' })

--- Reject collection after the first apply entry.
---@param collector PlaitCollector
local function ensure_collecting(collector)
  if collector.sealed then misuse('configuration collector is sealed') end
end

--- Invalidate the private point-in-time resolution after collection changes.
---@param collector PlaitCollector
local function invalidate_resolution(collector) resolution_caches[collector] = nil end

--- Select modules for this Plait configuration.
---@param entries string[]
---@return PlaitCollector
function Collector:select(entries)
  ensure_collecting(self)
  -- Local modules are opaque handles.  Copying them would discard their
  -- private marker and turn a valid declaration into an arbitrary table.
  self.selection_calls[#self.selection_calls + 1] = { value = entries, source = source('select[1]') }
  invalidate_resolution(self)
  return self
end

--- Add capability configuration to this Plait configuration.
---@param declaration { operation_feedback?: 'errors'|'all'|'silent', editor?: PlaitEditorConfiguration, language?: PlaitLanguageConfiguration, completion?: PlaitCompletionConfiguration, formatting?: PlaitFormattingConfiguration, tooling?: PlaitToolingConfiguration }
---@return PlaitCollector
function Collector:configure(declaration)
  ensure_collecting(self)
  self.configuration_calls[#self.configuration_calls + 1] =
    { value = vim.deepcopy(declaration), source = source('configure') }
  invalidate_resolution(self)
  return self
end

--- Add owner overrides to this Plait configuration.
---@param declaration table
---@return PlaitCollector
function Collector:override(declaration)
  ensure_collecting(self)
  self.override_calls[#self.override_calls + 1] = { value = vim.deepcopy(declaration), source = source('override') }
  invalidate_resolution(self)
  return self
end

--- Add provider escape-hatch declarations to this Plait configuration.
---@param declaration table
---@return PlaitCollector
function Collector:providers(declaration)
  ensure_collecting(self)
  self.provider_calls[#self.provider_calls + 1] = { value = vim.deepcopy(declaration), source = source('providers') }
  invalidate_resolution(self)
  return self
end

--- Combine repeated selection calls while retaining every source.
---@param calls table[]
---@param fallback_source table
---@return any, table[]
local function combine_selections(calls, fallback_source)
  local selections = {}
  local sources = {}
  for _, call in ipairs(calls) do
    if type(call.value) ~= 'table' or getmetatable(call.value) ~= nil then return call.value, { call.source } end
    local count = 0
    local maximum = 0
    for key in pairs(call.value) do
      count = count + 1
      if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return call.value, { call.source } end
      maximum = math.max(maximum, key)
    end
    if maximum ~= count then return call.value, { call.source } end
    for index = 1, count do
      selections[#selections + 1] = call.value[index]
      local item_source = vim.deepcopy(call.source)
      item_source.path = 'select[' .. index .. ']'
      sources[#sources + 1] = item_source
    end
  end
  if #sources == 0 then sources[1] = fallback_source end
  return selections, sources
end

--- Compare collected values without allowing malformed values to escape validation.
---@param left any
---@param right any
---@return boolean
local function collected_equal(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= 'table' then return left == right end
  local left_ok, left_encoded = pcall(canonical.encode, left)
  local right_ok, right_encoded = pcall(canonical.encode, right)
  return left_ok and right_ok and left_encoded == right_encoded
end

--- Record the source of each owner configuration leaf.
---@param value any
---@param path string
---@param declaration_source table
---@param sources table<string, table[]>
---@param ancestors? table<table, boolean>
local function record_configuration_sources(value, path, declaration_source, sources, ancestors)
  if type(value) ~= 'table' or getmetatable(value) ~= nil then
    sources[path] = sources[path] or {}
    local item_source = vim.deepcopy(declaration_source)
    item_source.path = path
    sources[path][#sources[path] + 1] = item_source
    return
  end
  ancestors = ancestors or {}
  if ancestors[value] then return end
  ancestors[value] = true
  local has_numeric_key = false
  local has_entries = false
  for key in pairs(value) do
    has_entries = true
    if type(key) ~= 'string' then has_numeric_key = true end
  end
  if has_numeric_key or not has_entries then
    sources[path] = sources[path] or {}
    local item_source = vim.deepcopy(declaration_source)
    item_source.path = path
    sources[path][#sources[path] + 1] = item_source
  else
    for key, child in pairs(value) do
      record_configuration_sources(child, path .. '.' .. key, declaration_source, sources, ancestors)
    end
  end
  ancestors[value] = nil
end

--- Merge disjoint repeated configuration calls and poison implicit conflicts.
---@param target table
---@param declaration table
---@param node table|nil
local function merge_configuration(target, declaration, node)
  for key, value in pairs(declaration) do
    local existing = rawget(target, key)
    local child = node and node.fields and node.fields[key]
    if existing == nil then
      target[key] = vim.deepcopy(value)
    elseif
      (not child or child.type == 'map')
      and type(existing) == 'table'
      and getmetatable(existing) == nil
      and type(value) == 'table'
      and getmetatable(value) == nil
    then
      merge_configuration(existing, value, child)
    elseif not collected_equal(existing, value) then
      target[key] = setmetatable({}, {})
    end
  end
end

--- Combine repeated configuration calls without assigning call-order precedence.
---@param calls table[]
---@param fallback_source table
---@return any, table, table<string, table[]>
local function combine_configuration(calls, fallback_source)
  local sources = {}
  for _, call in ipairs(calls) do
    record_configuration_sources(call.value, 'configure', call.source, sources)
  end
  if #calls == 0 then return nil, fallback_source, sources end
  if #calls == 1 then return calls[1].value, calls[1].source, sources end
  local configuration = {}
  for _, call in ipairs(calls) do
    if type(call.value) ~= 'table' or getmetatable(call.value) ~= nil then return call.value, call.source, sources end
    merge_configuration(configuration, call.value, { fields = schema })
  end
  return configuration, calls[1].source, sources
end

--- Resolve the currently collected declarations.
---@param collector PlaitCollector
---@return table|nil, table[]
local function resolve(collector)
  local cached = resolution_caches[collector]
  if cached then return cached.effective_plan, cached.diagnostics end
  local selections, selection_sources = combine_selections(collector.selection_calls, collector.collector_source)
  local declaration, configuration_source, configuration_sources =
    combine_configuration(collector.configuration_calls, collector.collector_source)
  local configuration, resolution, diagnostics = validation.validate(
    selections,
    selection_sources,
    declaration,
    configuration_source,
    configuration_sources,
    schema,
    collector.override_calls
  )
  if configuration then state.operation_feedback = configuration.operation_feedback end
  local semantic_diagnostic_count = #diagnostics
  vim.list_extend(diagnostics, vim.deepcopy(state.bootstrap_diagnostics))
  vim.list_extend(diagnostics, vim.deepcopy(state.operation_diagnostics))
  validation.sort_diagnostics(diagnostics)
  if not configuration or not resolution or semantic_diagnostic_count > 0 then
    resolution_caches[collector] = { diagnostics = diagnostics }
    return nil, diagnostics
  end
  local provider_diagnostics = providers.resolve(collector.provider_calls, resolution)
  vim.list_extend(diagnostics, provider_diagnostics)
  validation.sort_diagnostics(diagnostics)
  if #provider_diagnostics > 0 then
    resolution_caches[collector] = { diagnostics = diagnostics }
    return nil, diagnostics
  end
  local effective_plan, package_diagnostics = plan.build(configuration, resolution)
  vim.list_extend(diagnostics, package_diagnostics)
  validation.sort_diagnostics(diagnostics)
  resolution_caches[collector] = { effective_plan = effective_plan, diagnostics = diagnostics }
  return effective_plan, diagnostics
end

--- Validate collected declarations and publish an effective-plan snapshot.
---@return table
function Collector:validate()
  local effective_plan, diagnostics = resolve(self)
  if not effective_plan then
    snapshot.publish_empty('invalid', diagnostics)
    return vim.deepcopy({
      status = 'invalid',
      diagnostics = diagnostics,
      modules = {},
      capabilities = {},
      effects = {},
      packages = {},
      tools = {},
    })
  end
  local plan_id = plan.id(effective_plan, schema)
  snapshot.publish(effective_plan, diagnostics)
  return vim.deepcopy({ status = 'valid', diagnostics = diagnostics, plan = effective_plan, plan_id = plan_id })
end

--- Re-observe the effective plan at an explicit internal refresh boundary.
---@return table
function Collector:_refresh()
  invalidate_resolution(self)
  return self:validate()
end

--- Seal, re-resolve, and synchronously apply the effective editor plan.
---@param ... any
---@return table
function Collector:apply(...)
  if self.sealed then misuse('apply may only be called once') end
  self.sealed = true
  if select('#', ...) > 0 then misuse('apply expects no arguments') end
  if not startup.is_synchronous_init(self.owner_init) then
    misuse('apply is only available during synchronous init.lua startup')
  end

  local effective_plan, diagnostics = resolve(self)
  if not effective_plan then return application.invalid(diagnostics) end
  diagnostics = vim.deepcopy(diagnostics)
  local environment_diagnostics = environment.observe(#effective_plan.packages > 0)
  vim.list_extend(diagnostics, environment_diagnostics)
  validation.sort_diagnostics(diagnostics)
  local environment_codes = {}
  for _, item in ipairs(environment_diagnostics) do
    if environment.blocking(item) and not vim.list_contains(environment_codes, item.code) then
      environment_codes[#environment_codes + 1] = item.code
    end
  end
  if #environment_codes > 0 then
    return application.unavailable(effective_plan, diagnostics, 'environment_unavailable', environment_codes)
  end
  local package_state = packages.aggregate(effective_plan.packages)
  if package_state == 'absent' then
    local installed, reason = packages.install_for_apply(effective_plan.packages)
    if not installed then
      if reason == 'partial_unknown' then
        invalidate_resolution(self)
        effective_plan, diagnostics = resolve(self)
        if not effective_plan then return application.invalid(diagnostics) end
      end
      return application.unavailable(effective_plan, diagnostics, reason or 'partial_unknown')
    end
  elseif package_state ~= 'satisfied' then
    return application.unavailable(effective_plan, diagnostics, packages.apply_reason(package_state))
  else
    local activated, reason = packages.activate_for_apply(effective_plan.packages)
    if not activated then return application.unavailable(effective_plan, diagnostics, reason or 'partial_unknown') end
  end
  local preflight_diagnostics = application.preflight(effective_plan)
  if #preflight_diagnostics > 0 then
    vim.list_extend(diagnostics, preflight_diagnostics)
    validation.sort_diagnostics(diagnostics)
    local result = application.invalid(diagnostics, effective_plan)
    require('plait.feedback').blocked_application(preflight_diagnostics[1])
    return result
  end
  local applied = application.run(effective_plan, diagnostics, schema)
  invalidate_resolution(self)
  return applied
end

--- Create the process-wide Plait configuration collector.
---@return PlaitCollector
function M.config()
  if state.collector then misuse('a configuration collector already exists') end
  state.collector = setmetatable({
    collector_source = source('config'),
    selection_calls = {},
    configuration_calls = {},
    override_calls = {},
    provider_calls = {},
    sealed = false,
    owner_init = startup.owner_init(),
  }, Collector)
  return state.collector
end

--- Declare a constrained owner-local module.
---@param declaration table
---@return table
function M.module(declaration) return require('plait.modules').create_local(declaration, source('module')) end

--- Replace one supported contribution identity.
---@param value any
---@return table
function M.replace(value) return { kind = 'replace', value = vim.deepcopy(value) } end

--- Disable one supported contribution identity.
---@return table
function M.disable() return { kind = 'disable' } end

--- Inspect the latest completed Plait snapshot, or live servers for the current buffer.
---@param section string
---@param identity? string
---@return table
function M.inspect(section, identity)
  if type(section) ~= 'string' or section == '' then misuse('inspection section must be a non-empty string') end
  if identity ~= nil and (type(identity) ~= 'string' or identity == '') then
    misuse('inspection identity must be a non-empty string')
  end
  if not state.snapshot then misuse('inspection requires a completed snapshot') end
  if not inspection_sections[section] then misuse('unknown inspection section') end
  local records = section == 'language_servers'
      and require('plait.language').inspect_servers(vim.api.nvim_get_current_buf())
    or state.snapshot[section]
  --- Copy an inspection value while replacing functions with source descriptors.
  ---@param value any
  ---@param ancestors? table<table, boolean>
  ---@return any
  local function inspectable(value, ancestors)
    if type(value) == 'function' then
      local info = debug.getinfo(value, 'Sl') or {}
      return { kind = 'function', source = info.source or 'unknown', line = info.linedefined or 0 }
    end
    if type(value) ~= 'table' then return value end
    ancestors = ancestors or {}
    if ancestors[value] then return nil end
    ancestors[value] = true
    local result = {}
    for key, child in pairs(value) do
      result[key] = inspectable(child, ancestors)
    end
    ancestors[value] = nil
    return result
  end
  if identity == nil then
    local result = assert(inspectable(records))
    if section == 'operations' then
      table.sort(
        result,
        function(left, right)
          return left.started_at < right.started_at
            or (left.started_at == right.started_at and left.identity < right.identity)
        end
      )
    end
    return result
  end
  if section == 'diagnostics' then
    local matches = {}
    for _, record in ipairs(records) do
      if record.code == identity then matches[#matches + 1] = record end
    end
    if #matches > 0 then return assert(inspectable(matches)) end
    misuse('inspection identity not found')
    return {}
  end
  for _, record in ipairs(records) do
    if record.identity == identity then return assert(inspectable(record)) end
  end
  misuse('inspection identity not found')
  return {}
end

return M
