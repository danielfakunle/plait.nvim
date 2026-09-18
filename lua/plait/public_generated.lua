-- Generated from lua/plait/authority.lua. Do not edit.

---@alias PlaitCapabilityState "active"|"degraded"
---@alias PlaitEffectState "pending"|"completed"|"failed"|"skipped"
---@alias PlaitModuleState "active"
---@alias PlaitOperationState "pending"|"succeeded"|"failed"
---@alias PlaitOwnership "mason"|"project"|"hybrid"
---@alias PlaitPackageInconsistency "checkout_without_lock"|"lock_without_checkout"|"malformed_metadata"|"duplicate_metadata"|"internal_source_mismatch"|"internal_revision_mismatch"|"interrupted_mutation"
---@alias PlaitPackageState "absent"|"satisfied"|"drifted"|"source_collision"|"restart_required"|"partial_unknown"
---@alias PlaitReasonId "invalid_plan"|"not_configured"|"capability_inactive"|"no_client"|"client_unsupported"|"no_diagnostics"|"completion_inactive"|"no_candidate"|"documentation_unavailable"|"no_formatter"|"tool_absent"|"tool_incompatible"|"tool_unprobeable"|"formatter_chain_unavailable"|"consent_required"|"consent_denied"|"package_absent"|"package_drifted"|"package_source_collision"|"restart_required"|"partial_unknown"|"environment_unavailable"|"execution_failed"
---@alias PlaitSnapshotState "validated"|"invalid"|"applied"|"unavailable"|"failed"
---@alias PlaitToolProbeFailure "not_regular_file"|"not_executable"|"broken_symlink"|"symlink_loop"|"outside_root"|"timeout"|"exit_nonzero"|"output_limit"|"version_missing"
---@alias PlaitToolState "satisfied"|"absent"|"incompatible"|"unprobeable"
---@alias PlaitValue string|boolean|number|PlaitFunction|table<string, PlaitValue>|PlaitValue[]

---@class PlaitCapabilityRecord
---@field actions string[]
---@field activator string
---@field cardinality "exclusive"|"compositional"
---@field configuration PlaitConfigurationRecord
---@field contribution_history PlaitContributionHistory[]
---@field contributions string[]
---@field degradation_details PlaitDegradation[]
---@field degradation_reasons string[]
---@field dependents string[]
---@field formatter_chains? PlaitFormatterChain[]|nil
---@field identity string
---@field lsp_fallback? string|nil
---@field overrides string[]
---@field providers string[]
---@field responsible_integration string
---@field state PlaitCapabilityState

---@class PlaitCompletionProviders
---@field blink.cmp? PlaitSetupTarget

---@class PlaitConfigurationRecord
---@field providers PlaitProviderRecord[]
---@field sources PlaitSource[]
---@field values table

---@class PlaitContributionDeclaration
---@field module string
---@field source? PlaitSource
---@field sources? PlaitSource[]
---@field value? PlaitValue

---@class PlaitContributionDeclarationMap
---@field formatting? PlaitFormattingContributions
---@field language? PlaitLanguageContributions
---@field tooling? PlaitToolingContributions

---@class PlaitContributionHistory
---@field declarations PlaitContributionDeclaration[]
---@field overrides PlaitContributionOverride[]
---@field target string

---@class PlaitContributionOverride
---@field operation PlaitOverrideOperation
---@field source PlaitSource

---@class PlaitDegradation
---@field code string
---@field filetypes string[]
---@field repair string
---@field summary string
---@field tool string

---@class PlaitDiagnostic
---@field code string
---@field details table
---@field related_sources PlaitSource[]
---@field repair string
---@field severity "error"|"warning"|"info"
---@field source? PlaitSource|nil
---@field summary string

---@class PlaitEffectError
---@field code string
---@field details table
---@field operation_id string|nil
---@field provider string|nil
---@field responsible_capability string
---@field summary string

---@class PlaitEffectPartition
---@field completed string[]
---@field failed string[]
---@field skipped string[]

---@class PlaitEffectRecord
---@field dependencies string[]
---@field error PlaitEffectError|nil
---@field identity string
---@field provider string|nil
---@field responsible_capability string
---@field sources PlaitSource[]
---@field stage integer
---@field state PlaitEffectState

---@class PlaitFormatOptions
---@field range? PlaitRange

---@class PlaitFormatterChain
---@field chain string[]
---@field declaration string
---@field filetype string
---@field reason string
---@field sources PlaitSource[]
---@field state "disabled"|"effective"

---@class PlaitFormatterDeclaration
---@field tool string

---@class PlaitFormatterTargets
---@field formatters? table<string, table>
---@field setup? table

---@class PlaitFormattingContributions
---@field by_filetype? table<string, string[]>
---@field formatters? table<string, PlaitFormatterDeclaration>

---@class PlaitFormattingOverrides
---@field by_filetype? table<string, PlaitOverrideOperation>
---@field formatters? table<string, PlaitOverrideOperation>

---@class PlaitFormattingProviders
---@field conform.nvim? PlaitFormatterTargets

---@class PlaitFunction
---@field kind "function"
---@field line integer
---@field source string

