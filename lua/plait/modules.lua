local text = require('plait.text')

local M = {}

local module_catalog = {
  editor = {
    provides = { 'editor' },
    requires = {},
    optional = {},
    contributions = { 'editor.configuration' },
  },
  language = {
    provides = { 'language' },
    requires = {},
    optional = {},
    contributions = {},
  },
  completion = {
    provides = { 'completion' },
    requires = { 'language' },
    optional = {},
    contributions = {},
  },
  formatting = {
    provides = { 'formatting' },
    requires = {},
    optional = { 'language' },
    contributions = {},
  },
  tooling = {
    provides = { 'tooling' },
    requires = {},
    optional = {},
    contributions = {},
  },
  ['lang.lua'] = {
    provides = { 'lang.lua' },
    requires = { 'formatting', 'language', 'tooling' },
    optional = { 'completion' },
    contributions = {
      'formatting.by_filetype.lua',
      'formatting.formatters.stylua',
      'language.servers.lua_ls',
      'tooling.tools.lua-language-server',
      'tooling.tools.stylua',
    },
  },
  ['lang.typescript'] = {
    provides = { 'lang.typescript' },
    requires = { 'formatting', 'language', 'tooling' },
    optional = { 'completion' },
    contributions = {
      'formatting.by_filetype.javascript',
      'formatting.by_filetype.javascriptreact',
      'formatting.by_filetype.typescript',
      'formatting.by_filetype.typescriptreact',
      'formatting.formatters.oxfmt',
      'language.servers.tsc',
      'tooling.tools.oxfmt',
      'tooling.tools.tsc',
    },
  },
}

local capability_catalog = {
  editor = {
    cardinality = 'exclusive',
    responsible_integration = 'editor/native',
    providers = {},
    actions = { 'editor.clear_search', 'editor.focus', 'editor.save' },
  },
  language = {
    cardinality = 'exclusive',
    responsible_integration = 'language',
    providers = { 'vim.lsp' },
    actions = {
      'language.code_action',
      'language.definition',
      'language.hover',
      'language.next_diagnostic',
      'language.previous_diagnostic',
      'language.references',
      'language.rename',
    },
  },
  completion = {
    cardinality = 'exclusive',
    responsible_integration = 'completion',
    providers = { 'blink.cmp' },
    actions = {
      'completion.accept',
      'completion.cancel',
      'completion.next',
      'completion.previous',
      'completion.scroll_documentation',
      'completion.trigger',
    },
  },
  formatting = {
    cardinality = 'exclusive',
    responsible_integration = 'formatting',
    providers = { 'conform.nvim' },
    actions = { 'formatting.format' },
  },
  tooling = {
    cardinality = 'exclusive',
    responsible_integration = 'tooling',
    providers = { 'mason.nvim' },
    actions = { 'tooling.check', 'tooling.ensure', 'tooling.install', 'tooling.update' },
  },
  ['lang.lua'] = {
    cardinality = 'exclusive',
    responsible_integration = 'language',
    providers = {},
    actions = {},
  },
  ['lang.typescript'] = {
    cardinality = 'exclusive',
    responsible_integration = 'language',
    providers = {},
    actions = {},
  },
}

--- Return the canonical description of accepted built-in identities.
---@return string
function M.expected_identity()
  local identities = vim.tbl_keys(module_catalog)
  table.sort(identities)
  for index, identity in ipairs(identities) do
    identities[index] = string.format('%q', identity)
  end
  return 'one of ' .. table.concat(identities, ', ')
end

--- Check whether a value is an exact built-in module identity.
---@param identity any
---@return boolean
function M.is_builtin(identity) return type(identity) == 'string' and module_catalog[identity] ~= nil end

--- Sort source reasons independently of collection order.
---@param sources table[]
local function sort_sources(sources)
  table.sort(sources, function(left, right)
    if left.file ~= right.file then return left.file < right.file end
    if left.line ~= right.line then return left.line < right.line end
    return left.path < right.path
  end)
end

--- Build a source-aware graph diagnostic.
---@param code string
---@param summary string
---@param repair string
---@param details table
---@param source table
---@param related_sources? table[]
---@return table
local function graph_diagnostic(code, summary, repair, details, source, related_sources)
  return {
    code = code,
    severity = 'error',
    summary = summary,
    repair = repair,
    source = vim.deepcopy(source),
    related_sources = vim.deepcopy(related_sources or {}),
    details = details,
  }
