local state = require('plait.state')

local M = {}

local directions = {
  left = 'h',
  down = 'j',
  up = 'k',
  right = 'l',
}

local native_mapping_descriptions = {
  ['i:<C-s>'] = 'vim.lsp.buf.signature_help()',
  ['s:<C-s>'] = 'vim.lsp.buf.signature_help()',
  ['n:<C-l>'] = ':help CTRL-L-default',
}

--- Return an unavailable result when the editor capability has not been applied.
---@param operation string
---@return table|nil
local function inactive(operation)
  if state.editor_active then return nil end
  return {
    status = 'unavailable',
    operation = operation,
    reason = 'capability_inactive',
    details = { capability = 'editor' },
  }
end

--- Save the current buffer synchronously.
---@return table
local function save()
  local unavailable = inactive('editor.save')
  if unavailable then return unavailable end
  local buffer = vim.api.nvim_get_current_buf()
  local ok = pcall(vim.cmd.write)
  if ok then return { status = 'performed', operation = 'editor.save', details = { buffer = buffer } } end
  return {
    status = 'unavailable',
    operation = 'editor.save',
    reason = 'execution_failed',
    details = {
      diagnostic_codes = {},
      plan_id = state.applied_plan_id,
      effects = vim.deepcopy(state.applied_effects),
    },
  }
end

--- Clear search highlighting in the current window.
---@return table
local function clear_search()
  local unavailable = inactive('editor.clear_search')
  if unavailable then return unavailable end
  local window = vim.api.nvim_get_current_win()
  vim.cmd.nohlsearch()
  return { status = 'performed', operation = 'editor.clear_search', details = { window = window } }
end

--- Move focus toward an adjacent window.
---@param direction "left"|"down"|"up"|"right"
---@return table
local function focus(direction)
  if not directions[direction] then error('plait: editor focus direction must be left, down, up, or right', 2) end
  local unavailable = inactive('editor.focus')
  if unavailable then return unavailable end
  vim.cmd('wincmd ' .. directions[direction])
  return {
    status = 'performed',
    operation = 'editor.focus',
    details = { window = vim.api.nvim_get_current_win() },
  }
end

M.actions = {
  save = save,
  clear_search = clear_search,
  focus = focus,
}

--- Deliberately write one native option, even when it already has the target value.
---@param name string
---@param value any
local function set_option(name, value) vim.api.nvim_set_option_value(name, value, {}) end

--- Apply the editor's deliberately managed native options.
---@param configuration table
local function apply_options(configuration)
  vim.api.nvim_set_var('mapleader', ' ')
  set_option('termguicolors', true)
  set_option('ignorecase', true)
  set_option('smartcase', true)
  set_option('signcolumn', 'yes')
  set_option('number', configuration.line_numbers ~= 'off')
  set_option('relativenumber', configuration.line_numbers == 'relative')
  set_option('undofile', configuration.persistent_undo)
  set_option('splitbelow', configuration.splits.horizontal == 'below')
  set_option('splitright', configuration.splits.vertical == 'right')
  set_option('expandtab', configuration.indentation.style == 'spaces')
  set_option('shiftwidth', configuration.indentation.width)
  set_option('tabstop', configuration.indentation.width)
  set_option('softtabstop', -1)
  set_option('wrap', configuration.wrap)
  set_option('linebreak', configuration.wrap)
  set_option('breakindent', configuration.wrap)

  local ssh = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil
  local osc52 = configuration.clipboard == 'osc52' or (configuration.clipboard == 'auto' and ssh)
  set_option(
    'clipboard',
    (configuration.clipboard == 'system' or (configuration.clipboard == 'auto' and not ssh)) and 'unnamedplus' or ''
  )
  if osc52 then
    local native = require('vim.ui.clipboard.osc52')
    vim.api.nvim_set_var('clipboard', {
      name = 'OSC 52',
      copy = {
        ['+'] = native.copy('+'),
        ['*'] = native.copy('*'),
      },
    })
  else
    pcall(vim.api.nvim_del_var, 'clipboard')
  end

  if configuration.ui2 then
    local ok, ui2 = pcall(require, 'vim._core.ui2')
    if not ok or type(ui2.enable) ~= 'function' then
      error('plait: Neovim UI2 is unavailable in this supported Neovim version')
    end
    --- Enable UI2 only after Neovim has an attached UI.
    local function enable_ui2()
      if #vim.api.nvim_list_uis() > 0 then ui2.enable({ enable = true, msg = { targets = 'cmd' } }) end
    end
    local group = vim.api.nvim_create_augroup('plait.editor.ui2', { clear = true })
    vim.api.nvim_create_autocmd('UIEnter', { group = group, callback = enable_ui2 })
    enable_ui2()
  end
