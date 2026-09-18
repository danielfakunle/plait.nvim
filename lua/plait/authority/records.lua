return {
  PlaitFormatOptions = { fields = { range = 'PlaitRange' }, optional = { 'range' } },
  ['PlaitCapabilityRecord'] = {
    ['fields'] = {
      ['actions'] = 'string[]',
      ['activator'] = 'string',
      ['cardinality'] = '"exclusive"|"compositional"',
      ['configuration'] = 'PlaitConfigurationRecord',
      ['contribution_history'] = 'PlaitContributionHistory[]',
      ['contributions'] = 'string[]',
      ['degradation_details'] = 'PlaitDegradation[]',
      ['degradation_reasons'] = 'string[]',
      ['dependents'] = 'string[]',
      ['formatter_chains'] = 'PlaitFormatterChain[]|nil',
      ['identity'] = 'string',
      ['lsp_fallback'] = 'string|nil',
      ['overrides'] = 'string[]',
      ['providers'] = 'string[]',
      ['responsible_integration'] = 'string',
      ['state'] = 'PlaitCapabilityState',
    },
    ['optional'] = { 'formatter_chains', 'lsp_fallback' },
  },
  ['PlaitConfigurationRecord'] = {
    ['fields'] = {
      ['providers'] = 'PlaitProviderRecord[]',
      ['sources'] = 'PlaitSource[]',
      ['values'] = 'table',
    },
    ['optional'] = {},
  },
  ['PlaitContributionDeclaration'] = {
    ['fields'] = {
      ['module'] = 'string',
      ['sources'] = 'PlaitSource[]',
      ['source'] = 'PlaitSource',
      ['value'] = 'PlaitValue',
    },
    ['optional'] = { 'sources', 'source', 'value' },
  },
  ['PlaitContributionHistory'] = {
    ['fields'] = {
      ['declarations'] = 'PlaitContributionDeclaration[]',
      ['overrides'] = 'PlaitContributionOverride[]',
      ['target'] = 'string',
    },
    ['optional'] = {},
  },
  ['PlaitContributionOverride'] = {
    ['fields'] = {
      ['operation'] = 'PlaitOverrideOperation',
      ['source'] = 'PlaitSource',
    },
    ['optional'] = {},
  },
  ['PlaitDegradation'] = {
    ['fields'] = {
      ['code'] = 'string',
      ['filetypes'] = 'string[]',
      ['repair'] = 'string',
      ['summary'] = 'string',
      ['tool'] = 'string',
    },
    ['optional'] = {},
  },
  ['PlaitDiagnostic'] = {
    optional = { 'source' },
    ['fields'] = {
      ['code'] = 'string',
      ['details'] = 'table',
      ['related_sources'] = 'PlaitSource[]',
      ['repair'] = 'string',
      ['severity'] = '"error"|"warning"|"info"',
      ['source'] = 'PlaitSource|nil',
      ['summary'] = 'string',
    },
  },
  ['PlaitEffectError'] = {
    ['fields'] = {
      ['code'] = 'string',
      ['details'] = 'table',
      ['operation_id'] = 'string|nil',
      ['provider'] = 'string|nil',
      ['responsible_capability'] = 'string',
      ['summary'] = 'string',
    },
  },
  ['PlaitEffectRecord'] = {
    ['fields'] = {
      ['dependencies'] = 'string[]',
      ['error'] = 'PlaitEffectError|nil',
      ['identity'] = 'string',
      ['provider'] = 'string|nil',
      ['responsible_capability'] = 'string',
      ['sources'] = 'PlaitSource[]',
      ['stage'] = 'integer',
      ['state'] = 'PlaitEffectState',
    },
  },
  ['PlaitFormatterChain'] = {
    ['fields'] = {
      ['chain'] = 'string[]',
      ['declaration'] = 'string',
      ['filetype'] = 'string',
      ['reason'] = 'string',
      ['sources'] = 'PlaitSource[]',
      ['state'] = '"disabled"|"effective"',
    },
    ['optional'] = {},
  },
  ['PlaitFunction'] = {
    ['fields'] = {
      ['kind'] = '"function"',
      ['line'] = 'integer',
      ['source'] = 'string',
    },
    ['optional'] = {},
  },
  ['PlaitInvalidResult'] = {
    ['fields'] = {
      ['capabilities'] = 'PlaitCapabilityRecord[]',
      ['diagnostics'] = 'PlaitDiagnostic[]',
      ['effects'] = 'PlaitEffectRecord[]',
      ['modules'] = 'PlaitModuleRecord[]',
      ['packages'] = 'PlaitPackageRecord[]',
      ['status'] = '"invalid"',
      ['tools'] = 'PlaitToolRecord[]',
    },
  },
  ['PlaitModuleRecord'] = {
    ['fields'] = {
      ['contributions'] = 'string[]',
      ['identity'] = 'string',
      ['ordering_edges'] = 'string[]',
      ['provides'] = 'string[]',
      ['requires'] = 'string[]',
      ['selection_sources'] = 'PlaitSource[]',
      ['state'] = 'PlaitModuleState',
    },
  },
  ['PlaitOperationError'] = {
    ['fields'] = {
      ['message'] = 'string',
      ['reason'] = '"execution_failed"',
    },
    ['optional'] = {},
  },
  ['PlaitOperationRecord'] = {
    ['fields'] = {
      ['completed_at'] = 'string|nil',
      ['diagnostic_codes'] = 'string[]',
      ['error'] = 'PlaitOperationError|nil',
      ['identity'] = 'string',
      ['operation'] = 'string',
      ['result'] = 'PlaitPerformedResult|nil',
      ['started_at'] = 'string',
      ['state'] = 'PlaitOperationState',
      ['targets'] = 'string[]',
    },
  },
  ['PlaitOverrideOperation'] = {
    ['fields'] = {
      ['kind'] = '"replace"|"disable"',
      ['value'] = 'PlaitValue|nil',
    },
    ['optional'] = { 'value' },
  },
  ['PlaitPackageRecord'] = {
    ['fields'] = {
      ['active_commit'] = 'string|nil',
      ['active_source'] = 'string|nil',
      ['identity'] = 'string',
      ['inconsistency'] = 'PlaitPackageInconsistency|nil',
      ['repair'] = 'string',
      ['required_commit'] = 'string',
      ['responsible_capabilities'] = 'string[]',
      ['source'] = 'string',
      ['sources'] = 'PlaitSource[]',
      ['state'] = 'PlaitPackageState',
    },
  },
  ['PlaitPerformedResult'] = {
    ['fields'] = {
      ['details'] = 'table',
      ['operation'] = 'string',
      ['status'] = '"performed"',
    },
  },
  ['PlaitPlan'] = {
    ['fields'] = {
      ['capabilities'] = 'PlaitCapabilityRecord[]',
      ['effects'] = 'PlaitEffectRecord[]',
      ['modules'] = 'PlaitModuleRecord[]',
      ['packages'] = 'PlaitPackageRecord[]',
      ['snapshot_state'] = 'PlaitSnapshotState',
      ['tools'] = 'PlaitToolRecord[]',
    },
  },
  ['PlaitPosition'] = {
    minimum = { line = 0, character = 0 },
    ['fields'] = {
      ['character'] = 'integer',
      ['line'] = 'integer',
    },
    ['optional'] = {},
  },
  ['PlaitProviderRecord'] = {
    ['fields'] = {
      ['identity'] = 'string',
      ['sources'] = 'PlaitSource[]',
      ['target'] = 'string',
      ['opaque'] = 'boolean',
      ['revision_coupled'] = 'boolean',
      ['value'] = 'PlaitValue',
    },
  },
  ['PlaitRange'] = {
    ['fields'] = {
      ['end_'] = 'PlaitPosition',
      ['start'] = 'PlaitPosition',
    },
    ['optional'] = {},
  },
  ['PlaitSource'] = {
    ['fields'] = {
      ['file'] = 'string',
      ['line'] = 'integer',
      ['path'] = 'string',
    },
  },
  ['PlaitStartedResult'] = {
    ['fields'] = {
      ['details'] = 'table',
      ['operation'] = 'string',
      ['operation_id'] = 'string',
      ['status'] = '"started"',
    },
  },
  ['PlaitToolCandidate'] = {
    ['fields'] = {
      ['path'] = 'string',
      ['real_path'] = 'string|nil',
      ['reason'] = 'PlaitToolProbeFailure|nil',
      ['source'] = '"workspace"|"mason"|"PATH"',
      ['state'] = '"absent"|"present"|"rejected"',
    },
  },
  ['PlaitToolRecord'] = {
    ['fields'] = {
      ['affected_operations'] = 'string[]',
      ['authoritative_candidate'] = 'integer|nil',
      ['candidates'] = 'PlaitToolCandidate[]',
      ['constraint'] = 'string',
      ['executable'] = 'string',
      ['identity'] = 'string',
      ['ownership'] = '"mason"|"project"|"hybrid"',
      ['path'] = 'string|nil',
      ['repair'] = 'string',
      ['runtime'] = 'PlaitToolRuntime|nil',
      ['source'] = '"workspace"|"mason"|"PATH"|nil',
      ['sources'] = 'PlaitSource[]',
      ['state'] = 'PlaitToolState',
      ['version'] = 'string|nil',
    },
  },
  ['PlaitToolRuntime'] = {
    ['fields'] = {
      ['constraint'] = 'string',
      ['executable'] = 'string',
      ['path'] = 'string|nil',
      ['reason'] = 'PlaitToolProbeFailure|nil',
      ['state'] = 'PlaitToolState',
      ['version'] = 'string|nil',
    },
    ['optional'] = {},
  },
  ['PlaitUnavailableFormatter'] = {
    ['fields'] = {
      ['formatter'] = 'string',
      ['state'] = '"absent"|"incompatible"|"unprobeable"',
      ['tool'] = 'string',
    },
    ['optional'] = {},
  },
  ['PlaitUnavailableResult'] = {
    ['fields'] = {
      ['details'] = 'table',
      ['operation'] = 'string',
      ['reason'] = 'PlaitReasonId',
      ['status'] = '"unavailable"',
    },
  },
  ['PlaitValidResult'] = {
    ['fields'] = {
      ['diagnostics'] = 'PlaitDiagnostic[]',
      ['plan'] = 'PlaitPlan',
      ['plan_id'] = 'string',
      ['status'] = '"valid"',
    },
  },
  PlaitEffectPartition = { fields = { completed = 'string[]', failed = 'string[]', skipped = 'string[]' } },
  PlaitLanguageServerRecord = {
    fields = {
      identity = 'string',
      state = '"attached"|"not_attached"',
      tool_state = 'PlaitToolState',
      buffer = 'string',
      workspace_root = 'string|nil',
      note = 'string',
      repair = 'string',
    },
    optional = { 'workspace_root', 'note', 'repair' },
  },
}
