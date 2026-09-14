local operations = require('plait.operations')
local state = require('plait.state')
local tools = require('plait.tools')
local effect_record = require('plait.effects')

local M = {}

local builtin_servers = {
  lua_ls = { filetypes = { 'lua' }, tool = 'lua-language-server' },
  tsc = {
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    tool = 'tsc',
  },
}

local completion_capabilities = {
  textDocument = {
    completion = {
      completionItem = {
        snippetSupport = true,
        commitCharactersSupport = true,
        documentationFormat = { 'markdown', 'plaintext' },
        deprecatedSupport = true,
        preselectSupport = true,
        tagSupport = { valueSet = { 1 } },
        insertReplaceSupport = true,
        resolveSupport = { properties = { 'documentation', 'detail', 'additionalTextEdits', 'command', 'data' } },
        insertTextModeSupport = { valueSet = { 1, 2 } },
        labelDetailsSupport = true,
      },
      completionList = {
        itemDefaults = { 'commitCharacters', 'editRange', 'insertTextFormat', 'insertTextMode', 'data' },
      },
      contextSupport = true,
      insertTextMode = 1,
    },
  },
}

--- Find one tool record in an effective plan.
---@param effective_plan table
---@param identity string
---@return table|nil
local function tool_record(effective_plan, identity)
  for _, record in ipairs(effective_plan.tools) do
    if record.identity == identity then return record end
  end
end

--- Return whether one capability is active in an effective plan.
---@param effective_plan table
---@param identity string
---@return boolean
local function has_capability(effective_plan, identity)
  for _, capability in ipairs(effective_plan.capabilities) do
    if capability.identity == identity then return true end
  end
  return false
end

