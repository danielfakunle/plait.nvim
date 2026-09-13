local canonical = require('plait.canonical')
local compatibility = require('plait.compatibility')
local text = require('plait.text')

local M = {}

local target_schema = {
  language = { ['vim.lsp'] = { global = true, servers = 'dynamic' } },
  completion = { ['blink.cmp'] = { setup = true } },
  formatting = { ['conform.nvim'] = { setup = true, formatters = 'dynamic' } },
  tooling = { ['mason.nvim'] = { setup = true } },
}

--- Return a safe description of an invalid opaque value.
---@param value any
---@return string
local function observed(value)
  if type(value) == 'number' and (value ~= value or value == math.huge or value == -math.huge) then
    return 'non-finite number'
  end
  if type(value) == 'table' and getmetatable(value) ~= nil then return 'table with metatable' end
  return type(value)
end

--- Build a provider validation diagnostic.
---@param code string
---@param summary string
---@param repair string
---@param details table
---@param declaration_source table
---@param path string
---@param related_sources? table[]
---@return table
local function diagnostic(code, summary, repair, details, declaration_source, path, related_sources)
  local source = vim.deepcopy(declaration_source)
  source._provider_parts = nil
  source.file = text.normalize(source.file)
  source.path = text.normalize(path)
  local public_related_sources = {}
  for index, related_source in ipairs(related_sources or {}) do
    public_related_sources[index] = vim.deepcopy(related_source)
    public_related_sources[index]._provider_parts = nil
  end
  return {
    code = code,
    severity = 'error',
    summary = summary,
    repair = repair,
    source = source,
    related_sources = public_related_sources,
    details = details,
  }
end

--- Classify a non-empty table as a dense array or map.
---@param value table
---@return 'array'|'map'|nil
local function table_kind(value)
  local count, maximum, numeric, strings = 0, 0, false, false
  for key in pairs(value) do
    count = count + 1
    if type(key) == 'number' then
      numeric = true
      if key < 1 or key % 1 ~= 0 then return nil end
      maximum = math.max(maximum, key)
    elseif type(key) == 'string' then
      strings = true
    else
      return nil
    end
  end
  if numeric and strings then return nil end
  if numeric then return maximum == count and 'array' or nil end
  return 'map'
end

