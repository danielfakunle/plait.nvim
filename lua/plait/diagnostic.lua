local presentation = require('plait.presentation')

local M = {}

--- Render deterministic diagnostic detail fields as readable labels.
---@param details table
---@return string
local function render_details(details)
  local fields = {}
  local keys = vim.tbl_keys(details)
  table.sort(keys)
  for _, key in ipairs(keys) do
    fields[#fields + 1] = key:gsub('_', ' ') .. ': ' .. presentation.value(details[key])
  end
  return table.concat(fields, '; ')
end

--- Render a diagnostic using Plait's canonical single-line format.
---@param diagnostic table
---@return string
function M.render(diagnostic)
  local parts = {
    diagnostic.severity:upper() .. ' ' .. diagnostic.code .. ': ' .. diagnostic.summary,
  }
  if diagnostic.source then
    parts[#parts + 1] = ('[at %s:%d %s]'):format(diagnostic.source.file, diagnostic.source.line, diagnostic.source.path)
  end
  if diagnostic.repair ~= '' then parts[#parts + 1] = '[repair: ' .. diagnostic.repair .. ']' end
  if next(diagnostic.details) then parts[#parts + 1] = '[affected: ' .. render_details(diagnostic.details) .. ']' end
  return table.concat(parts, ' ')
end

return M
