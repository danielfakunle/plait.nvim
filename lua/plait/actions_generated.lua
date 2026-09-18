-- Generated from lua/plait/authority.lua. Do not edit.

---@class Plaitactions_apply_performed
---@field effects PlaitEffectPartition
---@field plan_id string

---@class Plaitactions_completion_accept_performed
---@field buffer integer

---@class Plaitactions_completion_cancel_performed
---@field buffer integer

---@class Plaitactions_completion_hide_performed
---@field buffer integer

---@class Plaitactions_completion_next_performed
---@field buffer integer

---@class Plaitactions_completion_previous_performed
---@field buffer integer

---@class Plaitactions_completion_scroll_documentation_performed
---@field buffer integer

---@class Plaitactions_completion_select_and_accept_performed
---@field buffer integer

---@class Plaitactions_completion_trigger_performed
---@field buffer integer

---@class Plaitactions_editor_clear_search_performed
---@field window integer

---@class Plaitactions_editor_focus_performed
---@field window integer

---@class Plaitactions_editor_save_performed
---@field buffer integer

---@class Plaitactions_formatting_format_performed
---@field buffer integer
---@field chain string[]
---@field range PlaitRange|nil

---@class Plaitactions_formatting_format_started
---@field buffer integer
---@field chain string[]
---@field range PlaitRange|nil

---@class Plaitactions_formatting_on_save_performed
---@field buffer integer
---@field chain string[]

---@class Plaitactions_language_code_action_performed
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_code_action_started
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_definition_performed
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_definition_started
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_hover_performed
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_hover_started
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_next_diagnostic_performed
---@field buffer integer

---@class Plaitactions_language_previous_diagnostic_performed
---@field buffer integer

---@class Plaitactions_language_references_performed
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_references_started
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_rename_performed
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_language_rename_started
---@field buffer integer
---@field position PlaitPosition

---@class Plaitactions_packages_sync_performed
---@field changed string[]
---@field states table<string, PlaitPackageState>

---@class Plaitactions_packages_sync_started
---@field targets string[]

---@class Plaitactions_tooling_check_performed
---@field states table<string, PlaitToolState>
---@field tools string[]

---@class Plaitactions_tooling_ensure_performed
---@field states table<string, PlaitToolState>
---@field targets string[]

---@class Plaitactions_tooling_ensure_started
---@field targets string[]

---@class Plaitactions_tooling_install_performed
---@field states table<string, PlaitToolState>
---@field targets string[]

---@class Plaitactions_tooling_install_started
---@field targets string[]

---@class Plaitactions_tooling_update_performed
---@field states table<string, PlaitToolState>
---@field targets string[]

---@class Plaitactions_tooling_update_started
---@field targets string[]

---@class PlaitActions
---@field apply fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_accept fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_cancel fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_hide fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_next fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_previous fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_scroll_documentation fun(arg1: -1|1): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_select_and_accept fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field completion_trigger fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field editor_clear_search fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field editor_focus fun(arg1: "left"|"down"|"up"|"right"): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field editor_save fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field formatting_format fun(arg1: PlaitFormatOptions|nil): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field formatting_on_save fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_code_action fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_definition fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_hover fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_next_diagnostic fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_previous_diagnostic fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_references fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field language_rename fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field packages_sync fun(arg1: boolean|nil): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field tooling_check fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field tooling_ensure fun(): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field tooling_install fun(arg1: string): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult
---@field tooling_update fun(arg1: string|nil): PlaitPerformedResult|PlaitStartedResult|PlaitUnavailableResult

return {}
