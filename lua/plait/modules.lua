local text = require('plait.text')

local M = {}

-- A local module is deliberately an opaque value: it can be selected, but is
-- not a second public declaration grammar that callers can manufacture.
local local_module_marker = {}

--- Create a local module declaration.
---@param declaration table
---@param declaration_source table
---@return table
function M.create_local(declaration, declaration_source)
  return setmetatable({ declaration = vim.deepcopy(declaration), source = vim.deepcopy(declaration_source) }, {
    __metatable = local_module_marker,
  })
end

---@param value any
---@return boolean
function M.is_local(value) return type(value) == 'table' and getmetatable(value) == local_module_marker end

---@param value any
---@return table|nil
function M.local_declaration(value)
  if M.is_local(value) then return value.declaration end
end

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
      'completion.hide',
      'completion.next',
      'completion.previous',
      'completion.scroll_documentation',
      'completion.select_and_accept',
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

--- Return the identity offered by a selected module value when it is known.
---@param value any
---@return string|nil
function M.identity(value)
  if M.is_builtin(value) then return value end
  if M.is_local(value) and type(value.declaration.name) == 'string' then return value.declaration.name end
end

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
---@param configuration table
---@param configuration_sources table<string, table[]>
---@return table|nil, table[]
function M.resolve(selections, selection_sources, configuration, configuration_sources, override_calls)
  local selected = {}
  for index, entry in ipairs(selections) do
    local identity = M.identity(entry)
    if not identity then return nil, {} end
    local module = selected[identity]
    if not module then
      local definition = module_catalog[identity]
      if not definition then
        local declaration = M.local_declaration(entry) or {}
        definition = {
          provides = vim.deepcopy(declaration.provides),
          requires = vim.deepcopy(declaration.requires),
          optional = {},
          contributions = {},
          local_declaration = declaration,
        }
        for seam, values in pairs(declaration.contribute) do
          for category, entries in pairs(values) do
            for contribution_identity in pairs(entries) do
              definition.contributions[#definition.contributions + 1] = seam
                .. '.'
                .. category
                .. '.'
                .. contribution_identity
            end
          end
        end
        table.sort(definition.contributions)
      end
      module = {
        identity = identity,
        state = 'active',
        selection_sources = {},
        provides = vim.deepcopy(definition.provides),
        requires = vim.deepcopy(definition.requires),
        ordering_edges = {},
        contributions = vim.deepcopy(definition.contributions),
        definition = definition,
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
      or {
        cardinality = 'exclusive',
        responsible_integration = capability,
        providers = {},
        actions = {},
      }
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
    local definition = module.definition
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
      elseif
        #candidates > 1
        and (capability_catalog[capability] or { cardinality = 'exclusive' }).cardinality == 'exclusive'
      then
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
      if
        #candidates == 1
        or (capability_catalog[capability] or { cardinality = 'exclusive' }).cardinality == 'compositional'
      then
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

  -- Contributions are keyed declarations, never an ordered stream.  Collect
  -- all peer values before considering owner operations so an override can
  -- deliberately settle an otherwise ambiguous peer identity.
  local contributed = {}
  for identity, module in pairs(selected) do
    local declaration = module.definition.local_declaration
    if declaration then
      for seam, categories in pairs(declaration.contribute) do
        for category, entries in pairs(categories) do
          for key, value in pairs(entries) do
            local contribution = seam .. '.' .. category .. '.' .. key
            contributed[contribution] = contributed[contribution] or {}
            contributed[contribution][#contributed[contribution] + 1] = {
              value = value,
              source = module.selection_sources[1],
              module = identity,
            }
          end
        end
      end
    end
  end

  local contribution_history = vim.deepcopy(contributed)
  local operations = {}
  local builtin_contributions = {
    ['language.servers.lua_ls'] = true,
    ['language.servers.tsc'] = true,
    ['formatting.formatters.stylua'] = true,
    ['formatting.formatters.oxfmt'] = true,
    ['formatting.by_filetype.lua'] = true,
    ['formatting.by_filetype.javascript'] = true,
    ['formatting.by_filetype.javascriptreact'] = true,
    ['formatting.by_filetype.typescript'] = true,
    ['formatting.by_filetype.typescriptreact'] = true,
    ['tooling.tools.lua-language-server'] = true,
    ['tooling.tools.stylua'] = true,
    ['tooling.tools.oxfmt'] = true,
    ['tooling.tools.tsc'] = true,
  }
  local function collect_operations(value, prefix, source)
    if type(value) ~= 'table' then
      diagnostics[#diagnostics + 1] = graph_diagnostic(
        'override.invalid',
        'Owner override has an invalid shape.',
        'Use one supported contribution seam.',
        {},
        source
      )
      return
    end
    for key, child in pairs(value) do
      local path = prefix == '' and key or prefix .. '.' .. key
      if type(key) ~= 'string' then
        diagnostics[#diagnostics + 1] = graph_diagnostic(
          'override.invalid',
          'Owner override has an invalid shape.',
          'Use string contribution identities.',
          {},
          source
        )
      elseif type(child) == 'table' and (child.kind == 'replace' or child.kind == 'disable') then
        operations[path] = operations[path] or {}
        operations[path][#operations[path] + 1] = { operation = child, source = source }
      else
        collect_operations(child, path, source)
      end
    end
  end
  for _, call in ipairs(override_calls or {}) do
    collect_operations(call.value, '', call.source)
  end

  local supported = {
    ['language.servers'] = true,
    ['formatting.formatters'] = true,
    ['formatting.by_filetype'] = true,
    ['tooling.tools'] = true,
  }
  for target, owner_operations in pairs(operations) do
    local prefix = target:match('^([^.]+%.[^.]+)')
    if not supported[prefix] then
      diagnostics[#diagnostics + 1] = graph_diagnostic(
        'override.unsupported',
        'Owner override targets an unsupported seam.',
        'Use language.servers, formatting.formatters, formatting.by_filetype, or tooling.tools.',
        { target = target },
        owner_operations[1].source
      )
    elseif not contributed[target] and not builtin_contributions[target] then
      diagnostics[#diagnostics + 1] = graph_diagnostic(
        'override.stale',
        'Owner override target does not exist.',
        'Choose an existing contribution identity.',
        { target = target },
        owner_operations[1].source
      )
    else
      local first = owner_operations[1]
      for index = 2, #owner_operations do
        local other = owner_operations[index]
        if
          first.operation.kind ~= other.operation.kind
          or (first.operation.kind == 'replace' and not vim.deep_equal(first.operation.value, other.operation.value))
        then
          diagnostics[#diagnostics + 1] = graph_diagnostic(
            'override.conflict',
            'Owner overrides disagree for one contribution.',
            'Keep one operation or make the operations equal.',
            { target = target },
            first.source,
            { other.source }
          )
        end
      end
      contributed[target] = first.operation.kind == 'disable' and {}
        or { { value = first.operation.value, source = first.source, module = 'owner' } }
    end
  end
  for target, peers in pairs(contributed) do
    if #peers > 1 then
      local first = peers[1]
      for index = 2, #peers do
        if not vim.deep_equal(first.value, peers[index].value) then
          diagnostics[#diagnostics + 1] = graph_diagnostic(
            'contribution.conflict',
            'Module contributions disagree for one identity.',
            'Use plait.replace() or make the declarations equal.',
            { target = target },
            first.source,
            { peers[index].source }
          )
          break
        end
      end
    end
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
      or {
        cardinality = 'exclusive',
        responsible_integration = identity,
        providers = {},
        actions = {},
      }
    local activator = identities[1]
    capabilities[#capabilities + 1] = {
      identity = identity,
      state = 'active',
      activator = activator,
      cardinality = definition.cardinality,
      responsible_integration = definition.responsible_integration,
      dependents = vim.deepcopy(outgoing[activator]),
      providers = vim.deepcopy(definition.providers),
      configuration = {
        values = vim.deepcopy(configuration[identity] or {}),
        sources = vim.deepcopy(configuration_sources[identity] or {}),
      },
      contributions = vim.deepcopy(selected[activator].contributions),
      actions = vim.deepcopy(definition.actions),
      degradation_reasons = {},
    }
  end
  table.sort(capabilities, function(left, right) return left.identity < right.identity end)
  -- `definition` is resolver-only metadata, never part of the closed public
  -- module record.
  for _, module in ipairs(modules) do
    module.definition = nil
  end
  local effective_contributions = {}
  local seen_contributions = {}
  for _, module in ipairs(modules) do
    for _, contribution in ipairs(module.contributions) do
      if contributed[contribution] == nil and not seen_contributions[contribution] then
        effective_contributions[#effective_contributions + 1] = contribution
        seen_contributions[contribution] = true
      end
    end
  end
  for target, peers in pairs(contributed) do
    if #peers > 0 and not seen_contributions[target] then
      effective_contributions[#effective_contributions + 1] = target
      seen_contributions[target] = true
    end
  end
  table.sort(effective_contributions)
  local contribution_values = {}
  for target, peers in pairs(contributed) do
    if #peers == 1 then contribution_values[target] = vim.deepcopy(peers[1]) end
  end
  return {
    modules = modules,
    capabilities = capabilities,
    effective_contributions = effective_contributions,
    contribution_values = contribution_values,
    contribution_history = contribution_history,
    contribution_overrides = vim.deepcopy(operations),
  },
    diagnostics
end

return M
