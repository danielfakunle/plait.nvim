vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

local compatibility = require('plait.compatibility')
local mode = vim.g.lua_quickstart_mode or 'satisfied'
local inconsistency = vim.g.lua_quickstart_inconsistency
local fixture_root = vim.g.lua_quickstart_root or vim.fn.tempname()
local config_root = fixture_root .. '/config'
local package_root = fixture_root .. '/pack/plait/opt'
local duplicate_root = fixture_root .. '/duplicate-pack'
vim.fn.mkdir(config_root, 'p')
vim.fn.mkdir(fixture_root .. '/bin', 'p')
vim.fn.writefile({ '#!/bin/sh', 'echo 3.19.1' }, fixture_root .. '/bin/lua-language-server')
vim.fn.writefile({ '#!/bin/sh', 'echo stylua 2.5.2' }, fixture_root .. '/bin/stylua')
vim.uv.fs_chmod(fixture_root .. '/bin/lua-language-server', 493)
vim.uv.fs_chmod(fixture_root .. '/bin/stylua', 493)
vim.opt.packpath:prepend(fixture_root)

local package_by_identity = {}
for _, requirement in ipairs(compatibility.providers) do
  package_by_identity[requirement.identity] = requirement
  if
    mode == 'satisfied'
    or inconsistency == 'checkout_without_lock'
    or inconsistency == 'duplicate_metadata'
    or inconsistency == 'internal_source_mismatch'
    or inconsistency == 'internal_revision_mismatch'
  then
    vim.fn.mkdir(package_root .. '/' .. requirement.identity, 'p')
    if inconsistency == 'duplicate_metadata' then
      vim.fn.mkdir(duplicate_root .. '/pack/plait/opt/' .. requirement.identity, 'p')
    end
  end
end
if inconsistency == 'duplicate_metadata' then
  -- luacheck: ignore 122
  vim.opt.packpath = { fixture_root, duplicate_root, vim.fn.stdpath('data') .. '/site' }
end

local lock = { plugins = {} }
for identity, requirement in pairs(package_by_identity) do
  lock.plugins[identity] = { source = requirement.source, commit = requirement.commit }
end
if
  mode == 'satisfied'
  or (inconsistency and inconsistency ~= 'checkout_without_lock' and inconsistency ~= 'duplicate_metadata')
then
  if inconsistency == 'internal_source_mismatch' then
    for _, entry in pairs(lock.plugins) do
      entry.src = entry.source .. '/other'
    end
  elseif inconsistency == 'internal_revision_mismatch' then
    for _, entry in pairs(lock.plugins) do
      entry.rev = string.rep('0', 40)
    end
  elseif inconsistency == 'malformed_metadata' then
    for identity in pairs(lock.plugins) do
      lock.plugins[identity] = 'invalid'
    end
  end
  vim.fn.writefile({ vim.json.encode(lock) }, config_root .. '/nvim-pack-lock.json')
end

local original_stdpath = vim.fn.stdpath
local original_globpath = vim.fn.globpath
local original_exepath = vim.fn.exepath
_G.lua_startup_probe_counts = {}
local original_system = vim.system
-- luacheck: push ignore 122
vim.fn.stdpath = function(kind)
  if kind == 'config' then return config_root end
  return original_stdpath(kind)
end
vim.fn.globpath = function(root, pattern, nosuf, list)
  local identity = pattern:match('([^/]+)$')
  if
    (mode == 'satisfied' or mode == 'recomputed' or inconsistency ~= nil)
    and (vim.fs.normalize(root) == vim.fs.normalize(fixture_root) or (inconsistency == 'duplicate_metadata' and vim.fs.normalize(
      root
    ) == vim.fs.normalize(duplicate_root)))
    and pattern:find('/opt/', 1, true)
    and package_by_identity[identity]
  then
    if inconsistency == 'lock_without_checkout' or inconsistency == 'malformed_metadata' then return {} end
    if vim.fs.normalize(root) == vim.fs.normalize(duplicate_root) then
      return { duplicate_root .. '/pack/plait/opt/' .. identity }
    end
    return { package_root .. '/' .. identity }
  end
  return original_globpath(root, pattern, nosuf, list)
end
vim.fn.exepath = function(executable)
  if mode == 'git_unavailable' and executable == 'git' then return '' end
  if executable == 'lua-language-server' or executable == 'stylua' then return fixture_root .. '/bin/' .. executable end
  return original_exepath(executable)
