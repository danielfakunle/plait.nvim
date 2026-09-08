local compatibility = require('plait.compatibility')
local state = require('plait.state')

local M = {}

--- Run one local command and return its successful captured output.
---@param arguments string[]
---@return { stdout: string, stderr: string }|nil
local function command_output(arguments)
  local ok, process = pcall(vim.system, arguments, { text = true })
  if not ok then return nil end
  local result = process:wait(2000)
  if result.code ~= 0 then return nil end
  return { stdout = (result.stdout or ''):sub(1, 65536), stderr = (result.stderr or ''):sub(1, 65536) }
end

--- Return the first output line from a successful local command.
---@param arguments string[]
---@return string|nil
local function command_output_line(arguments)
  local output = command_output(arguments)
  if not output then return nil end
  local preferred = output.stdout ~= '' and output.stdout or output.stderr
  return preferred:match('([^\r\n]+)')
end

--- Check whether a path names a local directory.
---@param path string
---@return boolean
local function is_directory(path)
  local attributes = vim.uv.fs_stat(path)
  return attributes ~= nil and attributes.type == 'directory'
end

--- Find an installed provider without loading or configuring it.
---@param identity string
---@return string|nil
local function provider_path(identity)
  for _, root in ipairs(vim.opt.packpath:get()) do
    local matches = vim.fn.globpath(root, 'pack/*/opt/' .. identity, false, true)
    vim.list_extend(matches, vim.fn.globpath(root, 'pack/*/start/' .. identity, false, true))
    table.sort(matches)
    for _, path in ipairs(matches) do
      if is_directory(path) then return vim.fs.normalize(path) end
    end
  end
end

--- Report a non-blocking qualification result.
---@param message string
---@param qualified boolean
local function qualification(message, qualified)
  if qualified then
    vim.health.ok(message)
  else
    vim.health.warn(message)
  end
end

--- Compare an observed semantic version with a manifest tuple.
---@param observed integer[]
---@param required integer[]
---@return integer
local function compare_version(observed, required)
  for index = 1, 3 do
    if observed[index] ~= required[index] then return observed[index] < required[index] and -1 or 1 end
  end
  return 0
end

--- Check an observed semantic version against one manifest requirement.
---@param observed integer[]
---@param requirement table
---@return boolean
local function version_qualified(observed, requirement)
  if requirement.exact and compare_version(observed, requirement.exact) ~= 0 then return false end
  if requirement.minimum and compare_version(observed, requirement.minimum) < 0 then return false end
  if requirement.maximum_exclusive and compare_version(observed, requirement.maximum_exclusive) >= 0 then
    return false
  end
  return true
end

--- Parse the first complete semantic version from stdout, then stderr.
---@param output { stdout: string, stderr: string }
---@return integer[]|nil, string|nil
local function parse_version(output)
  for _, text in ipairs({ output.stdout, output.stderr }) do
    local version = text:match('%f[%d](%d+%.%d+%.%d+)%f[^%d%.]')
    if version then
      local major, minor, patch = version:match('^(%d+)%.(%d+)%.(%d+)$')
      return { tonumber(major), tonumber(minor), tonumber(patch) }, version
    end
  end
end

--- Report whether the running Neovim satisfies the manifest.
local function report_neovim()
  local version = vim.version()
  local observed = { version.major, version.minor, version.patch }
  local qualified = version_qualified(observed, compatibility.neovim)
  local message = ('Neovim qualification: %d.%d.%d; required %s'):format(
    version.major,
    version.minor,
    version.patch,
    compatibility.neovim.constraint
  )
  if qualified then
    vim.health.ok(message)
  else
    vim.health.error(message)
  end
end

