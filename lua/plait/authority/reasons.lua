local buffer = { fields = { buffer = 'integer' } }
local position = { fields = { buffer = 'integer', position = 'PlaitPosition' } }
local targets = { fields = { targets = 'string[]' } }
local packages = { fields = { packages = 'string[]', states = 'table<string, PlaitPackageState>' } }
local tool = {
  fields = {
    buffer = 'integer',
    position = 'PlaitPosition',
    capability = 'string',
    language = 'string',
    filetype = 'string',
    server = 'string',
    tool = 'string',
    state = 'PlaitToolState',
  },
}
return {
  invalid_plan = { fields = { diagnostic_codes = 'string[]' } },
  not_configured = { fields = {} },
  capability_inactive = { fields = { capability = 'string' } },
  no_client = position,
  client_unsupported = position,
  no_diagnostics = buffer,
  completion_inactive = buffer,
  no_candidate = buffer,
  documentation_unavailable = buffer,
  no_formatter = buffer,
  tool_absent = tool,
  tool_incompatible = tool,
  tool_unprobeable = tool,
  formatter_chain_unavailable = { fields = { buffer = 'integer', unavailable = 'PlaitUnavailableFormatter[]' } },
  consent_required = targets,
  consent_denied = targets,
  package_absent = packages,
  package_drifted = packages,
  package_source_collision = packages,
  restart_required = packages,
  partial_unknown = packages,
  environment_unavailable = { fields = { diagnostic_codes = 'string[]' } },
  execution_failed = {
    fields = { diagnostic_codes = 'string[]', plan_id = 'string', effects = 'PlaitEffectPartition' },
  },
}
