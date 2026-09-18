-- The executable public contract. All generated artifacts consume this model.
local M = {
  configuration = require('plait.authority.configuration'),
  compatibility = require('plait.authority.compatibility'),
  records = require('plait.authority.records'),
  enums = require('plait.authority.enums'),
  diagnostics = require('plait.authority.diagnostics'),
  actions = require('plait.authority.actions'),
  reasons = require('plait.authority.reasons'),
  declarations = require('plait.authority.declarations'),
  api = { 'actions', 'config', 'disable', 'inspect', 'module', 'render', 'replace' },
  sections = {
    modules = 'PlaitModuleRecord',
    capabilities = 'PlaitCapabilityRecord',
    effects = 'PlaitEffectRecord',
    packages = 'PlaitPackageRecord',
    tools = 'PlaitToolRecord',
    operations = 'PlaitOperationRecord',
    diagnostics = 'PlaitDiagnostic',
    language_servers = 'PlaitLanguageServerRecord',
  },
}

for _, name in ipairs({ 'module', 'server', 'formatter', 'tool' }) do
  local class = 'Plait' .. name:gsub('^%l', string.upper) .. 'Declaration'
  M.records[class] = M.declarations[name]
end
for name, schema in pairs(M.declarations.records) do
  M.records[name] = schema
end
return M