---@class PlaitInvalidResult
---@field capabilities PlaitCapabilityRecord[]
---@field diagnostics PlaitDiagnostic[]
---@field effects PlaitEffectRecord[]
---@field modules PlaitModuleRecord[]
---@field packages PlaitPackageRecord[]
---@field status "invalid"
---@field tools PlaitToolRecord[]

---@class PlaitLanguageContributions
---@field servers? table<string, PlaitServerDeclaration>

---@class PlaitLanguageOverrides
---@field servers? table<string, PlaitOverrideOperation>

---@class PlaitLanguageProviders
---@field vim.lsp? PlaitLspTargets

---@class PlaitLanguageServerRecord
---@field buffer string
---@field identity string
---@field note? string
---@field repair? string
---@field state "attached"|"not_attached"
---@field tool_state PlaitToolState
---@field workspace_root? string|nil

---@class PlaitLspTargets
---@field global? table
---@field servers? table<string, table>

---@class PlaitModuleDeclaration
---@field contribute PlaitContributionDeclarationMap
---@field name string
---@field provides string[]
---@field requires string[]

---@class PlaitModuleRecord
---@field contributions string[]
---@field identity string
---@field ordering_edges string[]
---@field provides string[]
---@field requires string[]
---@field selection_sources PlaitSource[]
---@field state PlaitModuleState

---@class PlaitOperationError
---@field message string
---@field reason "execution_failed"

---@class PlaitOperationRecord
---@field completed_at string|nil
---@field diagnostic_codes string[]
---@field error PlaitOperationError|nil
---@field identity string
---@field operation string
---@field result PlaitPerformedResult|nil
---@field started_at string
---@field state PlaitOperationState
---@field targets string[]

---@class PlaitOverrideOperation
---@field kind "replace"|"disable"
---@field value? PlaitValue|nil

---@class PlaitOverrides
---@field formatting? PlaitFormattingOverrides
---@field language? PlaitLanguageOverrides
---@field tooling? PlaitToolingOverrides

---@class PlaitPackageRecord
---@field active_commit string|nil
---@field active_source string|nil
---@field identity string
---@field inconsistency PlaitPackageInconsistency|nil
---@field repair string
---@field required_commit string
---@field responsible_capabilities string[]
---@field source string
---@field sources PlaitSource[]
---@field state PlaitPackageState

---@class PlaitPerformedResult
---@field details table
---@field operation string
---@field status "performed"

---@class PlaitPlan
---@field capabilities PlaitCapabilityRecord[]
---@field effects PlaitEffectRecord[]
---@field modules PlaitModuleRecord[]
---@field packages PlaitPackageRecord[]
---@field snapshot_state PlaitSnapshotState
---@field tools PlaitToolRecord[]

---@class PlaitPosition
---@field character integer
---@field line integer

---@class PlaitProviderDeclarations
---@field completion? PlaitCompletionProviders
---@field formatting? PlaitFormattingProviders
---@field language? PlaitLanguageProviders
---@field tooling? PlaitToolingProviders

---@class PlaitProviderRecord
---@field identity string
---@field opaque boolean
---@field revision_coupled boolean
---@field sources PlaitSource[]
---@field target string
---@field value PlaitValue

---@class PlaitRange
---@field end_ PlaitPosition
---@field start PlaitPosition

---@class PlaitServerDeclaration
---@field filetypes string[]
---@field tool string

---@class PlaitSetupTarget
---@field setup? table

---@class PlaitSource
---@field file string
---@field line integer
---@field path string

---@class PlaitStartedResult
---@field details table
---@field operation string
---@field operation_id string
---@field status "started"

---@class PlaitToolCandidate
---@field path string
---@field real_path string|nil
---@field reason PlaitToolProbeFailure|nil
---@field source "workspace"|"mason"|"PATH"
---@field state "absent"|"present"|"rejected"

---@class PlaitToolDeclaration
---@field executable string
---@field mason? string
---@field ownership PlaitOwnership
---@field version string
---@field workspace_paths? string[]

---@class PlaitToolRecord
---@field affected_operations string[]
---@field authoritative_candidate integer|nil
---@field candidates PlaitToolCandidate[]
---@field constraint string
---@field executable string
---@field identity string
---@field ownership "mason"|"project"|"hybrid"
---@field path string|nil
---@field repair string
---@field runtime PlaitToolRuntime|nil
---@field source "workspace"|"mason"|"PATH"|nil
---@field sources PlaitSource[]
---@field state PlaitToolState
---@field version string|nil

---@class PlaitToolRuntime
---@field constraint string
---@field executable string
---@field path string|nil
---@field reason PlaitToolProbeFailure|nil
---@field state PlaitToolState
---@field version string|nil

---@class PlaitToolingContributions
---@field tools? table<string, PlaitToolDeclaration>

---@class PlaitToolingOverrides
---@field tools? table<string, PlaitOverrideOperation>

---@class PlaitToolingProviders
---@field mason.nvim? PlaitSetupTarget

---@class PlaitUnavailableFormatter
---@field formatter string
---@field state "absent"|"incompatible"|"unprobeable"
---@field tool string

---@class PlaitUnavailableResult
---@field details table
---@field operation string
---@field reason PlaitReasonId
---@field status "unavailable"

---@class PlaitValidResult
---@field diagnostics PlaitDiagnostic[]
---@field plan PlaitPlan
---@field plan_id string
---@field status "valid"

return {}
