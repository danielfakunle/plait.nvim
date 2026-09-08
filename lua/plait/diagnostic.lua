local canonical = require('plait.canonical')

local M = {}

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
  parts[#parts + 1] = '[details: ' .. canonical.encode(diagnostic.details) .. ']'
  return table.concat(parts, ' ')
end

return M
