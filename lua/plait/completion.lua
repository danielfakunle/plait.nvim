local state = require('plait.state')
local effect_record = require('plait.effects')

local M = {}

--- Return a closed buffer-scoped unavailable result.
---@param operation string
---@param reason string
---@param buffer integer
---@return table
local function unavailable_in_buffer(operation, reason, buffer)
  return { status = 'unavailable', operation = operation, reason = reason, details = { buffer = buffer } }
end

--- Return a closed buffer-scoped performed result.
---@param operation string
---@param buffer integer
---@return table
local function performed_in_buffer(operation, buffer)
  return { status = 'performed', operation = operation, details = { buffer = buffer } }
end

--- Return an unavailable result when the completion capability has not been applied.
---@param operation string
---@return table|nil
local function inactive(operation)
  if state.completion_active then return nil end
  return {
    status = 'unavailable',
    operation = operation,
    reason = 'capability_inactive',
    details = { capability = 'completion' },
  }
end

--- Trigger completion for the current insert session.
---@return table
local function trigger()
  local unavailable = inactive('completion.trigger')
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  if vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'i' then
    return unavailable_in_buffer('completion.trigger', 'completion_inactive', buffer)
  end
  local provider = require('blink.cmp')
  if provider.is_active() then
    local documentation = provider.is_documentation_visible()
    local action = documentation and provider.hide_documentation or provider.show_documentation
    if action() ~= true then return unavailable_in_buffer('completion.trigger', 'documentation_unavailable', buffer) end
    return performed_in_buffer('completion.trigger', buffer)
  end
  if provider.show() ~= true then return unavailable_in_buffer('completion.trigger', 'completion_inactive', buffer) end
  return performed_in_buffer('completion.trigger', buffer)
end

--- Invoke an action that requires an active completion session.
---@param name string
---@param provider_action string
---@param unavailable_reason? string
---@return table
local function session_action(name, provider_action, unavailable_reason)
  local operation = 'completion.' .. name
  local unavailable = inactive(operation)
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local provider = require('blink.cmp')
  if not provider.is_active() then return unavailable_in_buffer(operation, 'completion_inactive', buffer) end
  if provider[provider_action]() ~= true then
    return unavailable_in_buffer(operation, unavailable_reason or 'completion_inactive', buffer)
  end
  return performed_in_buffer(operation, buffer)
end

--- Scroll visible completion documentation by one page.
---@param direction -1|1
---@return table
local function scroll_documentation(direction)
  if direction ~= -1 and direction ~= 1 then
    error('plait: completion.scroll_documentation direction must be -1 or 1', 2)
  end
  return session_action(
    'scroll_documentation',
    direction == 1 and 'scroll_documentation_down' or 'scroll_documentation_up',
    'documentation_unavailable'
  )
end

--- Accept the selected completion candidate.
---@return table
local function accept()
  local operation = 'completion.accept'
  local unavailable = inactive(operation)
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local provider = require('blink.cmp')
  if not provider.is_active() or provider.get_selected_item() == nil then
    return unavailable_in_buffer(operation, 'no_candidate', buffer)
  end
  if provider.accept() ~= true then return unavailable_in_buffer(operation, 'no_candidate', buffer) end
  return performed_in_buffer(operation, buffer)
end

--- Select the first completion candidate when needed, then accept it.
---@return table
local function select_and_accept()
  local operation = 'completion.select_and_accept'
  local unavailable = inactive(operation)
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local provider = require('blink.cmp')
  if not provider.is_active() then return unavailable_in_buffer(operation, 'completion_inactive', buffer) end
  if provider.select_and_accept() ~= true then return unavailable_in_buffer(operation, 'no_candidate', buffer) end
  return performed_in_buffer(operation, buffer)
end

--- Cancel the active completion session.
---@return table
local function cancel() return session_action('cancel', 'cancel') end

--- Hide the active completion session without undoing its preview.
---@return table
local function hide() return session_action('hide', 'hide') end

--- Select the next completion candidate.
---@return table
local function select_next() return session_action('next', 'select_next', 'no_candidate') end

--- Select the previous completion candidate.
---@return table
local function select_previous() return session_action('previous', 'select_prev', 'no_candidate') end

