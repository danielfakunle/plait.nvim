local operations = require('plait.operations')
local state = require('plait.state')
local tools = require('plait.tools')
local effect_record = require('plait.effects')
local compatibility = require('plait.compatibility')

local M = {}

local builtin_formatters = { stylua = 'stylua', oxfmt = 'oxfmt' }
local builtin_chains = {
  lua = { 'stylua' },
  javascript = { 'oxfmt' },
  javascriptreact = { 'oxfmt' },
  typescript = { 'oxfmt' },
  typescriptreact = { 'oxfmt' },
}

--- Resolve formatter and filetype contributions for an effective plan.
---@param resolution table
---@return table
function M.resolve(resolution)
  local result = { formatters = {}, by_filetype = {} }
  for identity, tool in pairs(builtin_formatters) do
    if vim.list_contains(resolution.effective_contributions, 'formatting.formatters.' .. identity) then
      result.formatters[identity] = { tool = tool }
    end
  end
  for filetype, chain in pairs(builtin_chains) do
    if vim.list_contains(resolution.effective_contributions, 'formatting.by_filetype.' .. filetype) then
      result.by_filetype[filetype] = vim.deepcopy(chain)
    end
  end
  for target, peer in pairs(resolution.contribution_values or {}) do
    local formatter = target:match('^formatting%.formatters%.(.+)$')
    local filetype = target:match('^formatting%.by_filetype%.(.+)$')
    if formatter then result.formatters[formatter] = vim.deepcopy(peer.value) end
    if filetype then result.by_filetype[filetype] = vim.deepcopy(peer.value) end
  end
  return result
end