--- Report whether the current operating-system tuple is qualified.
local function report_platform()
  local uname = vim.uv.os_uname()
  local architecture = uname.machine == 'aarch64' and 'arm64' or uname.machine
  local platform = compatibility.platforms[uname.sysname]
  local qualified = platform ~= nil and platform[architecture] == true
  local libc = nil
  if platform and platform.libc then
    libc = command_output_line({ 'getconf', 'GNU_LIBC_VERSION' })
    qualified = qualified and libc ~= nil and libc:match('^' .. platform.libc .. ' ') ~= nil
  end
  local observed = uname.sysname .. '/' .. architecture .. (libc and ('/' .. libc) or '')
  qualification('Platform qualification: ' .. observed, qualified)
end

--- Report whether the required native package root is on 'packpath'.
local function report_package_path()
  local required = vim.fs.normalize(vim.fn.stdpath('data') .. '/site')
  local present = false
  for _, path in ipairs(vim.opt.packpath:get()) do
    if vim.fs.normalize(path) == required then present = true end
  end
  if present then
    vim.health.ok('Native package path: ' .. required)
  else
    vim.health.error('Native package path: missing ' .. required)
  end
end

--- Report the local Git path and version without contacting a remote.
local function report_git()
  local path = vim.fn.exepath('git')
  local version = path ~= '' and command_output_line({ path, 'version' }) or nil
  if version then
    vim.health.ok(('Git: %s (%s)'):format(version, path))
  else
    vim.health.error('Git: unavailable on PATH')
  end
end

--- Report exact local provider sources and revisions from the manifest.
---@return table<string, { path: string, qualified: boolean }>
local function report_providers()
  local paths = {}
  for _, provider in ipairs(compatibility.providers) do
    local path = provider_path(provider.identity)
    local source = path and command_output_line({ 'git', '-C', path, 'remote', 'get-url', 'origin' }) or nil
    local commit = path and command_output_line({ 'git', '-C', path, 'rev-parse', 'HEAD' }) or nil
    local qualified = source == provider.source and commit == provider.commit
    if path then paths[provider.identity] = { path = path, qualified = qualified } end
    local observed = path and ('source=' .. (source or 'unknown') .. ', revision=' .. (commit or 'unknown'))
      or 'checkout absent'
    qualification(
      ('Provider %s: %s; required source=%s, revision=%s'):format(
        provider.identity,
        observed,
        provider.source,
        provider.commit
      ),
      qualified
    )
  end
  return paths
end

--- Report the pinned Mason registry from local, non-mutating metadata.
local function report_registry()
  local registry = compatibility.registry
  local root = vim.fs.normalize(vim.fn.stdpath('data') .. '/mason/registries/github/mason-org/mason-registry')
  local commit = is_directory(root) and command_output_line({ 'git', '-C', root, 'rev-parse', 'HEAD' }) or nil
  qualification(
    ('Mason registry: %s; required release=%s, revision=%s'):format(
      commit and ('revision=' .. commit) or 'not installed',
      registry.release,
      registry.commit
    ),
    commit == registry.commit
  )
end

