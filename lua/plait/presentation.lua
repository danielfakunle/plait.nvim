local M = {}

--- Render a deterministic human-readable value with explicit nested boundaries.
---@param value any
---@return string
function M.value(value)
  if value == nil or value == vim.NIL then return 'none' end
  if type(value) ~= 'table' then return tostring(value) end
  local values = {}
  if vim.islist(value) then
    for _, item in ipairs(value) do
      values[#values + 1] = M.value(item)
    end
    return #values == 0 and 'none' or table.concat(values, ', ')
  end
  local keys = vim.tbl_keys(value)
  table.sort(keys)
  for _, key in ipairs(keys) do
    values[#values + 1] = key .. ': ' .. M.value(value[key])
  end
  return #values == 0 and 'none' or '(' .. table.concat(values, '; ') .. ')'
end

return M