end

--- Insert an item into a bytewise-sorted set-like array.
---@param values string[]
---@param value string
local function insert_sorted(values, value)
  for _, existing in ipairs(values) do
    if existing == value then return end
  end
  values[#values + 1] = value
  table.sort(values)
end

--- Find deterministic strongly connected components that contain cycles.
---@param outgoing table<string, string[]>
---@return string[][]
local function cyclic_components(outgoing)
  local next_index = 0
  local indices = {}
  local lowlinks = {}
  local stack = {}
  local on_stack = {}
  local components = {}

  --- Visit one node using Tarjan's strongly connected components algorithm.
  ---@param identity string
  local function visit(identity)
    next_index = next_index + 1
    indices[identity] = next_index
    lowlinks[identity] = next_index
    stack[#stack + 1] = identity
    on_stack[identity] = true

    for _, dependent in ipairs(outgoing[identity]) do
      if not indices[dependent] then
        visit(dependent)
        lowlinks[identity] = math.min(lowlinks[identity], lowlinks[dependent])
      elseif on_stack[dependent] then
        lowlinks[identity] = math.min(lowlinks[identity], indices[dependent])
      end
    end
    if lowlinks[identity] ~= indices[identity] then return end

    local component = {}
    while true do
      local member = table.remove(stack)
      on_stack[member] = nil
      component[#component + 1] = member
      if member == identity then break end
    end
    table.sort(component)
    local self_cycle = #component == 1 and vim.tbl_contains(outgoing[component[1]], component[1])
    if #component > 1 or self_cycle then components[#components + 1] = component end
  end

  local identities = vim.tbl_keys(outgoing)
  table.sort(identities)
  for _, identity in ipairs(identities) do
    if not indices[identity] then visit(identity) end
  end
  table.sort(components, function(left, right) return left[1] < right[1] end)
  return components
end

--- Find an actual canonical cycle beginning at the component's first identity.
---@param component string[]
---@param outgoing table<string, string[]>
---@return string[]
local function cycle_path(component, outgoing)
  local members = {}
  for _, identity in ipairs(component) do
    members[identity] = true
  end
  local start = component[1]
  local path = { start }
  local active = { [start] = true }

  --- Search component edges in canonical order until they close at the start.
  ---@param identity string
  ---@return boolean
  local function search(identity)
    for _, dependent in ipairs(outgoing[identity]) do
      if dependent == start then
        path[#path + 1] = start
        return true
      end
      if members[dependent] and not active[dependent] then
        active[dependent] = true
        path[#path + 1] = dependent
        if search(dependent) then return true end
        path[#path] = nil
        active[dependent] = nil
      end
    end
    return false
  end

  search(start)
  return path
end

--- Resolve selected built-ins into canonical module and capability records.
---@param selections string[]
---@param selection_sources table[]
---@param editor_configuration table
---@return table|nil, table[]
function M.resolve(selections, selection_sources, editor_configuration)
  local selected = {}
  for index, identity in ipairs(selections) do
    local module = selected[identity]
    if not module then
      local definition = module_catalog[identity]
      module = {
        identity = identity,
        state = 'active',
        selection_sources = {},
        provides = vim.deepcopy(definition.provides),
        requires = vim.deepcopy(definition.requires),
        ordering_edges = {},
        contributions = vim.deepcopy(definition.contributions),
      }
      selected[identity] = module
    end
    module.selection_sources[#module.selection_sources + 1] = vim.deepcopy(selection_sources[index])
  end
  for _, module in pairs(selected) do
    sort_sources(module.selection_sources)
  end

  local activators = {}
  local outgoing = {}
  local edge_capabilities = {}
  for identity, module in pairs(selected) do
    outgoing[identity] = {}
    for _, capability in ipairs(module.provides) do
      activators[capability] = activators[capability] or {}
      activators[capability][#activators[capability] + 1] = identity
    end
  end
  for _, identities in pairs(activators) do
    table.sort(identities)
  end

  local diagnostics = {}
  for capability, identities in pairs(activators) do
    local definition = capability_catalog[capability]
    if definition.cardinality == 'exclusive' and #identities ~= 1 then
      local related_sources = {}
      for index = 2, #identities do
        related_sources[#related_sources + 1] = selected[identities[index]].selection_sources[1]
      end
      diagnostics[#diagnostics + 1] = graph_diagnostic(
        'capability.cardinality',
        string.format('Capability %s has invalid cardinality.', text.normalize(capability)),
        'Leave exactly one activator selected.',
        { capability = capability, activators = vim.deepcopy(identities) },
        selected[identities[1]].selection_sources[1],
        related_sources
      )
    end
  end

  --- Add one resolved module edge and retain the capability that caused it.
  ---@param module table
  ---@param activator string
  ---@param capability string
  local function add_edge(module, activator, capability)
    insert_sorted(module.ordering_edges, activator)
    insert_sorted(outgoing[activator], module.identity)
    local key = activator .. '\0' .. module.identity
    edge_capabilities[key] = edge_capabilities[key] or {}
    insert_sorted(edge_capabilities[key], capability)
  end

  for identity, module in pairs(selected) do
    local definition = module_catalog[identity]
    for _, capability in ipairs(definition.requires) do
      local candidates = activators[capability] or {}
      if #candidates == 0 then
        diagnostics[#diagnostics + 1] = graph_diagnostic(
          'dependency.missing',
          string.format('Module %s requires %s.', text.normalize(identity), text.normalize(capability)),
          'Select exactly one module that provides `capability`.',
          { module = identity, capability = capability },
          module.selection_sources[1]
        )
      elseif #candidates > 1 and capability_catalog[capability].cardinality == 'exclusive' then
        diagnostics[#diagnostics + 1] = graph_diagnostic(
          'dependency.ambiguous',
          string.format('Capability %s has ambiguous activators.', text.normalize(capability)),
          'Select one unambiguous activator.',
          { module = identity, capability = capability, activators = vim.deepcopy(candidates) },
          module.selection_sources[1]
        )
      else
        for _, activator in ipairs(candidates) do
          add_edge(module, activator, capability)
        end
      end
    end
    for _, capability in ipairs(definition.optional) do
      local candidates = activators[capability] or {}
      if #candidates == 1 or capability_catalog[capability].cardinality == 'compositional' then
        for _, activator in ipairs(candidates) do
          add_edge(module, activator, capability)
        end
      end
    end
  end

  for _, component in ipairs(cyclic_components(outgoing)) do
    local cycle = cycle_path(component, outgoing)
    local capabilities = {}
    local related_sources = {}
    for index = 1, #cycle - 1 do
      local edge = edge_capabilities[cycle[index] .. '\0' .. cycle[index + 1]]
      capabilities[index] = edge[1]
      if index > 1 then related_sources[#related_sources + 1] = selected[cycle[index]].selection_sources[1] end
    end
    capabilities[#capabilities + 1] = capabilities[1]
    diagnostics[#diagnostics + 1] = graph_diagnostic(
      'dependency.cycle',
      'Module dependencies contain a cycle.',
      'Remove one listed dependency or selection.',
      { modules = cycle, capabilities = capabilities },
      selected[cycle[1]].selection_sources[1],
      related_sources
    )
  end
  if #diagnostics > 0 then return nil, diagnostics end

  local indegree = {}
  local ready = {}
  for identity, module in pairs(selected) do
    indegree[identity] = #module.ordering_edges
    if indegree[identity] == 0 then ready[#ready + 1] = identity end
  end
  table.sort(ready)
  local modules = {}
  while #ready > 0 do
    local identity = table.remove(ready, 1)
    modules[#modules + 1] = selected[identity]
    for _, dependent in ipairs(outgoing[identity]) do
      indegree[dependent] = indegree[dependent] - 1
      if indegree[dependent] == 0 then
        ready[#ready + 1] = dependent
        table.sort(ready)
      end
    end
  end

  local capabilities = {}
  for identity, identities in pairs(activators) do
    local definition = capability_catalog[identity]
    local activator = identities[1]
    capabilities[#capabilities + 1] = {
      identity = identity,
      state = 'active',
      activator = activator,
      cardinality = definition.cardinality,
      responsible_integration = definition.responsible_integration,
      dependents = vim.deepcopy(outgoing[activator]),
      providers = vim.deepcopy(definition.providers),
      configuration = identity == 'editor' and vim.deepcopy(editor_configuration) or {},
      contributions = vim.deepcopy(selected[activator].contributions),
      actions = vim.deepcopy(definition.actions),
      degradation_reasons = {},
    }
  end
  table.sort(capabilities, function(left, right) return left.identity < right.identity end)
  return { modules = modules, capabilities = capabilities }, diagnostics
end

return M
