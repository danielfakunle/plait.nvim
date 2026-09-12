local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

local requests = {
  definition = { method = 'textDocument/definition', invoke = function() vim.lsp.buf.definition() end },
  references = { method = 'textDocument/references', invoke = function() vim.lsp.buf.references() end },
  hover = { method = 'textDocument/hover', invoke = function() vim.lsp.buf.hover() end },
  rename = { method = 'textDocument/rename', invoke = function() vim.lsp.buf.rename() end },
  code_action = { method = 'textDocument/codeAction', invoke = function() vim.lsp.buf.code_action() end },
}

--- Return the current zero-based buffer position.
---@return table
local function position()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return { line = cursor[1] - 1, character = cursor[2] }
end

--- Return an unavailable result when the language capability has not been applied.
---@param operation string
---@return table|nil
local function inactive(operation)
  if state.language_active then return nil end
  return {
    status = 'unavailable',
    operation = operation,
    reason = 'capability_inactive',
    details = { capability = 'language' },
  }
end

--- Return a UTC RFC 3339 timestamp with millisecond precision.
---@return string
local function timestamp()
  local seconds, microseconds = vim.uv.gettimeofday()
  return os.date('!%Y-%m-%dT%H:%M:%S', seconds) .. ('.%03dZ'):format(math.floor(microseconds / 1000))
end

