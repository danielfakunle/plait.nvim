local canonical = require('plait.canonical')
local diagnostic = require('plait.diagnostic')
local plait = require('plait')
local presentation = require('plait.presentation')
local report = require('plait.report')
local state = require('plait.state')

local M = {}

local sections = { 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations' }

--- Raise a command misuse error.
---@param message string
local function fail(message) error('plait: ' .. message, 0) end

--- Validate the current collector and print its canonical result.
local function validate()
  if not state.collector then fail('validation requires a configuration collector') end
  local result = state.collector:validate()
  local lines = {}
  for _, item in ipairs(result.diagnostics) do
    lines[#lines + 1] = diagnostic.render(item)
  end
  lines[#lines + 1] = result.status == 'valid' and ('valid ' .. result.plan_id) or 'invalid'
  print(table.concat(lines, '\n'))
end

--- Return whether the current window may be reused for a report.
---@return boolean
local function current_window_is_empty()
  local buffer = vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_name(buffer) == ''
    and vim.bo[buffer].buftype == ''
    and not vim.bo[buffer].modified
    and vim.api.nvim_buf_line_count(buffer) == 1
    and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == ''
end

--- Open or replace the disposable inspection report.
---@param lines string[]
local function open_report(lines)
  local current = vim.api.nvim_get_current_buf()
  local existing = vim.fn.bufnr('plait://inspect')
  local refreshing = existing >= 0 and existing == current
  if existing >= 0 and not refreshing then pcall(vim.api.nvim_buf_delete, existing, { force = true }) end
  local dedicated_tab = refreshing and vim.b[current].plait_report_dedicated_tab == true
  if not refreshing and not current_window_is_empty() then
    vim.cmd.tabnew()
    dedicated_tab = true
  end
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_var(buffer, 'plait_report_dedicated_tab', dedicated_tab)
  --- Set one report-local buffer option.
  ---@param name string
  ---@param value any
  local function set_option(name, value) vim.api.nvim_set_option_value(name, value, { buf = buffer }) end
  set_option('modifiable', true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  if vim.api.nvim_buf_get_name(buffer) == '' then vim.api.nvim_buf_set_name(buffer, 'plait://inspect') end
  set_option('buftype', 'nofile')
  set_option('bufhidden', 'wipe')
  set_option('swapfile', false)
  set_option('filetype', 'plait-report')
  set_option('modifiable', false)
  set_option('modified', false)
  vim.keymap.set('n', 'q', function()
    if dedicated_tab then
      vim.cmd.tabclose()
    else
      vim.api.nvim_buf_delete(0, { force = true })
    end
  end, { buffer = buffer, silent = true, nowait = true })
end

--- Render inspection records selected by command arguments.
---@param arguments string[]
local function inspect(arguments)
  local json = arguments[#arguments] == '--json'
  if json then table.remove(arguments) end
  if #arguments > 2 then fail('inspect expects a section and optional identity') end
  local requested_sections = arguments[1] and { arguments[1] } or sections
  local selected = {}
  for _, section in ipairs(requested_sections) do
    local value = plait.inspect(section, arguments[2])
    selected[section] = value
  end
  if json then
    local lines = {}
    for _, section in ipairs(requested_sections) do
      local value = selected[section]
      local encoded = arguments[2] and canonical.encode(value) or canonical.encode_array(value)
      lines[#lines + 1] = section .. ': ' .. encoded
    end
    print(table.concat(lines, '\n'))
  else
    open_report(report.render(selected, requested_sections))
  end
end

--- Render a closed action result for the command line.
---@param result table
local function render_result(result)
  if result.status == 'started' then
    print(
      ('plait: %s started (%s)\ninspect progress: :Plait inspect operations %s'):format(
        result.operation,
        result.operation_id,
        result.operation_id
      )
    )
  elseif result.status == 'performed' then
    print(('plait: %s performed'):format(result.operation))
  else
    local lines = { ('plait: %s unavailable: %s'):format(result.operation, result.reason:gsub('_', ' ')) }
    local keys = vim.tbl_keys(result.details)
    table.sort(keys)
    for _, key in ipairs(keys) do
      lines[#lines + 1] = ('Affected %s: %s'):format(key:gsub('_', ' '), presentation.value(result.details[key]))
    end
    local repairs = {
      capability_inactive = ('activate the %s capability, validate again, then retry.'):format(
        result.details.capability or 'affected'
      ),
      not_configured = 'create and validate a Plait configuration, then retry.',
      consent_required = 'rerun the command with explicit consent.',
      consent_denied = 'approve the requested change when ready, then retry.',
      restart_required = 'restart Neovim, inspect the affected targets, then retry.',
    }
    lines[#lines + 1] = 'Repair: '
      .. (repairs[result.reason] or 'inspect diagnostics and the affected targets, repair them, then retry.')
    print(table.concat(lines, '\n'))
  end
end

--- Dispatch the process-wide Plait command.
---@param arguments string[]
---@param command? table
function M.dispatch(arguments, command)
  local subcommand = table.remove(arguments, 1)
  if subcommand == 'validate' and #arguments == 0 then
    validate()
  elseif subcommand == 'inspect' then
    inspect(arguments)
  elseif subcommand == 'packages' and (arguments[1] == 'sync' or arguments[1] == 'sync!') and #arguments == 1 then
    render_result(plait.actions.packages.sync(arguments[1] == 'sync!' and true or nil))
  elseif subcommand == 'tooling' and arguments[1] == 'check' and #arguments == 1 then
    render_result(plait.actions.tooling.check())
  elseif subcommand == 'tooling' and arguments[1] == 'ensure' and #arguments == 1 then
    render_result(plait.actions.tooling.ensure())
  elseif subcommand == 'tooling' and arguments[1] == 'install' and #arguments == 2 then
    render_result(plait.actions.tooling.install(arguments[2]))
  elseif subcommand == 'tooling' and arguments[1] == 'update' and #arguments <= 2 then
    render_result(plait.actions.tooling.update(arguments[2]))
  elseif subcommand == 'format' and #arguments == 0 then
    local range
    if command and command.range > 0 then
      local line = vim.api.nvim_buf_get_lines(0, command.line2 - 1, command.line2, true)[1] or ''
      range = {
        start = { line = command.line1 - 1, character = 0 },
        end_ = { line = command.line2 - 1, character = #line },
      }
    end
    render_result(plait.actions.formatting.format(range and { range = range } or nil))
  else
    fail('unknown or invalid command')
  end
end

return M
