local M = {}

---@param value string
---@param index integer
---@return integer|nil
--- Return the valid UTF-8 sequence length at a byte offset.
local function sequence_length(value, index)
  local byte = value:byte(index)
  local length
  if byte <= 0x7f then
    return 1
  elseif byte >= 0xc2 and byte <= 0xdf then
    length = 2
  elseif byte >= 0xe0 and byte <= 0xef then
    length = 3
  elseif byte >= 0xf0 and byte <= 0xf4 then
    length = 4
  else
    return nil
  end
  if index + length - 1 > #value then return nil end
  for offset = 1, length - 1 do
    local continuation = value:byte(index + offset)
    if continuation < 0x80 or continuation > 0xbf then return nil end
  end
  local second = value:byte(index + 1)
  if length == 3 and ((byte == 0xe0 and second < 0xa0) or (byte == 0xed and second > 0x9f)) then return nil end
  if length == 4 and ((byte == 0xf0 and second < 0x90) or (byte == 0xf4 and second > 0x8f)) then return nil end
  return length
end

--- Determine whether a string is valid UTF-8.
---@param value string
---@return boolean
function M.valid_utf8(value)
  local index = 1
  while index <= #value do
    local length = sequence_length(value, index)
    if not length then return false end
    index = index + length
  end
  return true
end

--- Normalize arbitrary text into one-line valid UTF-8 suitable for publication.
---@param value string
---@return string
function M.normalize(value)
  local parts = {}
  local index = 1
  while index <= #value do
    local length = sequence_length(value, index)
    if not length then
      parts[#parts + 1] = '?'
      index = index + 1
    else
      local character = value:sub(index, index + length - 1)
      local byte = value:byte(index)
      if byte < 0x20 or byte == 0x7f or character == '\226\128\168' or character == '\226\128\169' then
        parts[#parts + 1] = ' '
      else
        parts[#parts + 1] = character
      end
      index = index + length
    end
  end
  return table.concat(parts):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end

--- Return the longest prefix within a byte limit that ends at a UTF-8 boundary.
---@param value string
---@param maximum integer
---@return string
local function prefix_at_boundary(value, maximum)
  local index = 1
  local last = 0
  while index <= #value do
    local length = sequence_length(value, index) or 1
    if index + length - 1 > maximum then break end
    last = index + length - 1
    index = index + length
  end
  return value:sub(1, last)
end

--- Truncate a normalized sentence while retaining its final punctuation.
---@param value string
---@param maximum integer
---@return string
function M.truncate_sentence(value, maximum)
  if #value <= maximum then return value end
  local punctuation_start = #value
  while punctuation_start > 1 and value:byte(punctuation_start) >= 0x80 and value:byte(punctuation_start) <= 0xbf do
    punctuation_start = punctuation_start - 1
  end
  local punctuation = value:sub(punctuation_start)
  return prefix_at_boundary(value:sub(1, punctuation_start - 1), maximum - 3 - #punctuation) .. '...' .. punctuation
end

return M
