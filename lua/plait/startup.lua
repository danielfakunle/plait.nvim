local M = {}

--- Resolve the startup file selected by Neovim's command line.
---@return string|nil
local function selected_init()
  local argv = vim.v.argv or {}
  for index, argument in ipairs(argv) do
    if argument == '-u' then
      local path = argv[index + 1]
      if path and path ~= 'NONE' and path ~= 'NORC' then return vim.fs.normalize(vim.fn.fnamemodify(path, ':p')) end
      return nil
    end
  end
  return vim.fs.normalize(vim.fn.stdpath('config') .. '/init.lua')
end

--- Capture the exact owner init.lua invocation on the active stack.
---@return function|nil
function M.owner_init()
  local init = selected_init()
  if not init then return nil end
  local level = 2
  while true do
    local info = debug.getinfo(level, 'fS')
    if not info then return nil end
    if info.source and info.source:sub(1, 1) == '@' then
      local source = vim.fs.normalize(vim.fn.fnamemodify(info.source:sub(2), ':p'))
      if source == init then return info.func end
    end
    level = level + 1
  end
end

--- Check whether apply descends synchronously from the captured init invocation.
---@param owner function|nil
---@return boolean
function M.is_synchronous_init(owner)
  if vim.v.vim_did_enter ~= 0 or not owner then return false end
  local allowed_c_frames = { [require] = true, [dofile] = true, [pcall] = true, [xpcall] = true }
  local level = 2
  while true do
    local info = debug.getinfo(level, 'fnS')
    if not info then return false end
    if info.func == owner then return true end
    if info.what == 'C' and not allowed_c_frames[info.func] then return false end
    level = level + 1
  end
end

return M
