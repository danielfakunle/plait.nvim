local diagnostic = require('plait.diagnostic')
local presentation = require('plait.presentation')
local text = require('plait.text')
local contract = require('plait.public_contract')

local M = {}

local repairs = {
  capability_inactive = function(details)
    return ('activate the %s capability, validate again, then retry.'):format(details.capability or 'affected')
  end,
  not_configured = function() return 'create and validate a Plait configuration, then retry.' end,
  consent_required = function() return 'rerun the command with explicit consent.' end,
  consent_denied = function() return 'approve the requested change when ready, then retry.' end,
  restart_required = function() return 'restart Neovim, inspect the affected targets, then retry.' end,
}

--- Raise a bounded public rendering misuse error.
local function unsupported() error('plait: render expects a Plait validation or action result', 3) end

--- Return whether a value is a plain table.
---@param value any
---@return boolean
local function plain_table(value) return type(value) == 'table' and getmetatable(value) == nil end

--- Return whether text is normalized, single-line, and bounded for result presentation.
---@param value any
---@param maximum integer
---@return boolean
local function safe_text(value, maximum)
  return type(value) == 'string' and #value <= maximum and text.normalize(value) == value
end

--- Return whether a detail value can be rendered deterministically and safely.
---@param value any
---@param ancestors? table<table, boolean>
---@return boolean
local function presentable(value, ancestors)
  if value == nil or value == vim.NIL then return true end
  local kind = type(value)
  if kind == 'string' then return safe_text(value, 4096) end
  if kind == 'number' or kind == 'boolean' then return true end
  if not plain_table(value) then return false end
  ancestors = ancestors or {}
  if ancestors[value] then return false end
  ancestors[value] = true
  for key, child in pairs(value) do
    if type(key) ~= 'string' and type(key) ~= 'number' then return false end
    if not presentable(child, ancestors) then return false end
  end
  ancestors[value] = nil
  return true
end

--- Append deterministic result details using readable labels.
---@param lines string[]
---@param details table
---@param prefix string
local function append_details(lines, details, prefix)
  if not presentable(details) then unsupported() end
  local keys = vim.tbl_keys(details)
  table.sort(keys)
  for _, key in ipairs(keys) do
    lines[#lines + 1] = ('%s %s: %s'):format(prefix, key:gsub('_', ' '), presentation.value(details[key]))
  end
end

--- Render a validation result.
---@param value table
---@return string
local function render_validation(value)
  if not vim.islist(value.diagnostics) then unsupported() end
  local lines = { 'plait: validation ' .. value.status }
  if value.plan_id ~= nil then
    if not safe_text(value.plan_id, 160) or value.plan_id == '' then unsupported() end
    lines[#lines + 1] = 'Plan ID: ' .. value.plan_id
  end
  if #value.diagnostics == 0 then
    lines[#lines + 1] = 'Diagnostics: none'
  else
    lines[#lines + 1] = ('Diagnostics (%d):'):format(#value.diagnostics)
    for _, item in ipairs(value.diagnostics) do
      if
        not presentable(item)
        or not safe_text(item.code, 160)
        or not safe_text(item.severity, 32)
        or not safe_text(item.summary, 160)
        or not safe_text(item.repair, 512)
      then
        unsupported()
      end
      lines[#lines + 1] = '  ' .. diagnostic.render(item)
    end
  end
  return table.concat(lines, '\n')
end

--- Render a closed action or apply result.
---@param value table
---@param concise? boolean
---@return string
local function render_action(value, concise)
  if not safe_text(value.operation, 160) or value.operation == '' or not plain_table(value.details) then
    unsupported()
  end
  local lines = {}
  if value.status == 'started' then
    if not safe_text(value.operation_id, 160) or value.operation_id == '' then unsupported() end
    lines[1] = ('plait: %s started (%s)'):format(value.operation, value.operation_id)
    if not concise then append_details(lines, value.details, 'Details') end
    lines[#lines + 1] = (concise and 'inspect' or 'Inspect')
      .. ' progress: :Plait inspect operations '
      .. value.operation_id
  elseif value.status == 'performed' then
    lines[1] = ('plait: %s performed'):format(value.operation)
    if not concise then append_details(lines, value.details, 'Details') end
  elseif value.status == 'unavailable' or value.status == 'failed' then
    if not safe_text(value.reason, 160) or value.reason == '' then unsupported() end
    lines[1] = ('plait: %s %s: %s'):format(value.operation, value.status, value.reason:gsub('_', ' '))
    append_details(lines, value.details, 'Affected')
    local repair = repairs[value.reason]
    lines[#lines + 1] = 'Repair: '
      .. (repair and repair(value.details) or 'inspect diagnostics and the affected targets, repair them, then retry.')
  else
    unsupported()
  end
  return table.concat(lines, '\n')
end

--- Render one structured Plait validation or action result without side effects.
---@param value any
---@return string
function M.render(value)
  if not plain_table(value) or type(value.status) ~= 'string' then unsupported() end
  if value.status == 'valid' then
    if not contract.matches('PlaitValidResult', value) then unsupported() end
  elseif value.status == 'invalid' then
    if not contract.matches('PlaitInvalidResult', value) then unsupported() end
  elseif not contract.action_result(value) then
    unsupported()
  end
  local ok, rendered = pcall(function()
    if value.status == 'valid' or value.status == 'invalid' then return render_validation(value) end
    return render_action(value)
  end)
  if not ok then unsupported() end
  return rendered
end

--- Render the established concise command-line presentation of an action result.
---@param value table
---@return string
function M.render_command(value)
  if not plain_table(value) or type(value.status) ~= 'string' then unsupported() end
  if not contract.action_result(value) then unsupported() end
  return render_action(value, true)
end

return M