--- Explain effective and explicitly disabled chains with declaration provenance.
---@param resolution table
---@return table[]
function M.inspect_chains(resolution)
  local chains = M.resolve(resolution).by_filetype
  local records = {}
  for target in pairs(resolution.contribution_overrides or {}) do
    local filetype = target:match('^formatting%.by_filetype%.(.+)$')
    if filetype and chains[filetype] == nil then chains[filetype] = {} end
  end
  local filetypes = vim.tbl_keys(chains)
  table.sort(filetypes)
  for _, filetype in ipairs(filetypes) do
    local target = 'formatting.by_filetype.' .. filetype
    local overrides = (resolution.contribution_overrides or {})[target]
    local peer = (resolution.contribution_values or {})[target]
    local sources, declaration = {}, peer and peer.module or ''
    if overrides then
      declaration = 'owner override (' .. overrides[1].operation.kind .. ')'
      for _, override in ipairs(overrides) do
        sources[#sources + 1] = vim.deepcopy(override.source)
      end
    elseif peer then
      sources[1] = vim.deepcopy(peer.source)
    else
      for _, module in ipairs(resolution.modules) do
        if vim.list_contains(module.contributions, target) then
          declaration = module.identity
          vim.list_extend(sources, vim.deepcopy(module.selection_sources))
        end
      end
    end
    records[#records + 1] = {
      filetype = filetype,
      chain = chains[filetype],
      state = overrides and overrides[1].operation.kind == 'disable' and 'disabled' or 'effective',
      declaration = declaration,
      reason = overrides and 'Explicit owner override supersedes module contributions.' or 'Module contribution.',
      sources = sources,
    }
  end
  return records
end

--- Declare the formatting capability's complete managed effect family.
---@param sources table[]
---@return table[]
function M.effects(sources)
  local function effect(identity, stage, provider, dependencies)
    return effect_record.new('formatting', identity, stage, provider, dependencies, sources)
  end
  return {
    effect('formatting/package/conform.nvim', 2, 'vim.pack', {}),
    effect(
      'formatting/provider-setup',
      3,
      'conform.nvim',
      { 'formatting/package/conform.nvim', 'tooling/tool-resolution' }
    ),
    effect('formatting/actions-and-mapping', 4, 'conform.nvim', { 'formatting/provider-setup' }),
  }
end

--- Find one effective tool record.
---@param snapshot table
---@param identity string
---@return table|nil
local function tool_record(snapshot, identity)
  for _, record in ipairs(snapshot.tools or {}) do
    if record.identity == identity then return record end
  end
end

--- Return the configured external chain and all unavailable members.
---@param snapshot table
---@param buffer integer
---@return string[], table[]
local function chain_state(snapshot, buffer)
  local filetype = vim.bo[buffer].filetype
  local chain = vim.deepcopy(state.formatting_by_filetype[filetype] or {})
  local unavailable = {}
  for _, formatter in ipairs(chain) do
    local declaration = state.formatting_formatters[formatter]
    local record = declaration and tool_record(snapshot, declaration.tool)
    if not record or record.state ~= 'satisfied' then
      unavailable[#unavailable + 1] = {
        formatter = formatter,
        tool = declaration and declaration.tool or '',
        state = record and record.state or 'absent',
      }
    end
  end
  return chain, unavailable
end

--- Return whether a managed LSP client can format this buffer.
---@param buffer integer
---@return boolean
local function has_lsp_formatter(buffer)
  if not state.language_active then return false end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
    if client:supports_method('textDocument/formatting', buffer) then return true end
  end
  return false
end

--- Resolve the shared external-chain and LSP fallback policy for one buffer.
---@param snapshot table
---@param buffer integer
---@param configuration table
---@return string[], table[], boolean
local function format_policy(snapshot, buffer, configuration)
  local chain, unavailable = chain_state(snapshot, buffer)
  local lsp = #chain == 0 and configuration.lsp_fallback == 'if_no_formatter' and has_lsp_formatter(buffer)
  return chain, unavailable, lsp
end

--- Validate and translate the closed public range schema to Conform's range.
---@param opts any
---@return table|nil, table|nil
local function range_opts(opts)
  if opts == nil then return nil, nil end
  if type(opts) ~= 'table' or getmetatable(opts) ~= nil then
    error('plait: formatting.format expects an options table', 3)
  end
  for key in pairs(opts) do
    if key ~= 'range' then error('plait: formatting.format options contain an unknown key', 3) end
  end
  if opts.range == nil then return nil, nil end
  local range = opts.range
  if type(range) ~= 'table' or getmetatable(range) ~= nil then error('plait: formatting.format range is invalid', 3) end
  for key in pairs(range) do
    if key ~= 'start' and key ~= 'end_' then error('plait: formatting.format range is invalid', 3) end
  end
  local function position(value)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return nil end
    for key in pairs(value) do
      if key ~= 'line' and key ~= 'character' then return nil end
    end
    if
      type(value.line) ~= 'number'
      or value.line < 0
      or value.line % 1 ~= 0
      or type(value.character) ~= 'number'
      or value.character < 0
      or value.character % 1 ~= 0
    then
      return nil
    end
    return { line = value.line, character = value.character }
  end
  local start, end_ = position(range.start), position(range.end_)
  if
    not start
    or not end_
    or end_.line < start.line
    or (end_.line == start.line and end_.character < start.character)
  then
    error('plait: formatting.format range is invalid', 3)
  end
  local public = { start = start, end_ = end_ }
  return public, { start = { start.line + 1, start.character }, ['end'] = { end_.line + 1, end_.character } }
end

--- Format the current buffer through the qualified Conform integration.
---@param opts? table
---@return table
function M.format(opts)
  local public_range, conform_range = range_opts(opts)
  local operation = 'formatting.format'
  if not state.formatting_active then
    return {
      status = 'unavailable',
      operation = operation,
      reason = 'capability_inactive',
      details = { capability = 'formatting' },
    }
  end
  local snapshot = assert(state.snapshot)
  local buffer = vim.api.nvim_get_current_buf()
  local chain, unavailable, lsp = format_policy(snapshot, buffer, state.formatting_configuration)
  if #unavailable > 0 then
    return {
      status = 'unavailable',
      operation = operation,
      reason = 'formatter_chain_unavailable',
      details = { buffer = buffer, unavailable = unavailable },
    }
  end
  if #chain == 0 and not lsp then
    return { status = 'unavailable', operation = operation, reason = 'no_formatter', details = { buffer = buffer } }
  end
  local details = { buffer = buffer, range = public_range or vim.NIL, chain = vim.deepcopy(chain) }
  return operations.start({
    operation = operation,
    targets = { 'buffer:' .. buffer },
    work = function(done)
      local format_options = {
        bufnr = buffer,
        async = true,
        timeout_ms = state.formatting_configuration.timeout_ms,
        formatters = #chain > 0 and vim.deepcopy(chain) or nil,
        lsp_format = lsp and 'fallback' or 'never',
        quiet = true,
        range = conform_range,
      }
      local callback_error
      local callback_completed = false
      local returned = false
      local function completed(err)
        callback_error = err
        callback_completed = true
        if returned then done(err == nil) end
      end
      local ok, attempted = pcall(require('conform').format, format_options, completed)
      returned = true
      if not ok or attempted == false then
        done(false)
      elseif callback_completed then
        done(callback_error == nil)
      end
    end,
    success_details = function() return vim.deepcopy(details) end,
    started_details = details,
    failure_message = 'Formatting operation failed.',
  })
end

--- Build a zero-based end-exclusive public range from the current visual selection.
---@return table
local function visual_range()
  local start, finish = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  local start_line, start_character = start[2] - 1, math.max(start[3] - 1, 0)
  local end_line, end_character = finish[2] - 1, finish[3]
  return {
    start = { line = start_line, character = start_character },
    end_ = { line = end_line, character = end_character },
  }
end

--- Return mapping identities that this formatting effect would overwrite.
---@param identity string
---@param configuration table
---@return table[]
function M.preflight_effect(identity, configuration)
  if identity ~= 'formatting/actions-and-mapping' or configuration.mappings.format == false then return {} end
  local collisions = {}
  for _, mode in ipairs({ 'n', 'x' }) do
    local observed = vim.fn.maparg(configuration.mappings.format, mode, false, true)
    if next(observed) then
      collisions[#collisions + 1] = {
        identity = 'mapping:' .. mode .. ':' .. configuration.mappings.format .. ':global',
        observed_owner = 'mapping',
      }
    end
  end
  return collisions
end

--- Merge accepted provider payloads into the generated Conform setup.
---@param configuration table
---@param effective_plan table
---@return table
local function setup_options(configuration, effective_plan)
  local setup = {}
  local formatter_payloads = {}
  for _, provider in ipairs(configuration.providers or {}) do
    if provider.identity == 'conform.nvim' and provider.target == 'setup' then
      setup = vim.tbl_deep_extend('force', setup, provider.value)
    elseif provider.identity == 'conform.nvim' then
      formatter_payloads[provider.target] = provider.value
    end
  end
  local requirements = require('plait.plan').formatting_requirements(effective_plan)
  state.formatting_formatters = vim.deepcopy(requirements.formatters)
  state.formatting_by_filetype = vim.deepcopy(requirements.by_filetype)
  state.formatting_configuration = vim.deepcopy(configuration)
  local definitions = {}
  for identity, declaration in pairs(requirements.formatters) do
    local record = tool_record(effective_plan, declaration.tool)
    local command = record and tools.command(record) or nil
    if command then
      record = assert(record)
      local qualification = assert(compatibility.qualified_definitions.formatting[identity])
      local qualified = require('conform.formatters.' .. qualification.definition)
      if type(qualified) ~= 'table' then error('qualified formatter definition is invalid') end
      if qualification.command == 'static' then
        if type(qualified.command) ~= 'string' then
          error('qualified formatter definition must have a static command')
        end
        if qualified.command ~= record.executable then
          error('qualified formatter executable does not match its tool')
        end
      elseif qualification.command == 'dynamic' then
        if type(qualified.command) ~= 'function' then
          error('qualified formatter definition must have a dynamic command')
        end
      else
        error('qualified formatter command qualification is invalid')
      end
      definitions[identity] = vim.tbl_deep_extend('force', vim.deepcopy(qualified), formatter_payloads[identity] or {})
      definitions[identity].command = command[1]
    end
  end
  setup.formatters_by_ft = vim.deepcopy(requirements.by_filetype)
  setup.formatters = definitions
  setup.default_format_opts = {
    timeout_ms = configuration.timeout_ms,
    lsp_format = configuration.lsp_fallback == 'if_no_formatter' and 'fallback' or 'never',
  }
  setup.notify_on_error = false
  setup.notify_no_formatters = false
  if configuration.on_save then
    setup.format_on_save = function(buffer)
      local chain, unavailable, lsp = format_policy(state.snapshot or effective_plan, buffer, configuration)
      if #unavailable > 0 then return nil end
      if #chain == 0 and not lsp then return nil end
      return {
        timeout_ms = configuration.timeout_ms,
        formatters = #chain > 0 and chain or nil,
        lsp_format = lsp and 'fallback' or 'never',
        quiet = true,
      }, function(err)
        if err then
          require('plait.feedback').automatic_failure(
            'Plait formatting operation failed.',
            'Inspect :Plait inspect tools and diagnostics, repair the formatter, then retry.'
          )
        end
      end
    end
  else
    setup.format_on_save = nil
  end
  setup.format_after_save = nil
  return setup
end

--- Apply one formatting effect by stable identity.
---@param identity string
---@param configuration table
---@param effective_plan table
function M.apply_effect(identity, configuration, effective_plan)
  if identity == 'formatting/provider-setup' then
    require('conform').setup(setup_options(configuration, effective_plan))
  elseif identity == 'formatting/actions-and-mapping' then
    if configuration.mappings.format ~= false then
      vim.keymap.set('n', configuration.mappings.format, M.format)
      vim.keymap.set('x', configuration.mappings.format, function() M.format({ range = visual_range() }) end)
    end
  end
end

M.actions = { format = M.format }
M.integration = {
  implementation = M,
  failure_message = 'Managed formatting effect failed.',
  activation_effect = 'formatting/actions-and-mapping',
  activate = function() state.formatting_active = true end,
}

return M