--- Normalize an opaque provider value and record each atomic source.
---@param value any
---@param path string
---@param source table
---@param diagnostics table[]
---@param sources table[]
---@param ancestors table<table, boolean>
---@param parts? string[]
---@return any
local function normalize(value, path, source, diagnostics, sources, ancestors, parts)
  parts = parts or {}
  local function record_source()
    local item = vim.tbl_extend('force', vim.deepcopy(source), { path = path })
    item._provider_parts = vim.deepcopy(parts)
    sources[#sources + 1] = item
  end
  local kind = type(value)
  if kind == 'string' then
    if text.valid_utf8(value) then
      record_source()
      return value
    end
  elseif kind == 'boolean' or kind == 'function' then
    record_source()
    return value
  elseif kind == 'number' then
    if value == value and value ~= math.huge and value ~= -math.huge then
      record_source()
      return value == 0 and 0 or value
    end
  elseif kind == 'table' and getmetatable(value) == nil and not ancestors[value] then
    local shape = table_kind(value)
    if shape then
      ancestors[value] = true
      local result = {}
      if shape == 'array' then
        for index = 1, #value do
          local child_parts = vim.deepcopy(parts)
          child_parts[#child_parts + 1] = tostring(index)
          result[index] =
            normalize(value[index], path .. '[' .. index .. ']', source, diagnostics, sources, ancestors, child_parts)
        end
        canonical.mark_array(result)
        if #value == 0 then record_source() end
      else
        local keys = vim.tbl_keys(value)
        table.sort(keys)
        for _, key in ipairs(keys) do
          if not text.valid_utf8(key) then
            shape = nil
            break
          end
          local child_parts = vim.deepcopy(parts)
          child_parts[#child_parts + 1] = key
          result[key] = normalize(value[key], path .. '.' .. key, source, diagnostics, sources, ancestors, child_parts)
        end
        if next(value) == nil then record_source() end
      end
      ancestors[value] = nil
      if shape then return result end
    end
  end
  diagnostics[#diagnostics + 1] = diagnostic(
    'config.invalid',
    'Invalid provider value at ' .. text.normalize(path) .. '.',
    'Use an admissible opaque provider value.',
    { path = text.normalize(path), expected = 'an admissible opaque provider value', observed = observed(value) },
    source,
    path
  )
  return nil
end

--- Compare opaque values, including functions by object identity.
---@param left any
---@param right any
---@return boolean
local function equal(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= 'table' then return left == right or (left == 0 and right == 0) end
  local left_keys, right_keys = vim.tbl_keys(left), vim.tbl_keys(right)
  if #left_keys ~= #right_keys then return false end
  for key, value in pairs(left) do
    if rawget(right, key) == nil or not equal(value, right[key]) then return false end
  end
  return true
end

--- Whether two dotted provider paths overlap at an ancestor boundary.
---@param left string
---@param right string
---@return boolean
local function paths_overlap(left, right)
  return left == right
    or left:sub(1, #right + 1) == right .. '.'
    or left:sub(1, #right + 1) == right .. '['
    or right:sub(1, #left + 1) == left .. '.'
    or right:sub(1, #left + 1) == left .. '['
end

--- Recursively union two normalized provider maps.
---@param target table
---@param incoming table
---@param path string
---@param source table
---@param diagnostics table[]
---@param existing_sources table[]
local function merge(target, incoming, path, source, diagnostics, existing_sources)
  for key, value in pairs(incoming) do
    local child_path = path .. '.' .. key
    local current = rawget(target, key)
    if current == nil then
      target[key] = value
    elseif
      type(current) == 'table'
      and type(value) == 'table'
      and table_kind(current) == 'map'
      and table_kind(value) == 'map'
    then
      merge(current, value, child_path, source, diagnostics, existing_sources)
    elseif not equal(current, value) then
      local related = {}
      for _, existing_source in ipairs(existing_sources) do
        if paths_overlap(existing_source.path, child_path) then
          related[#related + 1] = vim.deepcopy(existing_source)
        end
      end
      diagnostics[#diagnostics + 1] = diagnostic(
        'contribution.conflict',
        'Provider declarations disagree for one path.',
        'Keep one value or make the provider declarations equal.',
        { target = child_path },
        source,
        child_path,
        related
      )
    end
  end
end

--- Split a provider path into its dotted components.
---@param path string
---@return string[]
local function split_path(path)
  local result = {}
  for part in path:gmatch('[^.]+') do
    result[#result + 1] = part
  end
  return result
end

--- Test whether possibly-wildcarded path parts prefix another path.
---@param prefix_parts string[]
---@param path_parts string[]
---@return boolean
local function parts_are_prefix(prefix_parts, path_parts)
  if #prefix_parts > #path_parts then return false end
  for index, part in ipairs(prefix_parts) do
    local alternatives = part:match('^{(.+)}$')
    if alternatives then
      local found = false
      for option in alternatives:gmatch('[^,]+') do
        if option == path_parts[index] then found = true end
      end
      if not found then return false end
    elseif part ~= path_parts[index] then
      local path_alternatives = path_parts[index]:match('^{(.+)}$')
      local found = false
      if path_alternatives then
        for option in path_alternatives:gmatch('[^,]+') do
          if option == part then found = true end
        end
      end
      if not found then return false end
    end
  end
  return true
end

--- Test whether a possibly-wildcarded provider path prefixes path parts.
---@param candidate_prefix string
---@param path_parts string[]
---@return boolean
local function path_is_prefix(candidate_prefix, path_parts)
  return parts_are_prefix(split_path(candidate_prefix), path_parts)
end

--- Find a guarded path touched directly, below a prefix, or through an ancestor replacement.
---@param provider string
---@param target_name string
---@param path_parts string[]
---@return string|nil
local function guarded(provider, target_name, path_parts)
  local metadata = compatibility.guards[provider]
  if not metadata then return nil end
  local prefixes, leaves = vim.deepcopy(metadata.prefixes or {}), vim.deepcopy(metadata.leaves or {})
  if provider == 'vim.lsp' and target_name ~= 'global' then
    local target = metadata.targets[target_name] or metadata.targets['*']
    if target then vim.list_extend(leaves, target.leaves or {}) end
  elseif provider == 'conform.nvim' and target_name ~= 'setup' then
    local target = metadata.formatter_targets[target_name] or metadata.formatter_targets['*']
    leaves = target and metadata.formatter_leaves or {}
    prefixes = {}
  end
  for _, guard in ipairs(prefixes) do
    if path_is_prefix(guard, path_parts) or parts_are_prefix(path_parts, split_path(guard)) then return guard end
  end
  for _, guard in ipairs(leaves) do
    if path_is_prefix(guard, path_parts) or parts_are_prefix(path_parts, split_path(guard)) then return guard end
  end
  return nil
end

--- Collect active capability and dynamic provider-target identities.
---@param resolution table
---@return table
local function effective_targets(resolution)
  local result = { servers = {}, formatters = {} }
  for _, contribution in ipairs(resolution.effective_contributions) do
    local server = contribution:match('^language%.servers%.(.+)$')
    local formatter = contribution:match('^formatting%.formatters%.(.+)$')
    if server then result.servers[server] = true end
    if formatter then result.formatters[formatter] = true end
  end
  for _, capability in ipairs(resolution.capabilities) do
    result[capability.identity] = true
  end
  return result
end

--- Validate, compose, and attach provider escape hatches to capability records.
---@param calls table[]
---@param resolution table
---@return table[]
function M.resolve(calls, resolution)
  local diagnostics, records = {}, {}
  vim.list_extend(diagnostics, require('plait.provider_qualification').validate(resolution, diagnostic))
  local effective = effective_targets(resolution)
  local by_key = {}
  for _, call in ipairs(calls) do
    local root = call.value
    if type(root) ~= 'table' or getmetatable(root) ~= nil then
      diagnostics[#diagnostics + 1] = diagnostic(
        'config.invalid',
        'Invalid provider declaration.',
        'Use the supported provider schema.',
        {},
        call.source,
        'providers'
      )
    else
      for capability, providers in pairs(root) do
        local capability_schema = target_schema[capability]
        if
          type(capability) ~= 'string'
          or not capability_schema
          or not effective[capability]
          or type(providers) ~= 'table'
        then
          diagnostics[#diagnostics + 1] = diagnostic(
            'config.invalid',
            'Invalid provider target.',
            'Use one supported capability/provider target.',
            { target = tostring(capability) },
            call.source,
            'providers.' .. tostring(capability)
          )
        else
          for provider, targets in pairs(providers) do
            local provider_schema = capability_schema[provider]
            if not provider_schema or type(targets) ~= 'table' then
              diagnostics[#diagnostics + 1] = diagnostic(
                'config.invalid',
                'Invalid provider target.',
                'Use one supported capability/provider target.',
                { target = capability .. '.' .. tostring(provider) },
                call.source,
                'providers.' .. capability .. '.' .. tostring(provider)
              )
            else
              for category, declarations in pairs(targets) do
                local category_schema = provider_schema[category]
                local dynamic = category_schema == 'dynamic'
                if not category_schema or type(declarations) ~= 'table' then
                  diagnostics[#diagnostics + 1] = diagnostic(
                    'config.invalid',
                    'Invalid provider target.',
                    'Use one supported provider target.',
                    { target = capability .. '.' .. provider .. '.' .. tostring(category) },
                    call.source,
                    'providers.' .. capability .. '.' .. provider .. '.' .. tostring(category)
                  )
                else
                  local targets_to_add = dynamic and declarations or { [category] = declarations }
                  for target_name, payload in pairs(targets_to_add) do
                    local valid_identity = not dynamic or effective[category][target_name]
                    local base = 'providers.' .. capability .. '.' .. provider .. '.' .. category
                    if dynamic then base = base .. '.' .. tostring(target_name) end
                    local replacement_guard = dynamic and guarded(provider, target_name, {}) or nil
                    if type(target_name) ~= 'string' or not valid_identity then
                      diagnostics[#diagnostics + 1] = diagnostic(
                        'config.invalid',
                        'Invalid provider target.',
                        'Target an effective server or formatter identity.',
                        { target = base },
                        call.source,
                        base
                      )
                    elseif
                      (type(payload) ~= 'table' or getmetatable(payload) ~= nil or table_kind(payload) ~= 'map')
                      and dynamic
                      and replacement_guard
                    then
                      diagnostics[#diagnostics + 1] = diagnostic(
                        'provider.guarded_path',
                        'Provider payload replaces a target containing guarded paths.',
                        'Remove the replacement and configure disjoint provider settings instead.',
                        {
                          target = provider .. '.' .. target_name,
                          path = '',
                          generated_source = {
                            file = 'plait:v0.1/' .. provider,
                            line = 0,
                            path = replacement_guard,
                          },
                        },
                        call.source,
                        base
                      )
                    elseif type(payload) ~= 'table' or getmetatable(payload) ~= nil or table_kind(payload) ~= 'map' then
                      diagnostics[#diagnostics + 1] = diagnostic(
                        'config.invalid',
                        'Invalid provider payload.',
                        'Use a plain string-keyed map.',
                        { target = base },
                        call.source,
                        base
                      )
                    else
                      local sources = {}
                      local normalized = normalize(payload, base, call.source, diagnostics, sources, {})
                      local key = canonical.encode_array({ capability, provider, target_name })
                      local record = by_key[key]
                      if not record then
                        record = {
                          identity = provider,
                          target = target_name,
                          value = {},
                          sources = {},
                          opaque = true,
                          revision_coupled = true,
                        }
                        by_key[key], records[#records + 1] = record, record
                      end
                      if normalized then
                        merge(record.value, normalized, base, call.source, diagnostics, record.sources)
                      end
                      vim.list_extend(record.sources, sources)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  for _, record in ipairs(records) do
    table.sort(record.sources, function(a, b)
      if a.path ~= b.path then return a.path < b.path end
      if a.file ~= b.file then return a.file < b.file end
      return a.line < b.line
    end)
    for _, item_source in ipairs(record.sources) do
      local value_parts = item_source._provider_parts
      if value_parts then
        local value_path = table.concat(value_parts, '.')
        local guard = guarded(record.identity, record.target, value_parts)
        if guard then
          local generated = { file = 'plait:v0.1/' .. record.identity, line = 0, path = guard }
          diagnostics[#diagnostics + 1] = diagnostic(
            'provider.guarded_path',
            'Provider payload touches a guarded path.',
            'Remove the path and configure the capability-level setting instead.',
            { target = record.identity .. '.' .. record.target, path = value_path, generated_source = generated },
            item_source,
            item_source.path,
            { generated }
          )
        end
        item_source._provider_parts = nil
      end
    end
  end
  table.sort(records, function(a, b)
    if a.identity ~= b.identity then return a.identity < b.identity end
    return a.target < b.target
  end)
  for _, capability in ipairs(resolution.capabilities) do
    capability.configuration.providers = {}
    for _, record in ipairs(records) do
      if target_schema[capability.identity] and target_schema[capability.identity][record.identity] then
        capability.configuration.providers[#capability.configuration.providers + 1] = record
      end
    end
    canonical.mark_array(capability.configuration.providers)
  end
  return diagnostics
end

return M