end

--- Install one configured global mapping for all fixed modes.
---@param modes string[]|string
---@param lhs string|false
---@param callback function|string
local function map(modes, lhs, callback)
  if lhs ~= false and lhs ~= nil then vim.keymap.set(modes, lhs, callback) end
end

--- Apply the editor's fixed mapping modes and scopes.
---@param configuration table
local function apply_mappings(configuration)
  local mappings = configuration.mappings
  map({ 'n', 'i', 'x', 's' }, mappings.save, M.actions.save)
  map({ 'i', 'c' }, mappings.delete_word, '<C-w>')
  map('n', mappings.clear_search, M.actions.clear_search)
  map('n', mappings.message_pager, 'g<')
  map('n', mappings.focus_left, function() M.actions.focus('left') end)
  map('n', mappings.focus_down, function() M.actions.focus('down') end)
  map('n', mappings.focus_up, function() M.actions.focus('up') end)
  map('n', mappings.focus_right, function() M.actions.focus('right') end)
end

--- Apply the exact yank-highlight autocmd.
local function apply_yank_highlight()
  local group = vim.api.nvim_create_augroup('plait.editor.yank_highlight', { clear = true })
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = group,
    pattern = '*',
    callback = function() vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 150 }) end,
  })
end

--- Return the identity collisions that would be overwritten by one editor effect.
---@param identity string
---@param configuration table
---@return table[]
function M.preflight_effect(identity, configuration)
  local collisions = {}
  if identity == 'editor/native-options' and configuration.ui2 then
    local group = 'plait.editor.ui2'
    if vim.fn.exists('#' .. group) == 1 then
      collisions[#collisions + 1] = { identity = 'augroup:' .. group, observed_owner = 'augroup' }
    end
  elseif identity == 'editor/mappings' then
    local mappings = {
      { { 'n', 'i', 'x', 's' }, configuration.mappings.save },
      { { 'i', 'c' }, configuration.mappings.delete_word },
      { { 'n' }, configuration.mappings.clear_search },
      { { 'n' }, configuration.mappings.message_pager },
      { { 'n' }, configuration.mappings.focus_left },
      { { 'n' }, configuration.mappings.focus_down },
      { { 'n' }, configuration.mappings.focus_up },
      { { 'n' }, configuration.mappings.focus_right },
    }
    for _, mapping in ipairs(mappings) do
      if mapping[2] ~= false and mapping[2] ~= nil then
        for _, mode in ipairs(mapping[1]) do
          local observed = vim.fn.maparg(mapping[2], mode, false, true)
          -- Neovim's built-ins and Lua-created mappings both use sid -8.
          -- Recognize only the native mappings this effect can supersede.
          local native_description = native_mapping_descriptions[mode .. ':' .. mapping[2]]
          local native = native_description ~= nil and observed.desc == native_description
          if next(observed) and not native and (observed.sid > 0 or observed.sid == -8) then
            collisions[#collisions + 1] =
              { identity = 'mapping:' .. mode .. ':' .. mapping[2], observed_owner = 'mapping' }
          end
        end
      end
    end
  elseif identity == 'editor/yank-highlight' then
    local group = 'plait.editor.yank_highlight'
    if vim.fn.exists('#' .. group) == 1 then
      collisions[#collisions + 1] = { identity = 'augroup:' .. group, observed_owner = 'augroup' }
    end
  end
  return collisions
end

--- Apply one editor effect by its stable identity.
---@param identity string
---@param configuration table
function M.apply_effect(identity, configuration)
  if identity == 'editor/native-options' then
    apply_options(configuration)
  elseif identity == 'editor/mappings' then
    apply_mappings(configuration)
  elseif identity == 'editor/yank-highlight' then
    apply_yank_highlight()
  end
end

return M
