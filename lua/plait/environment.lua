local compatibility = require('plait.compatibility')

local M = {}

local function compare(left, right)
  for index = 1, 3 do
    if left[index] ~= right[index] then return left[index] < right[index] and -1 or 1 end
  end
  return 0
end

local function diagnostic(code, severity, summary, repair, details)
  return {
    code = code,
    severity = severity,
    summary = summary,
    repair = repair,
    source = nil,
    related_sources = {},
    details = details,
  }
end

local function package_path()
  local required = vim.fs.normalize(vim.fn.stdpath('data') .. '/site')
  for _, path in ipairs(vim.opt.packpath:get()) do
    if vim.fs.normalize(path) == required then return required, true end
  end
  return required, false
end

local function git_available()
  local path = vim.fn.exepath('git')
  if path == '' then return false end
  local ok, process = pcall(vim.system, { path, 'version' }, { text = true })
  if not ok then return false end
  local result = process:wait(2000)
  return result.code == 0 and ((result.stdout or '') .. (result.stderr or '')):match('git version') ~= nil
end

local function command_line(arguments)
  local ok, process = pcall(vim.system, arguments, { text = true })
  if not ok then return nil end
  local result = process:wait(2000)
  if result.code ~= 0 then return nil end
  return ((result.stdout or '') .. (result.stderr or '')):match('([^\r\n]+)')
end

--- Observe compatibility conditions without network access or mutation.
---@param requires_git boolean
---@return table[]
function M.observe(requires_git)
  local diagnostics = {}
  local version = vim.version()
  local observed_version = { version.major, version.minor, version.patch }
  if
    compare(observed_version, compatibility.neovim.minimum) < 0
    or compare(observed_version, compatibility.neovim.maximum_exclusive) >= 0
  then
    local observed = table.concat(observed_version, '.')
    diagnostics[#diagnostics + 1] = diagnostic(
      'environment.unsupported_neovim',
      'error',
      'Neovim ' .. observed .. ' is unsupported.',
      'Run a supported Neovim version.',
      { required = compatibility.neovim.constraint, observed = observed }
    )
  end
  local required, present = package_path()
  if requires_git and not present then
    diagnostics[#diagnostics + 1] = diagnostic(
      'environment.package_path',
      'error',
      'Required package path is unavailable.',
      'Add the required path to `packpath` before collection.',
      { required_path = required }
    )
  end
  if requires_git and not git_available() then
    diagnostics[#diagnostics + 1] = diagnostic(
      'environment.git_unavailable',
      'error',
      'Git is unavailable for apply.',
      'Install/fix Git, then restart and apply.',
      { operation = 'apply', message = 'Git is not executable on PATH.' }
    )
  end
  local uname = vim.uv.os_uname()
  local architecture = uname.machine == 'aarch64' and 'arm64' or uname.machine
  local platform = compatibility.platforms[uname.sysname]
  local qualified = platform ~= nil and platform[architecture] == true
  local libc
  if qualified and platform.libc then
    libc = command_line({ 'getconf', 'GNU_LIBC_VERSION' })
    qualified = libc ~= nil and libc:match('^' .. platform.libc .. ' ') ~= nil
  end
  if not qualified then
    local observed = uname.sysname .. '/' .. architecture .. (libc and '/' .. libc or '')
    diagnostics[#diagnostics + 1] = diagnostic(
      'environment.unqualified',
      'warning',
      'platform is outside the qualified matrix.',
      'Reproduce on a qualified environment for support.',
      { dimension = 'platform', observed = observed, qualified = 'macOS or glibc Linux on arm64 or x86_64' }
    )
  end
  return diagnostics
end

--- Return whether a diagnostic blocks startup before effects.
---@param item table
---@return boolean
function M.blocking(item)
  return item.code == 'environment.unsupported_neovim'
    or item.code == 'environment.package_path'
    or item.code == 'environment.git_unavailable'
end

return M