end
vim.system = function(arguments, options)
  if arguments[2] == '--version' then
    local identity = table.concat(arguments, '\0')
    _G.lua_startup_probe_counts[identity] = (_G.lua_startup_probe_counts[identity] or 0) + 1
  end
  local function result(stdout)
    return { wait = function() return { code = 0, stdout = stdout, stderr = '' } end }
  end
  if arguments[1] == 'git' and arguments[4] == 'remote' then
    local identity = arguments[3]:match('([^/]+)$')
    return result(package_by_identity[identity].source .. '\n')
  end
  if arguments[1] == 'git' and arguments[4] == 'rev-parse' then
    local identity = arguments[3]:match('([^/]+)$')
    return result(package_by_identity[identity].commit .. '\n')
  end
  if arguments[1] == fixture_root .. '/bin/lua-language-server' then return result('3.19.1\n') end
  if arguments[1] == fixture_root .. '/bin/stylua' then return result('stylua 2.5.2\n') end
  return original_system(arguments, options)
end
vim.pack.add = function(specs, options)
  if not specs[1] or not specs[1].name then return end
  _G.lua_quickstart_provider_package_calls = (_G.lua_quickstart_provider_package_calls or 0) + 1
  _G.lua_quickstart_provider_package_options = vim.deepcopy(options)
  if mode == 'sync_failure' then error('fixture package mutation failed') end
  if mode ~= 'interactive' and mode ~= 'sync_success' then return end
  for _, spec in ipairs(specs) do
    local requirement = package_by_identity[spec.name]
    vim.fn.mkdir(package_root .. '/' .. spec.name, 'p')
    lock.plugins[spec.name] = { source = requirement.source, commit = requirement.commit }
  end
  vim.fn.writefile({ vim.json.encode(lock) }, config_root .. '/nvim-pack-lock.json')
  mode = 'satisfied'
end
if mode == 'interactive' then
  local original_has = vim.fn.has
  vim.fn.has = function(feature)
    if feature == 'ttyin' then return 1 end
    return original_has(feature)
  end
  vim.fn.confirm = function()
    _G.lua_quickstart_consent_calls = (_G.lua_quickstart_consent_calls or 0) + 1
    return 1
  end
end
if mode == 'unsupported_neovim' then vim.version = function() return { major = 0, minor = 11, patch = 0 } end end
if mode == 'package_path' then vim.opt.packpath:remove(original_stdpath('data') .. '/site') end

package.preload.conform = function()
  return { setup = function(options) _G.lua_quickstart_conform = vim.deepcopy(options) end }
end
_G.lua_quickstart_conform = {}
package.preload['conform.formatters.stylua'] = function()
  return { command = 'stylua', args = { '--stdin-filepath', '$FILENAME', '-' }, stdin = true }
end
package.preload.mason = function()
  return { setup = function() end }
end
package.preload['blink.cmp'] = function()
  return { setup = function(options) _G.lua_quickstart_blink = vim.deepcopy(options) end }
end

vim.lsp.config.lua_ls = {
  cmd = { 'lua-language-server' },
  root_markers = { '.luarc.json', '.git' },
}
local enable = vim.lsp.enable
vim.lsp.enable = function(name) return enable(name, false) end
-- luacheck: pop

local plait = require('plait')
_G.M = plait
if inconsistency == 'interrupted_mutation' then
  for identity in pairs(package_by_identity) do
    require('plait.packages').mark_interrupted(identity, {
      message = 'Provider package verification failed.',
    })
  end