--- Replace only the executable in a qualified static server command.
---@param definition table
---@param record table
---@param qualification table
---@return string[]
local function qualified_command(definition, record, qualification)
  if qualification.command == 'managed' then return assert(tools.command(record, qualification.arguments)) end
  if type(definition.cmd) ~= 'table' or type(definition.cmd[1]) ~= 'string' then
    error('qualified LSP server command must be a static array')
  end
  if definition.cmd[1] ~= record.executable then error('qualified LSP server executable does not match its tool') end
  local arguments = {}
  for index = 2, #definition.cmd do
    arguments[#arguments + 1] = definition.cmd[index]
  end
  return assert(tools.command(record, arguments))
end

--- Merge accepted language provider payloads for one server.
---@param configuration table
---@param identity string
---@return table
local function provider_options(configuration, identity)
  local result = {}
  for _, provider in ipairs(configuration.providers or {}) do
    if provider.identity == 'vim.lsp' and (provider.target == 'global' or provider.target == identity) then
      result = vim.tbl_deep_extend('force', result, provider.value)
    end
  end
  return result
end

--- Resolve language-server contributions for an effective plan.
---@param resolution table
---@return table<string, table>
function M.resolve(resolution)
  local result = {}
  for identity, declaration in pairs(builtin_servers) do
    if vim.list_contains(resolution.effective_contributions, 'language.servers.' .. identity) then
      result[identity] = vim.deepcopy(declaration)
    end
  end
  for target, peer in pairs(resolution.contribution_values or {}) do
    local identity = target:match('^language%.servers%.(.+)$')
    if identity then result[identity] = vim.deepcopy(peer.value) end
  end
  return result
end

--- Declare all language effects, including one definition and service per server.
---@param resolution table
---@param sources table[]
---@return table[]
function M.effects(resolution, sources)
  local function effect(identity, stage, provider, dependencies)
    return effect_record.new('language', identity, stage, provider, dependencies, sources)
  end
  local servers = M.resolve(resolution)
  local identities = vim.tbl_keys(servers)
  table.sort(identities)
  local native_dependencies = #identities > 0 and { 'language/package/nvim-lspconfig' } or {}
  local effects = {
    effect('language/native-diagnostics', 3, 'vim.diagnostic', native_dependencies),
    effect('language/actions-and-mappings', 4, 'vim.lsp', { 'language/native-diagnostics' }),
  }
  if #identities > 0 then effects[#effects + 1] = effect('language/package/nvim-lspconfig', 2, 'vim.pack', {}) end
  local completion = false
  for _, capability in ipairs(resolution.capabilities) do
    if capability.identity == 'completion' then completion = true end
  end
  for _, identity in ipairs(identities) do
    local contribution = 'language.servers.' .. identity
    local server_sources = {}
    for _, module in ipairs(resolution.modules) do
      if vim.list_contains(module.contributions, contribution) then
        vim.list_extend(server_sources, vim.deepcopy(module.selection_sources))
      end
    end
    if #server_sources == 0 then server_sources = sources end
    effects[#effects + 1] = effect('language/server-definition/' .. identity, 3, 'vim.lsp', {
      'language/package/nvim-lspconfig',
      'tooling/tool-resolution',
    })
    effects[#effects].sources = vim.deepcopy(server_sources)
    local dependencies = { 'language/server-definition/' .. identity, 'tooling/startup-check' }
    if completion then dependencies[#dependencies + 1] = 'completion/provider-setup' end
    effects[#effects + 1] = effect('language/service/' .. identity, 5, 'vim.lsp', dependencies)
    effects[#effects].sources = vim.deepcopy(server_sources)
  end
  return effects
end

local requests = {
  definition = { method = 'textDocument/definition', invoke = function() vim.lsp.buf.definition() end },
  references = { method = 'textDocument/references', invoke = function() vim.lsp.buf.references() end },
  hover = { method = 'textDocument/hover', invoke = function() vim.lsp.buf.hover() end },
  rename = { method = 'textDocument/rename', invoke = function() vim.lsp.buf.rename() end },
  code_action = { method = 'textDocument/codeAction', invoke = function() vim.lsp.buf.code_action() end },
}

--- Find the bytewise-first degraded managed server matching a buffer.
---@param buffer integer
---@return table|nil
local function degraded_server(buffer)
  local filetype = vim.bo[buffer].filetype
  local identities = vim.tbl_keys(state.language_servers)
  table.sort(identities)
  for _, identity in ipairs(identities) do
    local server = state.language_servers[identity]
    if vim.list_contains(server.filetypes, filetype) and server.state ~= 'satisfied' then
      return {
        server = identity,
        tool = server.tool,
        state = server.state,
        filetype = filetype,
        language = server.language,
      }
    end
  end
end

--- Return whether one attached client supports a method in a buffer.
---@param buffer integer
---@param method string
---@param clients? table[]
---@return boolean
local function supports_method(buffer, method, clients)
  clients = clients or vim.lsp.get_clients({ bufnr = buffer })
  for _, client in ipairs(clients) do
    if client:supports_method(method, buffer) then return true end
  end
  return false
end

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
  local degraded = degraded_server(buffer)
  if degraded then
    return {
      status = 'unavailable',
      operation = operation_name,
      reason = 'tool_' .. degraded.state,
      details = vim.tbl_extend('force', details, {
        capability = 'language',
        language = degraded.language,
        filetype = degraded.filetype,
        server = degraded.server,
        tool = degraded.tool,
        state = degraded.state,
      }),
    }
  end
  if #clients == 0 then
    return { status = 'unavailable', operation = operation_name, reason = 'no_client', details = details }
  end
  if not supports_method(buffer, requests[name].method, clients) then
    return { status = 'unavailable', operation = operation_name, reason = 'client_unsupported', details = details }
  end

  return operations.start(operation_name, { 'buffer:' .. buffer }, function(done)
    local ok = pcall(vim.api.nvim_buf_call, buffer, requests[name].invoke)
    done(ok, ok and nil or 'Language action failed.')
  end, function() return vim.deepcopy(details) end, details)
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
    if supports_method(buffer, descriptor.method, clients) then
      map(name == 'code_action' and { 'n', 'x' } or 'n', mappings[name], M.actions[name], buffer)
    end
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
    { modes = { 'n' }, lhs = configuration.mappings.previous_diagnostic },
    { modes = { 'n' }, lhs = configuration.mappings.next_diagnostic },
  }
  local clients = vim.lsp.get_clients({ bufnr = buffer })
  for name, descriptor in pairs(requests) do
    if supports_method(buffer, descriptor.method, clients) then
      mappings[#mappings + 1] = {
        modes = name == 'code_action' and { 'n', 'x' } or { 'n' },
        lhs = configuration.mappings[name],
      }
    end
  end
  local collisions = {}
  for _, mapping in ipairs(mappings) do
    if mapping.lhs ~= false then
      for _, mode in ipairs(mapping.modes) do
        local observed = vim.fn.maparg(mapping.lhs, mode, false, true)
        if next(observed) and observed.buffer == 1 then
          collisions[#collisions + 1] = {
            identity = 'mapping:' .. mode .. ':' .. mapping.lhs .. ':buffer:' .. buffer,
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
---@param effective_plan table
---@return 'skipped'|nil
function M.apply_effect(identity, configuration, effective_plan)
  local buffer = vim.api.nvim_get_current_buf()
  if identity == 'language/native-diagnostics' then
    vim.diagnostic.config(vim.deepcopy(configuration.diagnostics))
    vim.lsp.inlay_hint.enable(configuration.inlay_hints, { bufnr = buffer })
  elseif identity == 'language/actions-and-mappings' then
    map('n', configuration.mappings.previous_diagnostic, M.actions.previous_diagnostic, buffer)
    map('n', configuration.mappings.next_diagnostic, M.actions.next_diagnostic, buffer)
    M.attach(buffer, configuration.mappings)
  elseif identity:match('^language/server%-definition/') then
    local server_identity = assert(identity:match('^language/server%-definition/(.+)$'))
    local declaration = require('plait.plan').language_requirements(effective_plan)[server_identity]
    local record = declaration and tool_record(effective_plan, declaration.tool)
    state.language_servers[server_identity] = {
      filetypes = vim.deepcopy(declaration.filetypes),
      tool = declaration.tool,
      state = record and record.state or 'absent',
      language = server_identity == 'lua_ls' and 'lang.lua' or 'lang.' .. server_identity,
    }
    if not record or record.state ~= 'satisfied' then return 'skipped' end
    local qualified = vim.deepcopy(vim.lsp.config[server_identity])
    if type(qualified) ~= 'table' then error('qualified LSP server definition is unavailable') end
    local options = vim.tbl_deep_extend('force', qualified, provider_options(configuration, server_identity))
    local qualification = assert(require('plait.compatibility').qualified_definitions.language[server_identity])
    options.cmd = qualified_command(qualified, record, qualification)
    options.filetypes = vim.deepcopy(declaration.filetypes)
    if server_identity == 'lua_ls' then
      options.settings = vim.tbl_deep_extend('force', options.settings or {}, {
        Lua = {
          runtime = { version = 'LuaJIT' },
          workspace = {
            library = { vim.fs.normalize(vim.fn.fnamemodify(vim.env.VIMRUNTIME, ':p')) },
            checkThirdParty = false,
          },
          telemetry = { enable = false },
        },
      })
    end
    if has_capability(effective_plan, 'completion') then
      options.capabilities =
        vim.tbl_deep_extend('force', options.capabilities or {}, vim.deepcopy(completion_capabilities))
    end
    vim.lsp.config(server_identity, options)
  elseif identity:match('^language/service/') then
    local server_identity = assert(identity:match('^language/service/(.+)$'))
    local server = state.language_servers[server_identity]
    if not server or server.state ~= 'satisfied' then return 'skipped' end
    vim.lsp.enable(server_identity)
  end
end

return M
