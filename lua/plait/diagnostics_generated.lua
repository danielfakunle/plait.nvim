-- Generated from lua/plait/authority.lua. Do not edit.

---@class Plaitdiagnostics_bootstrap_command_collision_details
---@field identity string
---@field observed_owner string

---@class Plaitdiagnostics_capability_cardinality_details
---@field activators string[]
---@field capability string

---@class Plaitdiagnostics_config_invalid_details
---@field expected string
---@field observed string
---@field path string

---@class Plaitdiagnostics_contribution_conflict_details
---@field sources PlaitSource[]
---@field target string
---@field values PlaitValue[]

---@class Plaitdiagnostics_dependency_ambiguous_details
---@field activators string[]
---@field capability string
---@field module string

---@class Plaitdiagnostics_dependency_cycle_details
---@field capabilities string[]
---@field modules string[]

---@class Plaitdiagnostics_dependency_missing_details
---@field capability string
---@field module string

---@class Plaitdiagnostics_effect_collision_details
---@field effect string
---@field identity string
---@field observed_owner string

---@class Plaitdiagnostics_effect_failed_details
---@field capability string
---@field cause string
---@field completed string[]
---@field effect string
---@field failed string[]
---@field message string
---@field operation_id string
---@field provider string|nil
---@field skipped string[]
---@field stage integer

---@class Plaitdiagnostics_environment_git_unavailable_details
---@field message string
---@field operation string

---@class Plaitdiagnostics_environment_package_path_details
---@field required_path string

---@class Plaitdiagnostics_environment_unqualified_details
---@field dimension string
---@field observed string
---@field qualified string

---@class Plaitdiagnostics_environment_unsupported_neovim_details
---@field observed string
---@field required string

---@class Plaitdiagnostics_formatting_chain_unavailable_details
---@field filetype string
---@field unavailable PlaitUnavailableFormatter[]

---@class Plaitdiagnostics_language_mapping_collision_details
---@field action string
---@field buffer integer
---@field key string
---@field mode string

---@class Plaitdiagnostics_operation_failed_details
---@field message string
---@field operation string
---@field operation_id string
---@field targets string[]

---@class Plaitdiagnostics_operation_succeeded_details
---@field operation string
---@field operation_id string
---@field targets string[]

---@class Plaitdiagnostics_override_stale_target_details
---@field target string
---@field valid_targets string[]

---@class Plaitdiagnostics_package_absent_details
---@field commit string
---@field interactive boolean
---@field package string
---@field source string

---@class Plaitdiagnostics_package_drifted_details
---@field observed string
---@field package string
---@field required string

---@class Plaitdiagnostics_package_partial_unknown_details
---@field inconsistency PlaitPackageInconsistency
---@field message string
---@field operation_id? string
---@field packages string[]

---@class Plaitdiagnostics_package_restart_required_details
---@field packages string[]

---@class Plaitdiagnostics_package_source_collision_details
---@field observed string
---@field package string
---@field required string

---@class Plaitdiagnostics_provider_guarded_path_details
---@field generated_source PlaitSource
---@field path string
---@field target string

---@class Plaitdiagnostics_tool_absent_details
---@field affected_operations string[]
---@field candidates PlaitToolCandidate[]
---@field constraint string
---@field tool string

---@class Plaitdiagnostics_tool_incompatible_details
---@field affected_operations string[]
---@field constraint string
---@field path string
---@field tool string
---@field version string

---@class Plaitdiagnostics_tool_unprobeable_details
---@field affected_operations string[]
---@field constraint string
---@field path string
---@field reason string
---@field tool string

return {}
