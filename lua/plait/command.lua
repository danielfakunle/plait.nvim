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

--- Dispatch the process-wide Plait command.
---@param arguments string[]
function M.dispatch(arguments)
  local subcommand = table.remove(arguments, 1)
  if subcommand == 'validate' and #arguments == 0 then
    validate()
  elseif subcommand == 'inspect' then
    inspect(arguments)
  else
    fail('unknown or invalid command')
  end
end

return M