--- Publish the terminal diagnostic for an accepted language action.
---@param operation table
---@param succeeded boolean
local function publish_diagnostic(operation, succeeded)
  local code = succeeded and 'operation.succeeded' or 'operation.failed'
  local details = {
    operation_id = operation.identity,
    operation = operation.operation,
    targets = vim.deepcopy(operation.targets),
  }
  if not succeeded then details.message = 'Language action failed.' end
  local diagnostic = {
    code = code,
    severity = succeeded and 'info' or 'error',
    summary = succeeded and ('Operation ' .. operation.identity .. ' succeeded.')
      or ('Operation ' .. operation.identity .. ' failed.'),
    repair = succeeded and '' or 'Repair the reported target/environment and invoke a new operation.',
    source = nil,
    related_sources = {},
    details = details,
  }
  state.operation_diagnostics[#state.operation_diagnostics + 1] = vim.deepcopy(diagnostic)
  validation.sort_diagnostics(state.operation_diagnostics)
  if state.snapshot then
    state.snapshot.diagnostics[#state.snapshot.diagnostics + 1] = vim.deepcopy(diagnostic)
    validation.sort_diagnostics(state.snapshot.diagnostics)
  end
end

--- Accept and track one asynchronous native LSP action.
---@param name string
---@return table
local function request(name)
  local operation_name = 'language.' .. name
  local unavailable = inactive(operation_name)
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local details = { buffer = buffer, position = position() }
  local clients = vim.lsp.get_clients({ bufnr = buffer })
  if #clients == 0 then
    return { status = 'unavailable', operation = operation_name, reason = 'no_client', details = details }
  end
  local supported = false
  for _, client in ipairs(clients) do
    if client:supports_method(requests[name].method, buffer) then
      supported = true
      break
    end
  end
  if not supported then
    return { status = 'unavailable', operation = operation_name, reason = 'client_unsupported', details = details }
  end

  state.next_operation_id = state.next_operation_id + 1
  local operation_id = ('op-%08d'):format(state.next_operation_id)
  local operation = {
    identity = operation_id,
    operation = operation_name,
    state = 'pending',
    started_at = timestamp(),
    completed_at = vim.NIL,
    targets = { 'buffer:' .. buffer },
    result = vim.NIL,
    error = vim.NIL,
    diagnostic_codes = {},
  }
  state.operations[#state.operations + 1] = operation
  if state.snapshot then state.snapshot.operations = state.operations end
  vim.schedule(function()
    local ok = pcall(vim.api.nvim_buf_call, buffer, requests[name].invoke)
    operation.completed_at = timestamp()
    if ok then
      operation.state = 'succeeded'
      operation.result = { status = 'performed', operation = operation_name, details = vim.deepcopy(details) }
      operation.error = vim.NIL
      operation.diagnostic_codes = { 'operation.succeeded' }
    else
      operation.state = 'failed'
      operation.result = vim.NIL
      operation.error = { reason = 'execution_failed', message = 'Language action failed.' }
      operation.diagnostic_codes = { 'operation.failed' }
    end
    publish_diagnostic(operation, ok)
  end)
  return {
    status = 'started',
    operation = operation_name,
    operation_id = operation_id,
    details = vim.deepcopy(details),
  }
end

--- Navigate to one native diagnostic.
---@param name string
---@param count integer
---@return table
local function navigate(name, count)
  local operation = 'language.' .. name
  local unavailable = inactive(operation)
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local target = vim.diagnostic.jump({ count = count, float = true })
  if not target then
    return { status = 'unavailable', operation = operation, reason = 'no_diagnostics', details = { buffer = buffer } }
  end
  return { status = 'performed', operation = operation, details = { buffer = buffer } }
end

M.actions = {
  definition = function() return request('definition') end,
  references = function() return request('references') end,
  hover = function() return request('hover') end,
  rename = function() return request('rename') end,
  code_action = function() return request('code_action') end,
  previous_diagnostic = function() return navigate('previous_diagnostic', -1) end,
  next_diagnostic = function() return navigate('next_diagnostic', 1) end,
}

--- Install one configured buffer-local mapping.
---@param modes string[]|string
---@param lhs string|false
---@param callback function
---@param buffer integer
local function map(modes, lhs, callback, buffer)
  if lhs ~= false then vim.keymap.set(modes, lhs, callback, { buffer = buffer }) end
end

--- Install mappings supported by clients attached to one buffer.
---@param buffer integer
---@param mappings table
function M.attach(buffer, mappings)
  local clients = vim.lsp.get_clients({ bufnr = buffer })
  for name, descriptor in pairs(requests) do
    local supported = false
    for _, client in ipairs(clients) do
      if client:supports_method(descriptor.method, buffer) then
        supported = true
        break
      end
    end
    if supported then map(name == 'code_action' and { 'n', 'x' } or 'n', mappings[name], M.actions[name], buffer) end
  end
end

--- Return buffer-local mapping identities that this language effect would overwrite.
---@param identity string
---@param configuration table
---@return table[]
function M.preflight_effect(identity, configuration)
  if identity ~= 'language/actions-and-mappings' then return {} end
  local buffer = vim.api.nvim_get_current_buf()
  local mappings = {
    { { 'n' }, configuration.mappings.previous_diagnostic },
    { { 'n' }, configuration.mappings.next_diagnostic },
  }
  local clients = vim.lsp.get_clients({ bufnr = buffer })
  for name, descriptor in pairs(requests) do
    for _, client in ipairs(clients) do
      if client:supports_method(descriptor.method, buffer) then
        mappings[#mappings + 1] = { name == 'code_action' and { 'n', 'x' } or { 'n' }, configuration.mappings[name] }
        break
      end
    end
  end
  local collisions = {}
  for _, mapping in ipairs(mappings) do
    if mapping[2] ~= false then
      for _, mode in ipairs(mapping[1]) do
        local observed = vim.fn.maparg(mapping[2], mode, false, true)
        if next(observed) and observed.buffer == 1 then
          collisions[#collisions + 1] = {
            identity = 'mapping:' .. mode .. ':' .. mapping[2] .. ':buffer:' .. buffer,
            observed_owner = 'mapping',
          }
        end
      end
    end
  end
  table.sort(collisions, function(left, right) return left.identity < right.identity end)
  return collisions
end

--- Apply one language effect by its stable identity.
---@param identity string
---@param configuration table
function M.apply_effect(identity, configuration)
  local buffer = vim.api.nvim_get_current_buf()
  if identity == 'language/native-diagnostics' then
    vim.diagnostic.config(vim.deepcopy(configuration.diagnostics))
    vim.lsp.inlay_hint.enable(configuration.inlay_hints, { bufnr = buffer })
  elseif identity == 'language/actions-and-mappings' then
    map('n', configuration.mappings.previous_diagnostic, M.actions.previous_diagnostic, buffer)
    map('n', configuration.mappings.next_diagnostic, M.actions.next_diagnostic, buffer)
    M.attach(buffer, configuration.mappings)
  end
end

return M
