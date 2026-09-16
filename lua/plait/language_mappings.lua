local state = require('plait.state')
local validation = require('plait.validation')

local M = {}

---@type table<integer, table<string, boolean>>
local reported = {}

---@type table<integer, table<string, function>>
local owned = {}

--- Read one exact buffer-local mapping without considering global defaults.
---@param buffer integer
---@param mode string
---@param lhs string
---@return table
local function observed_mapping(buffer, mode, lhs)
  return vim.api.nvim_buf_call(buffer, function()
    local mapping = vim.fn.maparg(lhs, mode, false, true)
    return mapping.buffer == 1 and mapping or {}
  end)
end

--- Inspect configured action mappings with their modes, client support, and current owners.
---@param buffer integer
---@param mappings table
---@param requests table
---@param departing? integer
---@return table[]
local function inspect_mappings(buffer, mappings, requests, departing)
  local clients = vim.lsp.get_clients({ bufnr = buffer })
  local names = vim.tbl_keys(requests)
  table.sort(names)
  local records = {}
  for _, name in ipairs(names) do
    local lhs = mappings[name]
    if lhs and lhs ~= false then
      local method = requests[name].method
      local supported = method == nil
      for _, client in ipairs(clients) do
        if method and (not departing or client.id ~= departing) and client:supports_method(method, buffer) then
          supported = true
          break
        end
      end
      for _, mode in ipairs(name == 'code_action' and { 'n', 'x' } or { 'n' }) do
        records[#records + 1] = {
          name = name,
          lhs = lhs,
          mode = mode,
          supported = supported,
          observed = observed_mapping(buffer, mode, lhs),
        }
      end
    end
  end
  return records
end

--- Find collisions for supported actions in loaded buffers and current diagnostic mappings.
---@param mappings table
---@param requests table
---@return table[]
function M.preflight(mappings, requests)
  local collisions = {}
  local current = vim.api.nvim_get_current_buf()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      local selected = requests
      if buffer == current then
        selected = vim.tbl_extend('force', requests, { previous_diagnostic = {}, next_diagnostic = {} })
      end
      for _, mapping in ipairs(inspect_mappings(buffer, mappings, selected)) do
        if mapping.supported and next(mapping.observed) then
          collisions[#collisions + 1] = {
            identity = 'mapping:' .. mapping.mode .. ':' .. mapping.lhs .. ':buffer:' .. buffer,
            observed_owner = 'mapping',
          }
        end
      end
    end
  end
  table.sort(collisions, function(left, right) return left.identity < right.identity end)
  return collisions
end

--- Publish one collision per buffer mapping and action until buffer wipeout.
---@param buffer integer
---@param mode string
---@param lhs string
---@param name string
local function report_collision(buffer, mode, lhs, name)
  reported[buffer] = reported[buffer] or {}
  local identity = mode .. ':' .. lhs .. ':' .. name
  if reported[buffer][identity] then return end
  reported[buffer][identity] = true
  local diagnostic = {
    code = 'language.mapping_collision',
    severity = 'warning',
    summary = 'Language mapping was skipped because another owner controls it.',
    repair = 'Remove the buffer mapping or configure a different key for language.mappings.' .. name .. '.',
    related_sources = {},
    details = { buffer = buffer, mode = mode, key = lhs, action = 'language.' .. name },
  }
  state.operation_diagnostics[#state.operation_diagnostics + 1] = diagnostic
  if state.snapshot then
    state.snapshot.diagnostics[#state.snapshot.diagnostics + 1] = vim.deepcopy(diagnostic)
    validation.sort_diagnostics(state.snapshot.diagnostics)
  end
end

--- Reconcile supported actions while removing only callbacks installed by Plait.
---@param buffer integer
---@param mappings table
---@param actions table<string, function>
---@param requests table
---@param departing? integer
local function reconcile(buffer, mappings, actions, requests, departing)
  if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then return end
  owned[buffer] = owned[buffer] or {}
  local callbacks = owned[buffer]
  for _, mapping in ipairs(inspect_mappings(buffer, mappings, requests, departing)) do
    local identity = mapping.mode .. ':' .. mapping.lhs
    local callback = callbacks[identity]
    if mapping.supported then
      if not next(mapping.observed) then
        callback = function() return actions[mapping.name]() end
        vim.keymap.set(mapping.mode, mapping.lhs, callback, { buffer = buffer, nowait = true })
        callbacks[identity] = callback
      elseif mapping.observed.callback ~= callback then
        callbacks[identity] = nil
        report_collision(buffer, mapping.mode, mapping.lhs, mapping.name)
      end
    elseif callback then
      if mapping.observed.callback == callback then vim.keymap.del(mapping.mode, mapping.lhs, { buffer = buffer }) end
      callbacks[identity] = nil
    end
  end
end

--- Install one process-wide lifecycle integration and reconcile existing buffers.
---@param mappings table
---@param actions table<string, function>
---@param requests table
function M.apply(mappings, actions, requests)
  local group = vim.api.nvim_create_augroup('plait.language.lifecycle', { clear = true })
  vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach', 'BufWipeout' }, {
    group = group,
    callback = function(event)
      if event.event == 'BufWipeout' then
        owned[event.buf] = nil
        reported[event.buf] = nil
      else
        local departing = event.event == 'LspDetach' and event.data.client_id or nil
        reconcile(event.buf, mappings, actions, requests, departing)
      end
    end,
  })
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then reconcile(buffer, mappings, actions, requests) end
  end
end

return M
