local canonical = require('plait.canonical')

local M = {}

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

--- Build the canonical effective plan for resolved built-in modules.
---@param configuration table
---@param resolution table
---@return table
function M.build(configuration, resolution)
  local effects = {}
  local editor
  for _, module in ipairs(resolution.modules) do
    if module.identity == 'editor' then editor = module end
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
  return {
    snapshot_state = 'validated',
    modules = resolution.modules,
    capabilities = resolution.capabilities,
    effects = effects,
    packages = {},
    tools = {},
  }
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
    semantic.capabilities[index] = {
      identity = capability.identity,
      activator = capability.activator,
      cardinality = capability.cardinality,
      responsible_integration = capability.responsible_integration,
      dependents = array(capability.dependents),
      providers = array(capability.providers),
      configuration = configuration_value(configuration_schema[capability.identity], capability.configuration.values),
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
