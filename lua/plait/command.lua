local canonical = require('plait.canonical')
local diagnostic = require('plait.diagnostic')
local plait = require('plait')
local report = require('plait.report')
local result_presentation = require('plait.result')
local state = require('plait.state')

local M = {}

local sections =
  { 'modules', 'capabilities', 'effects', 'language_servers', 'packages', 'tools', 'diagnostics', 'operations' }
local subcommands = { 'format', 'inspect', 'packages', 'tooling', 'validate' }
local package_actions = { 'sync', 'sync!' }
local tooling_actions = { 'check', 'ensure', 'install', 'update' }

--- Return sorted candidates matching the current argument lead.
---@param candidates string[]
---@param argument_lead string
---@return string[]
local function matching(candidates, argument_lead)
  local selected = vim.tbl_filter(function(candidate) return vim.startswith(candidate, argument_lead) end, candidates)
  table.sort(selected)
  return selected
end

--- Return identities from one completed-snapshot section without publishing state.
---@param section string
---@return string[]
local function snapshot_identities(section)
  if not state.snapshot or not vim.tbl_contains(sections, section) then return {} end
  local identities = {}
  local seen = {}
  local records = section == 'language_servers' and plait.inspect(section) or state.snapshot[section] or {}
  for _, record in ipairs(records) do
    local identity = section == 'diagnostics' and record.code or record.identity
    if type(identity) == 'string' and not seen[identity] then
      identities[#identities + 1] = identity
      seen[identity] = true
    end
  end
  table.sort(identities)
  return identities
end

--- Complete arguments accepted by the process-wide Plait command.
---@param argument_lead string
---@param command_line string
---@param cursor_position integer
---@return string[]
function M.complete(argument_lead, command_line, cursor_position)
  local before_cursor = command_line:sub(1, cursor_position)
  local arguments = vim.split(before_cursor, '%s+', { trimempty = true })
  if before_cursor:match('%s$') then arguments[#arguments + 1] = '' end
  if #arguments == 2 then return matching(subcommands, argument_lead) end
  local subcommand = arguments[2]
  if subcommand == 'inspect' and #arguments == 3 then
    local candidates = vim.deepcopy(sections)
    candidates[#candidates + 1] = '--json'
    return matching(candidates, argument_lead)
  end
  if subcommand == 'inspect' and #arguments == 4 and vim.tbl_contains(sections, arguments[3]) then
    local candidates = snapshot_identities(arguments[3])
    candidates[#candidates + 1] = '--json'
    return matching(candidates, argument_lead)
  end
  if subcommand == 'inspect' and #arguments == 5 and vim.tbl_contains(sections, arguments[3]) then
    if vim.tbl_contains(snapshot_identities(arguments[3]), arguments[4]) then
      return matching({ '--json' }, argument_lead)
    end
    return {}
  end
  if subcommand == 'packages' and #arguments == 3 then return matching(package_actions, argument_lead) end
  if subcommand == 'tooling' and #arguments == 3 then return matching(tooling_actions, argument_lead) end
  if subcommand == 'tooling' and #arguments == 4 and (arguments[3] == 'install' or arguments[3] == 'update') then
    return matching(snapshot_identities('tools'), argument_lead)
  end
  return {}
end

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
  if require('plait.feedback').present_result(result) then print(result_presentation.render_command(result)) end
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
