local compatibility = require('plait.compatibility')

local M = {}

--- Return an effective tool declaration's executable basename.
---@param resolution table
---@param identity string
---@return string|nil
local function tool_executable(resolution, identity)
  local peer = resolution.contribution_values['tooling.tools.' .. identity]
  if peer then return type(peer.value) == 'table' and peer.value.executable or nil end
  for _, tool in ipairs(compatibility.tools) do
    if tool.identity == identity then return tool.executable end
  end
end

--- Validate that effective dynamic targets have pinned definitions and tools.
---@param resolution table
---@param diagnostic fun(code: string, summary: string, repair: string, details: table, source: table, path: string): table
---@return table[]
function M.validate(resolution, diagnostic)
  local diagnostics = {}
  local qualified = compatibility.qualified_definitions
  for target, peer in pairs(resolution.contribution_values or {}) do
    local kind, identity = target:match('^(language)%.servers%.(.+)$')
    if not kind then
      kind, identity = target:match('^(formatting)%.formatters%.(.+)$')
    end
    if kind then
      local qualification = qualified[kind][identity]
      if
        not qualification
        or (qualification.local_definition == false and type(peer.module) == 'string' and peer.module:match('^local%.'))
      then
        diagnostics[#diagnostics + 1] = diagnostic(
          'provider.unqualified_definition',
          ('Provider definition %s is not qualified at the pinned revision.'):format(identity),
          'Use a static definition qualified by the compatibility manifest.',
          { capability = kind, identity = identity },
          peer.source,
          target
        )
      else
        local tool = type(peer.value) == 'table' and peer.value.tool or nil
        local effective = type(tool) == 'string'
          and vim.list_contains(resolution.effective_contributions, 'tooling.tools.' .. tool)
        if not effective then
          diagnostics[#diagnostics + 1] = diagnostic(
            'provider.tool_requirement_missing',
            ('Provider definition %s has no effective tool requirement.'):format(identity),
            'Contribute the referenced tooling.tools identity from the selected local module.',
            { capability = kind, identity = identity, tool = tool or '' },
            peer.source,
            target
          )
        else
          local tool_identity = assert(tool)
          local executable = tool_executable(resolution, tool_identity)
          if executable ~= qualification.executable then
            diagnostics[#diagnostics + 1] = diagnostic(
              'provider.tool_requirement_mismatch',
              ('Provider definition %s references a tool with the wrong executable.'):format(identity),
              ('Reference an effective tool whose executable is %s.'):format(qualification.executable),
              {
                capability = kind,
                identity = identity,
                tool = tool_identity,
                expected_executable = qualification.executable,
                executable = executable or '',
              },
              peer.source,
              target
            )
          end
        end
      end
    end
  end
  return diagnostics
end

return M
