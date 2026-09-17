local state = require('plait.state')

local M = {}

---@alias PlaitInvocationOrigin 'lua'|'command'|'mapping'|'automatic'
---@type PlaitInvocationOrigin
local origin = 'automatic'
local invoking = false

--- Return whether execution details are enabled, including the compatibility alias.
---@return boolean
function M.debug() return state.operation_feedback == 'debug' or state.operation_feedback == 'all' end

--- Return the origin captured by operations started in the current invocation.
---@return PlaitInvocationOrigin
function M.origin() return origin end

--- Summarize maintenance targets without filling the message area with long lists.
---@param targets string[]
---@param section string
---@return string
local function target_names(targets, section)
  local names = vim.tbl_map(function(name) return name == 'stylua' and 'StyLua' or name end, targets)
  if #names == 0 then return section == 'packages' and 'Packages' or 'Tools' end
  if #names == 1 then return names[1] end
  local shown = {}
  for index = 1, math.min(3, #names) do
    shown[index] = names[index]
  end
  return ('%d %s (%s%s)'):format(
    #names,
    section,
    table.concat(shown, ', '),
    #names > 3 and ', …; inspect: :Plait inspect ' .. section or ''
  )
end

--- Present one maintenance result according to its invocation origin and policy.
---@param result table
---@param invocation PlaitInvocationOrigin
---@param completion? boolean
---@param operation_id? string
function M.maintenance(result, invocation, completion, operation_id)
  local explicit = invocation == 'command' or invocation == 'mapping'
  local failed = result.status == 'failed' or (result.status == 'unavailable' and result.reason ~= 'consent_denied')
  local check = result.operation == 'tooling.check' and explicit
  if not check then
    if state.operation_feedback == 'silent' then return end
    if not failed and not M.debug() and (state.operation_feedback ~= 'info' or not explicit) then return end
  end
  local section = result.operation == 'packages.sync' and 'packages' or 'tools'
  local details = result.details
  local targets = details.targets or details.packages or details.tools or details.changed or {}
  if section == 'packages' and #targets == 0 and details.states then
    targets = vim.tbl_keys(details.states)
    table.sort(targets)
  end
  local names = target_names(targets, section)
  local message
  if failed then
    message = require('plait.result').render_command(result)
  elseif result.reason == 'consent_denied' then
    message = 'Plait: Package synchronization cancelled; no packages changed.'
  elseif check then
    local findings = {}
    for _, tool in ipairs(details.tools or {}) do
      local finding = tool .. ': ' .. details.states[tool]
      if details.states[tool] ~= 'satisfied' then
        for _, record in ipairs(state.snapshot and state.snapshot.tools or {}) do
          if record.identity == tool then finding = finding .. '. ' .. record.repair end
        end
      end
      findings[#findings + 1] = finding
    end
    message = 'Plait: ' .. (#findings > 0 and table.concat(findings, '\n') or 'No tool requirements.')
  elseif result.status == 'started' then
    message = section == 'packages' and ('Plait: Synchronizing %s.'):format(names)
      or ('Plait: Preparing %s.'):format(names)
  elseif completion then
    message = section == 'packages'
        and ('Plait: Synchronized %s. Restart Neovim to use the package changes.'):format(names)
      or ('Plait: %s %s.'):format(names, result.operation == 'tooling.update' and 'updated' or 'installed')
  else
    message = ('Plait: %s %s already satisfied.'):format(names, #targets == 1 and 'is' or 'are')
  end
  if M.debug() then
    local rendered = require('plait.result').render(result)
    message = failed and rendered or message .. '\n' .. rendered
    if completion then
      message = message
        .. ('\nOperation %s %s (%s)'):format(result.operation, failed and 'failed' or 'succeeded', operation_id)
    end
  end
  if explicit and not completion and result.status ~= 'started' then
    print(message)
  else
    pcall(vim.notify, message, failed and vim.log.levels.ERROR or vim.log.levels.INFO)
  end
end

--- Invoke a capability or maintenance action with one presentation owner and restore context on misuse.
---@param action function
---@param invocation PlaitInvocationOrigin
---@param ... any
---@return table
function M.invoke(action, invocation, ...)
  if invoking then return action(...) end
  local previous = origin
  origin, invoking = invocation, true
  local ok, result = pcall(action, ...)
  origin, invoking = previous, false
  if not ok then error(result, 0) end
  if result.status ~= 'started' then
    if result.operation == 'packages.sync' or result.operation:match('^tooling%.') then
      M.maintenance(result, invocation)
    else
      M.action_result(result, invocation)
    end
  end
  return result
end

--- Wrap a public action so direct Lua failures use the same policy.
---@param action function
---@return function
function M.wrap(action)
  return function(...) return M.invoke(action, 'lua', ...) end
end

--- Present a synchronous capability result without classifying normal fallback as failure.
---@param result table
---@param invocation PlaitInvocationOrigin
function M.action_result(result, invocation)
  local expected = result.reason == 'no_diagnostics'
    or (
      result.operation:match('^completion%.')
      and (
        result.reason == 'completion_inactive'
        or result.reason == 'no_candidate'
        or result.reason == 'documentation_unavailable'
      )
    )
  local failed = not expected and (result.status == 'failed' or result.status == 'unavailable')
  local empty = result.reason == 'no_diagnostics' and (invocation == 'command' or invocation == 'mapping')
  if state.operation_feedback == 'silent' then return end
  if not M.debug() and not failed and not (empty and state.operation_feedback == 'info') then return end
  local message = empty and 'Plait: No diagnostics to navigate' or require('plait.result').render_command(result)
  if M.debug() then message = require('plait.result').render(result) end
  pcall(vim.notify, message, failed and vim.log.levels.ERROR or vim.log.levels.INFO)
end

---@type table<string, string>
local warnings = {}

--- Observe an automatic problem, suppressing identical observations until recovery.
---@param identity string
---@param message? string Nil clears the observed problem.
---@param repair? string
---@param failure? boolean
---@param evidence? string Opaque fingerprint of the observed problem.
function M.automatic(identity, message, repair, failure, evidence)
  if not message then
    warnings[identity] = nil
    return
  end
  local rendered = message .. ' Repair: ' .. (repair or '')
  local signature = rendered .. (evidence or '')
  local changed = warnings[identity] ~= signature
  warnings[identity] = signature
  if state.operation_feedback == 'silent' then return end
  if not failure and state.operation_feedback == 'errors' then return end
  if not changed and not M.debug() then return end
  pcall(vim.notify, rendered, failure and vim.log.levels.ERROR or vim.log.levels.WARN)
end

--- Present a sanitized automatic formatting failure, or observe its recovery.
---@param message? string
---@param repair? string
---@param evidence? string
function M.automatic_failure(message, repair, evidence)
  M.automatic('formatting.on_save', message, repair, true, evidence)
end

--- Present non-maintenance ledger lifecycle events through the common feedback owner.
---@param operation string
---@param identity string
---@param event string
function M.lifecycle(operation, identity, event)
  if not M.present_completion(event ~= 'failed') then return end
  local message = ('Plait operation %s %s (%s)'):format(operation, event, identity)
  if event == 'failed' then
    message = message
      .. '\nRepair: Inspect :Plait inspect operations '
      .. identity
      .. ', repair the target/provider, then retry.'
  end
  if event == 'succeeded' and operation:match('^language%.') then
    message = ('Plait operation %s request dispatched (%s); server response is not tracked.'):format(
      operation,
      identity
    )
  end
  if event == 'started' then message = message .. '\nInspect progress: :Plait inspect operations ' .. identity end
  pcall(vim.notify, message, event == 'failed' and vim.log.levels.ERROR or vim.log.levels.INFO)
end

--- Summarize all application degradation once, retaining detailed inspection evidence.
---@param result table
function M.application(result)
  local problems = {}
  local failed = result.status ~= 'performed'
  for _, diagnostic in ipairs(state.snapshot and state.snapshot.diagnostics or {}) do
    if
      (diagnostic.severity == 'error' or diagnostic.severity == 'warning')
      and not (result.status == 'performed' and diagnostic.code:match('^package%.'))
    then
      problems[#problems + 1] = diagnostic
    end
  end
  if failed or #problems > 0 then
    local primary = problems[1]
    for _, problem in ipairs(problems) do
      if problem.severity == 'error' then
        primary = problem
        break
      end
    end
    local message = failed and 'Plait application was blocked or failed. ' or 'Plait application is degraded. '
    message = message
      .. (#problems > 1 and ('%d problems. '):format(#problems) or '')
      .. (primary and primary.summary or result.reason:gsub('_', ' '))
    local repair = (primary and primary.repair or 'Repair the affected packages/environment and restart Neovim.')
      .. ' Inspect: :Plait inspect diagnostics'
    if M.debug() then message = message .. '\n' .. require('plait.result').render(result) end
    M.automatic('apply', message, repair, failed, require('plait.canonical').encode(problems))
  else
    M.automatic('apply')
    M.action_result(result, 'automatic')
  end
end

--- Return whether the configured policy presents an asynchronous completion.
---@param succeeded boolean
---@return boolean
function M.present_completion(succeeded)
  if state.operation_feedback == 'silent' then return false end
  return M.debug() or not succeeded
end

return M