M.actions = {
  trigger = trigger,
  accept = accept,
  select_and_accept = select_and_accept,
  cancel = cancel,
  hide = hide,
  next = select_next,
  previous = select_previous,
  scroll_documentation = scroll_documentation,
}

--- Declare the completion capability's complete managed effect family.
---@param sources table[]
---@return table[]
function M.effects(sources)
  local function effect(identity, stage, provider, dependencies)
    return effect_record.new('completion', identity, stage, provider, dependencies, sources)
  end
  return {
    effect('completion/package/blink.cmp', 2, 'vim.pack', {}),
    effect('completion/provider-setup', 3, 'blink.cmp', { 'completion/package/blink.cmp' }),
    effect('completion/actions-and-mappings', 4, 'blink.cmp', { 'completion/provider-setup' }),
  }
end

--- Return configured global insert mapping collisions.
---@param identity string
---@param configuration table
---@return table[]
function M.preflight_effect(identity, configuration)
  if identity ~= 'completion/actions-and-mappings' then return {} end
  local collisions = {}
  for _, lhs in pairs(configuration.mappings) do
    if lhs ~= false then
      local observed = vim.fn.maparg(lhs, 'i', false, true)
      if next(observed) and observed.sid > 0 then
        collisions[#collisions + 1] = { identity = 'mapping:i:' .. lhs .. ':global', observed_owner = 'mapping' }
      end
    end
  end
  table.sort(collisions, function(left, right) return left.identity < right.identity end)
  return collisions
end

--- Assemble Plait's Blink setup policy with accepted provider payloads.
---@param configuration table
---@return table
local function setup_options(configuration)
  local options = {}
  for _, provider in ipairs(configuration.providers or {}) do
    if provider.identity == 'blink.cmp' and provider.target == 'setup' then
      options = vim.tbl_deep_extend('force', options, provider.value)
    end
  end
  return vim.tbl_deep_extend('force', options, {
    keymap = { preset = 'none' },
    enabled = function() return true end,
    completion = {
      menu = { enabled = true, auto_show = configuration.automatic },
      trigger = {
        show_on_keyword = configuration.automatic,
        show_on_trigger_character = configuration.automatic,
      },
      list = { selection = { preselect = false } },
      documentation = { auto_show = configuration.documentation ~= 'off', auto_show_delay_ms = 200 },
    },
    signature = { enabled = configuration.signature_help },
    sources = { default = vim.deepcopy(configuration.sources) },
    cmdline = {
      enabled = true,
      keymap = { preset = 'cmdline', ['<Right>'] = false, ['<Left>'] = false },
      completion = {
        list = { selection = { preselect = false } },
        menu = { auto_show = function() return vim.fn.getcmdtype() == ':' end },
        ghost_text = { enabled = true },
      },
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  })
end

--- Install an insert mapping that preserves native behavior when unavailable.
---@param lhs string|false
---@param action function
---@param ... any
local function map(lhs, action, ...)
  if lhs == false then return end
  local arguments = { ... }
  vim.keymap.set('i', lhs, function()
    local result = action(arguments[1])
    return result.status == 'unavailable' and lhs or ''
  end, { expr = true })
end

--- Apply one completion effect by stable identity.
---@param identity string
---@param configuration table
function M.apply_effect(identity, configuration)
  if identity == 'completion/provider-setup' then
    require('blink.cmp').setup(setup_options(configuration))
  elseif identity == 'completion/actions-and-mappings' then
    local mappings = configuration.mappings
    map(mappings.trigger, M.actions.trigger)
    map(mappings.next, M.actions.next)
    map(mappings.previous, M.actions.previous)
    map(mappings.previous_arrow, M.actions.previous)
    map(mappings.next_arrow, M.actions.next)
    map(mappings.accept, M.actions.accept)
    map(mappings.select_and_accept, M.actions.select_and_accept)
    map(mappings.hide, M.actions.hide)
    map(mappings.scroll_documentation_down, M.actions.scroll_documentation, 1)
    map(mappings.scroll_documentation_up, M.actions.scroll_documentation, -1)
  end
end

--- Mark completion actions available after their activation effect completes.
local function activate() state.completion_active = true end

M.integration = {
  implementation = M,
  failure_message = 'Managed completion effect failed.',
  activation_effect = 'completion/actions-and-mappings',
  activate = activate,
}

return M
