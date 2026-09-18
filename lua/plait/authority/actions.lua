local buffer = { fields = { buffer = 'integer' } }
local position = { fields = { buffer = 'integer', position = 'PlaitPosition' } }
local targets = { fields = { targets = 'string[]' } }
local tools = { fields = { targets = 'string[]', states = 'table<string, PlaitToolState>' } }

local M = {
  ['editor.save'] = { performed = buffer, arguments = {} },
  ['editor.clear_search'] = { performed = { fields = { window = 'integer' } }, arguments = {} },
  ['editor.focus'] = { performed = { fields = { window = 'integer' } }, arguments = { '"left"|"down"|"up"|"right"' } },
  ['completion.trigger'] = { performed = buffer, arguments = {} },
  ['completion.accept'] = { performed = buffer, arguments = {} },
  ['completion.select_and_accept'] = { performed = buffer, arguments = {} },
  ['completion.cancel'] = { performed = buffer, arguments = {} },
  ['completion.hide'] = { performed = buffer, arguments = {} },
  ['completion.next'] = { performed = buffer, arguments = {} },
  ['completion.previous'] = { performed = buffer, arguments = {} },
  ['completion.scroll_documentation'] = { performed = buffer, arguments = { '-1|1' } },
  ['language.definition'] = { started = position, performed = position, arguments = {} },
  ['language.references'] = { started = position, performed = position, arguments = {} },
  ['language.hover'] = { started = position, performed = position, arguments = {} },
  ['language.rename'] = { started = position, performed = position, arguments = {} },
  ['language.code_action'] = { started = position, performed = position, arguments = {} },
  ['language.previous_diagnostic'] = { performed = buffer, arguments = {} },
  ['language.next_diagnostic'] = { performed = buffer, arguments = {} },
  ['formatting.format'] = {
    started = { fields = { buffer = 'integer', range = 'PlaitRange|nil', chain = 'string[]' } },
    performed = { fields = { buffer = 'integer', range = 'PlaitRange|nil', chain = 'string[]' } },
    arguments = { 'PlaitFormatOptions|nil' },
  },
  ['formatting.on_save'] = { performed = { fields = { buffer = 'integer', chain = 'string[]' } }, arguments = {} },
  ['tooling.check'] = {
    performed = { fields = { tools = 'string[]', states = 'table<string, PlaitToolState>' } },
    arguments = {},
  },
  ['tooling.ensure'] = { performed = tools, started = targets, arguments = {} },
  ['tooling.install'] = { performed = tools, started = targets, arguments = { 'string' } },
  ['tooling.update'] = { performed = tools, started = targets, arguments = { 'string|nil' } },
  ['packages.sync'] = {
    performed = { fields = { changed = 'string[]', states = 'table<string, PlaitPackageState>' } },
    started = targets,
    arguments = { 'boolean|nil' },
  },
  apply = { performed = { fields = { plan_id = 'string', effects = 'PlaitEffectPartition' } }, arguments = {} },
}

local common = { 'not_configured', 'invalid_plan', 'capability_inactive', 'execution_failed' }
for operation, action in pairs(M) do
  action.unavailable = vim.deepcopy(common)
  local reasons = {}
  if operation == 'apply' then
    reasons = {
      'environment_unavailable',
      'package_absent',
      'package_drifted',
      'package_source_collision',
      'restart_required',
      'partial_unknown',
      'consent_denied',
    }
  elseif operation:match('^completion%.') then
    reasons = { 'completion_inactive', 'no_candidate', 'documentation_unavailable' }
  elseif operation:match('^language%.') then
    reasons = action.started
        and { 'no_client', 'client_unsupported', 'tool_absent', 'tool_incompatible', 'tool_unprobeable' }
      or { 'no_diagnostics' }
  elseif operation == 'formatting.format' then
    reasons = { 'formatter_chain_unavailable', 'no_formatter' }
  elseif operation:match('^tooling%.') and operation ~= 'tooling.check' then
    reasons = { 'consent_required', 'consent_denied', 'restart_required', 'environment_unavailable' }
  elseif operation == 'packages.sync' then
    reasons = {
      'consent_required',
      'consent_denied',
      'restart_required',
      'partial_unknown',
      'package_source_collision',
      'package_drifted',
      'package_absent',
      'environment_unavailable',
    }
  end
  vim.list_extend(action.unavailable, reasons)
end
return M
