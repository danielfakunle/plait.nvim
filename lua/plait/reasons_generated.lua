-- Generated from lua/plait/authority.lua. Do not edit.

---@class Plaitreasons_capability_inactive_details
---@field capability string

---@class Plaitreasons_client_unsupported_details
---@field buffer integer
---@field position PlaitPosition

---@class Plaitreasons_completion_inactive_details
---@field buffer integer

---@class Plaitreasons_consent_denied_details
---@field targets string[]

---@class Plaitreasons_consent_required_details
---@field targets string[]

---@class Plaitreasons_documentation_unavailable_details
---@field buffer integer

---@class Plaitreasons_environment_unavailable_details
---@field diagnostic_codes string[]

---@class Plaitreasons_execution_failed_details
---@field diagnostic_codes string[]
---@field effects PlaitEffectPartition
---@field plan_id string

---@class Plaitreasons_formatter_chain_unavailable_details
---@field buffer integer
---@field unavailable PlaitUnavailableFormatter[]

---@class Plaitreasons_invalid_plan_details
---@field diagnostic_codes string[]

---@class Plaitreasons_no_candidate_details
---@field buffer integer

---@class Plaitreasons_no_client_details
---@field buffer integer
---@field position PlaitPosition

---@class Plaitreasons_no_diagnostics_details
---@field buffer integer

---@class Plaitreasons_no_formatter_details
---@field buffer integer

---@class Plaitreasons_not_configured_details

---@class Plaitreasons_package_absent_details
---@field packages string[]
---@field states table<string, PlaitPackageState>

---@class Plaitreasons_package_drifted_details
---@field packages string[]
---@field states table<string, PlaitPackageState>

---@class Plaitreasons_package_source_collision_details
---@field packages string[]
---@field states table<string, PlaitPackageState>

---@class Plaitreasons_partial_unknown_details
---@field packages string[]
---@field states table<string, PlaitPackageState>

---@class Plaitreasons_restart_required_details
---@field packages string[]
---@field states table<string, PlaitPackageState>

---@class Plaitreasons_tool_absent_details
---@field buffer integer
---@field capability string
---@field filetype string
---@field language string
---@field position PlaitPosition
---@field server string
---@field state PlaitToolState
---@field tool string

---@class Plaitreasons_tool_incompatible_details
---@field buffer integer
---@field capability string
---@field filetype string
---@field language string
---@field position PlaitPosition
---@field server string
---@field state PlaitToolState
---@field tool string

---@class Plaitreasons_tool_unprobeable_details
---@field buffer integer
---@field capability string
---@field filetype string
---@field language string
---@field position PlaitPosition
---@field server string
---@field state PlaitToolState
---@field tool string

return {}