end
local quickstart
if mode == 'satisfied' or mode == 'recomputed' then
  local source_suffix = 'tests/fixtures/lua_quickstart/config.lua'
  debug.sethook(function()
    local level = 2
    while true do
      local info = debug.getinfo(level, 'Sl')
      if not info then return end
      if info.source and info.source:sub(-#source_suffix) == source_suffix and info.currentline == 22 then
        local index = 1
        while true do
          local name, value = debug.getlocal(level, index)
          if not name then break end
          if name == 'config' then _G.lua_quickstart_config = value end
          if name == 'validation' then _G.lua_quickstart_validation = value end
          if name == 'result' then _G.lua_quickstart_result = value end
          index = index + 1
        end
        debug.sethook()
        return
      end
      level = level + 1
    end
  end, 'l')
  vim.api.nvim_buf_set_name(0, fixture_root .. '/main.lua')
  dofile('tests/fixtures/lua_quickstart/config.lua')
  _G.lua_startup_probe_counts_at_apply = vim.deepcopy(_G.lua_startup_probe_counts)
  debug.sethook()
  quickstart = {
    config = _G.lua_quickstart_config,
    validation = _G.lua_quickstart_validation,
    result = _G.lua_quickstart_result,
  }
else
  vim.pack.add({ { src = 'https://github.com/danielfakunle/plait.nvim', version = '>=0.1.0,<0.2.0' } })
  local negative_config = plait.config()
  negative_config:select({ 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua' })
  local negative_validation = negative_config:validate()
  quickstart = { config = negative_config, validation = negative_validation, result = negative_config:apply() }
end
local config = quickstart.config
local validation = quickstart.validation
local validation_plan = validation.plan
validation.plan.modules[1].identity = 'mutated'
local validation_detached = plait.inspect('modules')[1].identity == 'editor'
local result = quickstart.result

if result.status ~= 'performed' then
  _G.lua_quickstart = {
    validation = validation,
    result = result,
    effects = plait.inspect('effects'),
    provider_package_calls = _G.lua_quickstart_provider_package_calls or 0,
    provider_package_options = _G.lua_quickstart_provider_package_options,
    consent_calls = _G.lua_quickstart_consent_calls or 0,
  }
  return
end

local first_inspection = plait.inspect('capabilities')
local second_inspection = plait.inspect('capabilities')
local inspection_detached = first_inspection ~= second_inspection
  and first_inspection[1] ~= second_inspection[1]
  and vim.deep_equal(first_inspection, second_inspection)

local contributions = plait.inspect('modules', 'lang.lua').contributions

local function facts(records, fields)
  return vim.tbl_map(function(record)
    return vim.tbl_map(function(field) return record[field] end, fields)
  end, records)
end

local lifecycle_errors = {}
for _, call in ipairs({
  function() config:apply() end,
  function() config:select({ 'editor' }) end,
  function() config:configure({}) end,
  function() config:providers({}) end,
  function() plait.config() end,
}) do
  local ok, err = pcall(call)
  assert(not ok)
  lifecycle_errors[#lifecycle_errors + 1] = tostring(err):match('plait:.*')
end

local effects = plait.inspect('effects')
local lua_server = vim.lsp.config.lua_ls
local nested_semantics = {}
for _, section in ipairs({ 'modules', 'capabilities', 'effects', 'packages', 'tools' }) do
  nested_semantics[section] = {}
  for _, record in ipairs(plait.inspect(section)) do
    local projection = {}
    for _, field in ipairs({
      'provides',
      'requires',
      'ordering_edges',
      'contributions',
      'dependents',
      'providers',
      'actions',
      'degradation_reasons',
      'dependencies',
      'responsible_capabilities',
      'affected_operations',
    }) do
      if record[field] then projection[field] = record[field] end
    end
    nested_semantics[section][record.identity] = projection
  end
end
_G.lua_quickstart = {
  validation = validation,
  validation_plan = validation_plan,
  result = result,
  contributions = contributions,
  package_facts = facts(plait.inspect('packages'), { 'identity', 'state' }),
  tool_facts = facts(plait.inspect('tools'), { 'identity', 'version', 'state' }),
  effect_identities = vim.tbl_map(function(item) return item.identity end, effects),
  lua_filetypes = lua_server.filetypes,
  lua_formatter_chain = (_G.lua_quickstart_conform.formatters_by_ft or {}).lua,
  lua_ls_settings = lua_server.settings,
  expected_lua_ls_settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      telemetry = { enable = false },
    },
  },
  lua_ls_capabilities = lua_server.capabilities,
  expected_completion_capabilities = {
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
          resolveSupport = {
            properties = { 'documentation', 'detail', 'additionalTextEdits', 'command', 'data' },
          },
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
  },
  validation_detached = validation_detached,
  inspection_detached = inspection_detached,
  lifecycle_errors = lifecycle_errors,
  provider_package_calls = _G.lua_quickstart_provider_package_calls or 0,
  provider_package_options = _G.lua_quickstart_provider_package_options,
  consent_calls = _G.lua_quickstart_consent_calls or 0,
  nested_semantics_hash = vim.fn.sha256(require('plait.canonical').encode(nested_semantics)),
}
