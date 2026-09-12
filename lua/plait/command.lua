local canonical = require('plait.canonical')
local diagnostic = require('plait.diagnostic')
local plait = require('plait')
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

--- Render inspection records selected by command arguments.
---@param arguments string[]
local function inspect(arguments)
  if #arguments > 2 then fail('inspect expects a section and optional identity') end
  local requested_sections = arguments[1] and { arguments[1] } or sections
  local lines = {}
  for _, section in ipairs(requested_sections) do
    local value = plait.inspect(section, arguments[2])
    local encoded = arguments[2] and canonical.encode(value) or canonical.encode_array(value)
    lines[#lines + 1] = section .. ': ' .. encoded
  end
  print(table.concat(lines, '\n'))
end

--- Render a closed action result for the command line.
---@param result table
local function render_result(result)
  if result.status == 'started' then
    print(('plait: %s started (%s)'):format(result.operation, result.operation_id))
  elseif result.status == 'performed' then
    print(('plait: %s performed'):format(result.operation))
  else
    local fields = {}
    local keys = vim.tbl_keys(result.details)
    table.sort(keys)
    for _, key in ipairs(keys) do
      fields[#fields + 1] = key .. '=' .. canonical.encode(result.details[key])
    end
    local suffix = #fields > 0 and ('\n' .. table.concat(fields, '\n')) or ''
    print(('plait: %s unavailable (%s)%s'):format(result.operation, result.reason, suffix))
  end
end

--- Dispatch the process-wide Plait command.
---@param arguments string[]
function M.dispatch(arguments)
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
  else
    fail('unknown or invalid command')
  end
end

return M
