local canonical = require('plait.canonical')
local schema = require('plait.schema_generated')
local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

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

--- Resolve the canonical editor-only effective plan.
---@param configuration table
---@param selection_sources table[]
---@return table
local function plan_for(configuration, selection_sources)
  local modules = {
    {
      identity = 'editor',
      state = 'active',
      selection_sources = vim.deepcopy(selection_sources),
      provides = { 'editor' },
      requires = {},
      ordering_edges = {},
      contributions = { 'editor.configuration' },
    },
  }
  local capabilities = {
    {
      identity = 'editor',
      state = 'active',
      activator = 'editor',
      cardinality = 'exclusive',
      responsible_integration = 'editor/native',
      dependents = {},
      providers = {},
      configuration = configuration,
      contributions = { 'editor.configuration' },
      actions = { 'editor.clear_search', 'editor.focus', 'editor.save' },
      degradation_reasons = {},
    },
  }
  local effects = {
    {
      identity = 'editor/native-options',
      stage = 3,
      responsible_capability = 'editor',
      provider = nil,
      dependencies = {},
      state = 'pending',
      sources = vim.deepcopy(selection_sources),
      error = nil,
    },
    {
      identity = 'editor/actions',
      stage = 4,
      responsible_capability = 'editor',
      provider = nil,
      dependencies = { 'editor/native-options' },
      state = 'pending',
      sources = vim.deepcopy(selection_sources),
      error = nil,
    },
    {
      identity = 'editor/mappings',
      stage = 4,
      responsible_capability = 'editor',
      provider = nil,
      dependencies = { 'editor/actions' },
      state = 'pending',
      sources = vim.deepcopy(selection_sources),
      error = nil,
    },
  }
  if configuration.yank_highlight then
    effects[#effects + 1] = {
      identity = 'editor/yank-highlight',
      stage = 4,
      responsible_capability = 'editor',
      provider = nil,
      dependencies = { 'editor/native-options' },
      state = 'pending',
      sources = vim.deepcopy(selection_sources),
      error = nil,
    }
  end
  return {
    snapshot_state = 'validated',
    modules = modules,
    capabilities = capabilities,
    effects = effects,
    packages = {},
    tools = {},
  }
end

---@class PlaitCollector
---@field collector_source table
---@field selection_calls table[]
---@field configuration_calls table[]
local Collector = {}
Collector.__index = Collector

--- Select modules for this Plait configuration.
---@param entries string[]
---@return PlaitCollector
function Collector:select(entries)
  self.selection_calls[#self.selection_calls + 1] = { value = vim.deepcopy(entries), source = source('select[1]') }
  return self
end

--- Add capability configuration to this Plait configuration.
---@param declaration { editor?: PlaitEditorConfiguration }
---@return PlaitCollector
function Collector:configure(declaration)
  self.configuration_calls[#self.configuration_calls + 1] =
    { value = vim.deepcopy(declaration), source = source('configure') }
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

--- Merge disjoint repeated configuration calls and poison implicit conflicts.
---@param target table
---@param declaration table
local function merge_configuration(target, declaration)
  for key, value in pairs(declaration) do
    local existing = rawget(target, key)
    if existing == nil then
      target[key] = vim.deepcopy(value)
    elseif
      type(existing) == 'table'
      and getmetatable(existing) == nil
      and type(value) == 'table'
      and getmetatable(value) == nil
    then
      merge_configuration(existing, value)
    elseif not collected_equal(existing, value) then
      target[key] = setmetatable({}, {})
    end
  end
end

--- Combine repeated configuration calls without assigning call-order precedence.
---@param calls table[]
---@param fallback_source table
---@return any, table
local function combine_configuration(calls, fallback_source)
  if #calls == 0 then return nil, fallback_source end
  if #calls == 1 then return calls[1].value, calls[1].source end
  local configuration = {}
  for _, call in ipairs(calls) do
    if type(call.value) ~= 'table' or getmetatable(call.value) ~= nil then return call.value, call.source end
    merge_configuration(configuration, call.value)
  end
  return configuration, calls[1].source
end

--- Validate collected declarations and publish an effective-plan snapshot.
---@return table
function Collector:validate()
  local selections, selection_sources = combine_selections(self.selection_calls, self.collector_source)
  local declaration, configuration_source = combine_configuration(self.configuration_calls, self.collector_source)
  local configuration, diagnostics =
    validation.validate(selections, selection_sources, declaration, configuration_source, schema.editor)
  vim.list_extend(diagnostics, vim.deepcopy(state.bootstrap_diagnostics))
  validation.sort_diagnostics(diagnostics)
  if not configuration then
    state.snapshot = {
      modules = {},
      capabilities = {},
      effects = {},
      packages = {},
      tools = {},
      diagnostics = diagnostics,
      operations = {},
    }
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
  local plan = plan_for(configuration, selection_sources)
  local semantic_plan = vim.deepcopy(plan)
  semantic_plan.snapshot_state = nil
  for _, module in ipairs(semantic_plan.modules) do
    module.selection_sources = nil
  end
  for _, effect in ipairs(semantic_plan.effects) do
    effect.sources = nil
    effect.state = nil
    effect.error = nil
  end
  local plan_id = vim.fn.sha256(canonical.encode(semantic_plan))
  state.snapshot = {
    modules = plan.modules,
    capabilities = plan.capabilities,
    effects = plan.effects,
    packages = plan.packages,
    tools = plan.tools,
    diagnostics = diagnostics,
    operations = {},
  }
  return vim.deepcopy({ status = 'valid', diagnostics = diagnostics, plan = plan, plan_id = plan_id })
end

--- Create the process-wide Plait configuration collector.
---@return PlaitCollector
function M.config()
  if state.collector then misuse('a configuration collector already exists') end
  state.collector = setmetatable({
    collector_source = source('config'),
    selection_calls = {},
    configuration_calls = {},
  }, Collector)
  return state.collector
end

--- Inspect the latest completed Plait snapshot.
---@param section string
---@param identity? string
---@return table
function M.inspect(section, identity)
  if type(section) ~= 'string' or section == '' then misuse('inspection section must be a non-empty string') end
  if identity ~= nil and (type(identity) ~= 'string' or identity == '') then
    misuse('inspection identity must be a non-empty string')
  end
  if not state.snapshot then misuse('inspection requires a completed snapshot') end
  local records = state.snapshot[section]
  if not records then misuse('unknown inspection section ' .. tostring(section)) end
  if identity == nil then return vim.deepcopy(records) end
  if section == 'diagnostics' then
    local matches = {}
    for _, record in ipairs(records) do
      if record.code == identity then matches[#matches + 1] = record end
    end
    if #matches > 0 then return vim.deepcopy(matches) end
    misuse('inspection identity not found: ' .. identity)
    return {}
  end
  for _, record in ipairs(records) do
    if record.identity == identity then return vim.deepcopy(record) end
  end
  misuse('inspection identity not found: ' .. identity)
  return {}
end

return M
