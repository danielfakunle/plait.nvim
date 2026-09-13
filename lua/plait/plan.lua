local canonical = require('plait.canonical')
local completion_integration = require('plait.completion')
local formatting_integration = require('plait.formatting')
local packages = require('plait.packages')
local tooling_integration = require('plait.tooling')
local tools = require('plait.tools')

local M = {}
local private_tool_requirements = setmetatable({}, { __mode = 'k' })
local private_formatting_requirements = setmetatable({}, { __mode = 'k' })
local private_language_requirements = setmetatable({}, { __mode = 'k' })

--- Copy a semantic array and preserve its declared array identity when empty.
---@param values table[]
---@return table[]
local function array(values) return canonical.mark_array(vim.deepcopy(values)) end

--- Copy validated configuration according to its executable schema.
---@param node table
---@param value any
---@return any
local function configuration_value(node, value)
  if not node then return vim.deepcopy(value) end
  if node.type == 'array' then
    local result = {}
    for index, item in ipairs(value) do
      result[index] = configuration_value(node.item, item)
    end
    return canonical.mark_array(result)
  end
  if node.type ~= 'map' then return value end
  local result = {}
  for name, child in pairs(node.fields) do
    result[name] = configuration_value(child, value[name])
  end
  return result
end

--- Sort effects by stage, dependency topology, and bytewise identity.
---@param effects table[]
local function sort_effects(effects)
  local by_identity, emitted, ordered = {}, {}, {}
  for _, effect in ipairs(effects) do
    by_identity[effect.identity] = effect
  end
  while #ordered < #effects do
    local candidates = {}
    for _, effect in ipairs(effects) do
      if not emitted[effect.identity] then
        local ready = true
        for _, dependency in ipairs(effect.dependencies) do
          if by_identity[dependency] and not emitted[dependency] then ready = false end
        end
        if ready then candidates[#candidates + 1] = effect end
      end
    end
    table.sort(candidates, function(left, right)
      if left.stage ~= right.stage then return left.stage < right.stage end
      return left.identity < right.identity
    end)
    local selected = assert(candidates[1], 'effective plan has cyclic effect dependencies')
    emitted[selected.identity] = true
    ordered[#ordered + 1] = selected
  end
  for index, effect in ipairs(ordered) do
    effects[index] = effect
  end
end

--- Build the canonical effective plan for resolved built-in modules.
---@param configuration table
---@param resolution table
---@return table, table[]
function M.build(configuration, resolution)
  local effects = {}
  local editor
  local completion
  local language
  local formatting
  local tooling
  for _, module in ipairs(resolution.modules) do
    if module.identity == 'editor' then editor = module end
    if module.identity == 'completion' then completion = module end
    if module.identity == 'language' then language = module end
    if module.identity == 'formatting' then formatting = module end
    if module.identity == 'tooling' then tooling = module end
  end
  if editor then
    effects = {
      {
        identity = 'editor/native-options',
        stage = 3,
        responsible_capability = 'editor',
        provider = nil,
        dependencies = {},
        state = 'pending',
        sources = vim.deepcopy(editor.selection_sources),
        error = nil,
      },
      {
        identity = 'editor/actions',
        stage = 4,
        responsible_capability = 'editor',
        provider = nil,
        dependencies = { 'editor/native-options' },
        state = 'pending',
        sources = vim.deepcopy(editor.selection_sources),
        error = nil,
      },
      {
        identity = 'editor/mappings',
        stage = 4,
        responsible_capability = 'editor',
        provider = nil,
        dependencies = { 'editor/actions' },
        state = 'pending',
        sources = vim.deepcopy(editor.selection_sources),
        error = nil,
      },
    }
  end
  if editor and configuration.editor.yank_highlight then
    effects[#effects + 1] = {
      identity = 'editor/yank-highlight',
      stage = 4,
      responsible_capability = 'editor',
      provider = nil,
      dependencies = { 'editor/native-options' },
      state = 'pending',
      sources = vim.deepcopy(editor.selection_sources),
      error = nil,
    }
  end
  if language then
    vim.list_extend(effects, require('plait.language').effects(resolution, language.selection_sources))
  end
  if completion then vim.list_extend(effects, completion_integration.effects(completion.selection_sources)) end
  if formatting then vim.list_extend(effects, formatting_integration.effects(formatting.selection_sources)) end
  if tooling then
    vim.list_extend(effects, tooling_integration.effects(configuration.tooling, tooling.selection_sources))
  end
  local package_records, package_diagnostics = packages.resolve(resolution)
  local tool_records, tool_diagnostics, tool_requirements = tools.resolve(resolution)
  for _, item in ipairs(tool_diagnostics) do
    for _, operation in ipairs(item.details.affected_operations) do
      local capability_identity = operation:match('^([^.]+)')
      for _, capability in ipairs(resolution.capabilities) do
        if capability.identity == capability_identity then
          capability.state = 'degraded'
          if not vim.list_contains(capability.degradation_reasons, item.code) then
            capability.degradation_reasons[#capability.degradation_reasons + 1] = item.code
            table.sort(capability.degradation_reasons)
          end
        end
      end
    end
  end
  vim.list_extend(package_diagnostics, tool_diagnostics)
  sort_effects(effects)
  local effective_plan = {
    snapshot_state = 'validated',
    modules = resolution.modules,
    capabilities = resolution.capabilities,
    effects = effects,
    packages = package_records,
    tools = tool_records,
  }
  private_tool_requirements[effective_plan] = tool_requirements
  private_formatting_requirements[effective_plan] = formatting_integration.resolve(resolution)
  private_language_requirements[effective_plan] = require('plait.language').resolve(resolution)
  return effective_plan, package_diagnostics
end

--- Return private tool requirements associated with one effective plan.
---@param effective_plan table
---@return table<string, table>
function M.tool_requirements(effective_plan) return vim.deepcopy(private_tool_requirements[effective_plan] or {}) end

--- Return private formatting requirements associated with one effective plan.
---@param effective_plan table
---@return table
function M.formatting_requirements(effective_plan)
  return vim.deepcopy(private_formatting_requirements[effective_plan] or { formatters = {}, by_filetype = {} })
end

--- Return private language-server requirements associated with one effective plan.
---@param effective_plan table
---@return table<string, table>
function M.language_requirements(effective_plan)
  return vim.deepcopy(private_language_requirements[effective_plan] or {})
end

--- Compute the semantic identity of an effective plan.
---@param effective_plan table
---@param configuration_schema table
---@return string
function M.id(effective_plan, configuration_schema)
  local semantic = {
    modules = canonical.mark_array({}),
    capabilities = canonical.mark_array({}),
    effects = canonical.mark_array({}),
    packages = canonical.mark_array({}),
    tools = canonical.mark_array({}),
  }
  for index, module in ipairs(effective_plan.modules) do
    semantic.modules[index] = {
      identity = module.identity,
      provides = array(module.provides),
      requires = array(module.requires),
      ordering_edges = array(module.ordering_edges),
      contributions = array(module.contributions),
    }
  end
  for index, capability in ipairs(effective_plan.capabilities) do
    local provider_configuration = canonical.mark_array({})
    for provider_index, provider in ipairs(capability.configuration.providers or {}) do
      provider_configuration[provider_index] = {
        identity = provider.identity,
        target = provider.target,
        value = vim.deepcopy(provider.value),
      }
    end
    semantic.capabilities[index] = {
      identity = capability.identity,
      activator = capability.activator,
      cardinality = capability.cardinality,
      responsible_integration = capability.responsible_integration,
      dependents = array(capability.dependents),
      providers = array(capability.providers),
      configuration = configuration_value(configuration_schema[capability.identity], capability.configuration.values),
      provider_configuration = provider_configuration,
      contributions = array(capability.contributions),
      actions = array(capability.actions),
    }
  end
  for index, effect in ipairs(effective_plan.effects) do
    semantic.effects[index] = {
      identity = effect.identity,
      stage = effect.stage,
      responsible_capability = effect.responsible_capability,
      provider = effect.provider,
      dependencies = array(effect.dependencies),
    }
  end
  for index, package in ipairs(effective_plan.packages) do
    semantic.packages[index] = {
      identity = package.identity,
      source = package.source,
      required_commit = package.required_commit,
      responsible_capabilities = array(package.responsible_capabilities),
    }
  end
  for index, tool in ipairs(effective_plan.tools) do
    semantic.tools[index] = {
      identity = tool.identity,
      executable = tool.executable,
      constraint = tool.constraint,
      ownership = tool.ownership,
      affected_operations = array(tool.affected_operations),
    }
  end
  return vim.fn.sha256(canonical.encode_plan(semantic))
end

return M
