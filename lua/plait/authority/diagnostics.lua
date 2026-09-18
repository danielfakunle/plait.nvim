return {
  ['bootstrap.command_collision'] = {
    ['fields'] = {
      ['identity'] = 'string',
      ['observed_owner'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['capability.cardinality'] = {
    ['fields'] = {
      ['activators'] = 'string[]',
      ['capability'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['config.invalid'] = {
    ['fields'] = {
      ['expected'] = 'string',
      ['observed'] = 'string',
      ['path'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['contribution.conflict'] = {
    ['fields'] = {
      ['sources'] = 'PlaitSource[]',
      ['target'] = 'string',
      ['values'] = 'PlaitValue[]',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['dependency.ambiguous'] = {
    ['fields'] = {
      ['activators'] = 'string[]',
      ['capability'] = 'string',
      ['module'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['dependency.cycle'] = {
    ['fields'] = {
      ['capabilities'] = 'string[]',
      ['modules'] = 'string[]',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['dependency.missing'] = {
    ['fields'] = {
      ['capability'] = 'string',
      ['module'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['effect.collision'] = {
    ['fields'] = {
      ['effect'] = 'string',
      ['identity'] = 'string',
      ['observed_owner'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['effect.failed'] = {
    ['fields'] = {
      cause = 'string',
      ['capability'] = 'string',
      ['completed'] = 'string[]',
      ['effect'] = 'string',
      ['failed'] = 'string[]',
      ['message'] = 'string',
      ['operation_id'] = 'string',
      ['provider'] = 'string|nil',
      ['skipped'] = 'string[]',
      ['stage'] = 'integer',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['environment.git_unavailable'] = {
    ['fields'] = {
      ['message'] = 'string',
      ['operation'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['environment.package_path'] = {
    ['fields'] = {
      ['required_path'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['environment.unqualified'] = {
    ['fields'] = {
      ['dimension'] = 'string',
      ['observed'] = 'string',
      ['qualified'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'warning',
  },
  ['environment.unsupported_neovim'] = {
    ['fields'] = {
      ['observed'] = 'string',
      ['required'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['formatting.chain_unavailable'] = {
    ['fields'] = {
      ['filetype'] = 'string',
      ['unavailable'] = 'PlaitUnavailableFormatter[]',
    },
    ['optional'] = {},
    ['severity'] = 'warning',
  },
  ['operation.failed'] = {
    ['fields'] = {
      ['message'] = 'string',
      ['operation'] = 'string',
      ['operation_id'] = 'string',
      ['targets'] = 'string[]',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['operation.succeeded'] = {
    ['fields'] = {
      ['operation'] = 'string',
      ['operation_id'] = 'string',
      ['targets'] = 'string[]',
    },
    ['optional'] = {},
    ['severity'] = 'info',
  },
  ['override.stale_target'] = {
    ['fields'] = {
      ['target'] = 'string',
      ['valid_targets'] = 'string[]',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['package.absent'] = {
    ['fields'] = {
      ['commit'] = 'string',
      ['interactive'] = 'boolean',
      ['package'] = 'string',
      ['source'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['package.drifted'] = {
    ['fields'] = {
      ['observed'] = 'string',
      ['package'] = 'string',
      ['required'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['package.partial_unknown'] = {
    ['fields'] = {
      ['inconsistency'] = 'PlaitPackageInconsistency',
      ['message'] = 'string',
      ['operation_id'] = 'string',
      ['packages'] = 'string[]',
    },
    ['optional'] = { 'operation_id' },
    ['severity'] = 'error',
  },
  ['package.restart_required'] = {
    ['fields'] = {
      ['packages'] = 'string[]',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['package.source_collision'] = {
    ['fields'] = {
      ['observed'] = 'string',
      ['package'] = 'string',
      ['required'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['provider.guarded_path'] = {
    ['fields'] = {
      ['generated_source'] = 'PlaitSource',
      ['path'] = 'string',
      ['target'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'error',
  },
  ['tool.absent'] = {
    ['fields'] = {
      ['affected_operations'] = 'string[]',
      ['candidates'] = 'PlaitToolCandidate[]',
      ['constraint'] = 'string',
      ['tool'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'warning',
  },
  ['tool.incompatible'] = {
    ['fields'] = {
      ['affected_operations'] = 'string[]',
      ['constraint'] = 'string',
      ['path'] = 'string',
      ['tool'] = 'string',
      ['version'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'warning',
  },
  ['tool.unprobeable'] = {
    ['fields'] = {
      ['affected_operations'] = 'string[]',
      ['constraint'] = 'string',
      ['path'] = 'string',
      ['reason'] = 'string',
      ['tool'] = 'string',
    },
    ['optional'] = {},
    ['severity'] = 'warning',
  },
  ['language.mapping_collision'] = {
    severity = 'warning',
    fields = { buffer = 'integer', mode = 'string', key = 'string', action = 'string' },
  },
}