--- Add a tool path once while preserving source precedence.
---@param candidates table[]
---@param seen table<string, boolean>
---@param path string
---@param source string
local function add_tool_candidate(candidates, seen, path, source)
  if path == '' or seen[path] or vim.fn.executable(path) ~= 1 then return end
  path = vim.fs.normalize(path)
  if seen[path] then return end
  seen[path] = true
  candidates[#candidates + 1] = { path = path, source = source }
end

--- Find workspace, Mason, then PATH candidates for one tool requirement.
---@param tool table
---@return table[]
local function tool_candidates(tool)
  local candidates = {}
  local seen = {}
  if tool.workspace then
    local directory = vim.fs.normalize(vim.fn.getcwd())
    while directory do
      add_tool_candidate(candidates, seen, directory .. '/node_modules/.bin/' .. tool.executable, 'workspace')
      local parent = vim.fs.dirname(directory)
      if parent == directory then break end
      directory = parent
    end
  end
  if tool.mason then
    add_tool_candidate(candidates, seen, vim.fn.stdpath('data') .. '/mason/bin/' .. tool.executable, 'mason')
  end
  add_tool_candidate(candidates, seen, vim.fn.exepath(tool.executable), 'PATH')
  return candidates
end

--- Report authoritative local tool candidates and semantic-version qualification.
local function report_tools()
  for _, tool in ipairs(compatibility.tools) do
    local candidate = tool_candidates(tool)[1]
    local output = candidate and command_output({ candidate.path, '--version' }) or nil
    local parsed, version
    if output then
      parsed, version = parse_version(output)
    end
    if parsed and version and version_qualified(parsed, tool) then
      vim.health.ok(
        ('Tool %s: version %s (%s, %s); required %s'):format(
          tool.identity,
          version,
          candidate.path,
          candidate.source,
          tool.constraint
        )
      )
    elseif parsed and version then
      vim.health.warn(
        ('Tool %s: incompatible version %s (%s, %s); required %s'):format(
          tool.identity,
          version,
          candidate.path,
          candidate.source,
          tool.constraint
        )
      )
    elseif candidate then
      vim.health.warn(
        ('Tool %s: unprobeable (%s, %s); required %s'):format(
          tool.identity,
          candidate.path,
          candidate.source,
          tool.constraint
        )
      )
    else
      vim.health.warn(('Tool %s: absent; required %s'):format(tool.identity, tool.constraint))
    end
  end
end

--- Read the effective clipboard policy from the latest completed snapshot.
---@return string|nil
local function configured_clipboard()
  if not state.snapshot then return nil end
  for _, capability in ipairs(state.snapshot.capabilities) do
    if capability.identity == 'editor' then return capability.configuration.values.clipboard end
  end
end

--- Report the effective or locally available clipboard route.
local function report_clipboard()
  local policy = configured_clipboard()
  local ssh = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil
  local path
  if policy == 'disabled' then
    path = 'disabled'
  elseif policy == 'osc52' or (policy == 'auto' and ssh) then
    path = 'native OSC52 copy; paste unavailable'
  elseif policy == 'system' or policy == 'auto' then
    path = vim.fn.has('clipboard') == 1 and 'system clipboard (unnamedplus)' or 'system clipboard unavailable'
  else
    path = 'not configured; system=' .. (vim.fn.has('clipboard') == 1 and 'available' or 'unavailable')
  end
  vim.health.info('Clipboard path: ' .. path)
end

--- Report Blink's qualified Rust fuzzy library or Lua fallback.
---@param blink { path: string, qualified: boolean }|nil
local function report_blink(blink)
  if not blink then
    vim.health.info('Blink fuzzy path: provider absent')
    return
  end
  local libraries = vim.fn.glob(blink.path .. '/**/libblink_cmp_fuzzy*.so', false, true)
  vim.list_extend(libraries, vim.fn.glob(blink.path .. '/**/libblink_cmp_fuzzy*.dylib', false, true))
  vim.list_extend(libraries, vim.fn.glob(blink.path .. '/**/blink_cmp_fuzzy*.dll', false, true))
  table.sort(libraries)
  if blink.qualified and #libraries > 0 then
    vim.health.ok('Blink fuzzy path: qualified v1.10.2 Rust library ' .. vim.fs.normalize(libraries[1]))
  else
    vim.health.warn('Blink fuzzy path: Lua fallback; Rust fuzzy library unavailable')
  end
end

--- Report Plait compatibility and current local observations without mutating state.
function M.check()
  vim.health.start('Plait')
  vim.health.info('Plait version: ' .. compatibility.version)
  vim.health.info('Configuration: ' .. (state.snapshot and 'configured' or 'not configured'))
  report_neovim()
  report_platform()
  report_package_path()
  report_git()
  local providers = report_providers()
  report_registry()
  report_tools()
  report_clipboard()
  report_blink(providers['blink.cmp'])
end

return M
