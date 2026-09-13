local compatibility = require('plait.compatibility')

local M = {}
local output_limit = 65536

--- Copy a public array value.
---@param value? table[]
---@return table[]
local function array(value) return vim.deepcopy(value or {}) end

--- Return canonical provenance for a tool requirement.
---@param requirement table
---@return table
local function source_for(requirement)
  return requirement.source
    or {
      file = 'plait:v0.1/tooling.tools.' .. requirement.identity,
      line = 0,
      path = 'tooling.tools.' .. requirement.identity,
    }
end

--- Build one closed tool diagnostic.
---@param code string
---@param requirement table
---@param record table
---@param reason? string
---@return table
local function diagnostic(code, requirement, record, reason)
  local details
  if code == 'tool.absent' then
    details = {
      tool = requirement.identity,
      constraint = requirement.constraint,
      candidates = array(record.candidates),
      affected_operations = array(requirement.affected_operations),
    }
  elseif code == 'tool.incompatible' then
    details = {
      tool = requirement.identity,
      constraint = requirement.constraint,
      path = record.path,
      version = record.version,
      affected_operations = array(requirement.affected_operations),
    }
  else
    details = {
      tool = requirement.identity,
      constraint = requirement.constraint,
      path = record.path,
      reason = reason,
      affected_operations = array(requirement.affected_operations),
    }
  end
  local summary = code == 'tool.absent' and ('Tool ' .. requirement.identity .. ' is absent.')
    or code == 'tool.incompatible' and ('Tool ' .. requirement.identity .. ' does not satisfy ' .. requirement.constraint .. '.')
    or ('Tool ' .. requirement.identity .. ' could not be probed (' .. reason .. ').')
  return {
    code = code,
    severity = 'warning',
    summary = summary,
    repair = code == 'tool.absent' and 'Install through the declared ownership path, then check again.'
      or code == 'tool.incompatible' and 'Install a satisfying version or change the requirement.'
      or 'Repair the executable/path so the fixed probe succeeds.',
    source = vim.deepcopy(source_for(requirement)),
    related_sources = {},
    details = details,
  }
end

--- Compare two parsed semantic versions.
---@param a table
---@param b table
---@return integer
local function compare(a, b)
  for i = 1, 3 do
    if a[i] ~= b[i] then return a[i] < b[i] and -1 or 1 end
  end
  local ap, bp = a[4], b[4]
  if ap == bp then return 0 end
  if not ap then return 1 end
  if not bp then return -1 end
  local aa, bb = vim.split(ap, '.', { plain = true }), vim.split(bp, '.', { plain = true })
  for i = 1, math.max(#aa, #bb) do
    if not aa[i] then return -1 end
    if not bb[i] then return 1 end
    local an, bn = aa[i]:match('^%d+$') and tonumber(aa[i]), bb[i]:match('^%d+$') and tonumber(bb[i])
    if an and bn and an ~= bn then return an < bn and -1 or 1 end
    if an and not bn then return -1 end
    if not an and bn then return 1 end
    if aa[i] ~= bb[i] then return aa[i] < bb[i] and -1 or 1 end
  end
  return 0
end

--- Parse one complete SemVer 2.0 version.
---@param value string
---@return table|nil
local function parse_semver(value)
  local base, build = value:match('^(.-)%+(.+)$')
  if value:find('%+') then
    if not base or build:find('%+') or build:find('%.%.') then return nil end
    for identifier in build:gmatch('[^.]+') do
      if not identifier:match('^[%w-]+$') then return nil end
    end
  else
    base = value
  end
  local core, pre = base:match('^(%d+%.%d+%.%d+)%-(.+)$')
  core = core or base
  local a, b, c = core:match('^(%d+)%.(%d+)%.(%d+)$')
  if not a or (#a > 1 and a:sub(1, 1) == '0') or (#b > 1 and b:sub(1, 1) == '0') or (#c > 1 and c:sub(1, 1) == '0') then
    return nil
  end
  if pre then
    if pre:find('%.%.') then return nil end
    for identifier in pre:gmatch('[^.]+') do
      if
        not identifier:match('^[%w-]+$')
        or (identifier:match('^%d+$') and #identifier > 1 and identifier:sub(1, 1) == '0')
      then
        return nil
      end
    end
  end
  return { tonumber(a), tonumber(b), tonumber(c), pre }
end

--- Validate and normalize one closed external-tool declaration.
---@param value any
---@return table|nil
function M.normalize_declaration(value)
  if type(value) ~= 'table' or getmetatable(value) ~= nil then return nil end
  local allowed = { executable = true, version = true, ownership = true, workspace_paths = true, mason = true }
  for key in pairs(value) do
    if type(key) ~= 'string' or not allowed[key] then return nil end
  end
  if
    type(value.executable) ~= 'string'
    or value.executable == ''
    or value.executable == '.'
    or value.executable == '..'
    or value.executable:find('[%z/\\]')
  then
    return nil
  end
  if
    type(value.version) ~= 'string'
    or value.version == ''
    or value.version:find('[|%^~%*]')
    or value.version:find('%s%-%s')
  then
    return nil
  end
  local comparators = 0
  local lower, lower_open, upper, upper_open
  for part in value.version:gmatch('[^,]+') do
    comparators = comparators + 1
    part = part:match('^%s*(.-)%s*$')
    local operator, semver
    for _, candidate in ipairs({ '<=', '>=', '=', '<', '>' }) do
      if part:sub(1, #candidate) == candidate then
        operator, semver = candidate, part:sub(#candidate + 1):match('^%s*(.-)%s*$')
        break
      end
    end
    operator, semver = operator or '=', semver or part
    local parsed = parse_semver(semver)
    if not parsed then return nil end
    if operator == '=' then
      if (lower and compare(parsed, lower) < 0) or (upper and compare(parsed, upper) > 0) then return nil end
      lower, upper, lower_open, upper_open = parsed, parsed, false, false
    elseif operator == '>' or operator == '>=' then
      local relation = lower and compare(parsed, lower) or 1
      if relation > 0 or (relation == 0 and operator == '>') then
        lower, lower_open = parsed, operator == '>'
      end
    else
      local relation = upper and compare(parsed, upper) or -1
      if relation < 0 or (relation == 0 and operator == '<') then
        upper, upper_open = parsed, operator == '<'
      end
    end
  end
  if comparators == 0 then return nil end
  if lower and upper then
    local relation = compare(lower, upper)
    if relation > 0 or (relation == 0 and (lower_open or upper_open)) then return nil end
  end
  if value.ownership ~= 'mason' and value.ownership ~= 'project' and value.ownership ~= 'hybrid' then return nil end
  if value.ownership == 'mason' then
    if value.workspace_paths ~= nil or type(value.mason) ~= 'string' or value.mason == '' then return nil end
  elseif value.ownership == 'project' then
    if value.mason ~= nil or type(value.workspace_paths) ~= 'table' then return nil end
  elseif type(value.mason) ~= 'string' or value.mason == '' or type(value.workspace_paths) ~= 'table' then
    return nil
  end
  if value.mason and (value.mason == '.' or value.mason == '..' or value.mason:find('[%z/\\]')) then return nil end
  local normalized = vim.deepcopy(value)
  if value.workspace_paths then
    local seen, paths = {}, {}
    if #value.workspace_paths == 0 then return nil end
    for index, path in ipairs(value.workspace_paths) do
      if
        type(path) ~= 'string'
        or path == ''
        or path:find('[%z\\]')
        or path:sub(1, 1) == '/'
        or path:sub(-1) == '/'
      then
        return nil
      end
      local pieces = {}
      for piece in path:gmatch('[^/]+') do
        if piece == '..' then
          return nil
        elseif piece ~= '.' then
          pieces[#pieces + 1] = piece
        end
      end
      local canonical = table.concat(pieces, '/')
      if canonical == '' or seen[canonical] then return nil end
      seen[canonical], paths[index] = true, canonical
    end
    for key in pairs(value.workspace_paths) do
      if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or key > #value.workspace_paths then return nil end
    end
    normalized.workspace_paths = paths
  end
  return normalized
end

--- Check a parsed version against a validated comparator intersection.
---@param version table
---@param constraint string
---@return boolean
local function constraint_allows(version, constraint)
  for part in constraint:gmatch('[^,]+') do
    part = part:match('^%s*(.-)%s*$')
    local op, wanted
    for _, candidate in ipairs({ '<=', '>=', '=', '<', '>' }) do
      if part:sub(1, #candidate) == candidate then
        op, wanted = candidate, part:sub(#candidate + 1)
        break
      end
    end
    if not op then
      op, wanted = '=', part
    end
    wanted = wanted:match('^%s*(.-)%s*$')
    local target = parse_semver(wanted)
    if not target then return false end
    local c = compare(version, target)
    if
      not (
        (op == '=' and c == 0)
        or (op == '<' and c < 0)
        or (op == '<=' and c <= 0)
        or (op == '>' and c > 0)
        or (op == '>=' and c >= 0)
      )
    then
      return false
    end
  end
  return true
end

--- Check one lexical candidate and its resolved target.
---@param path string
---@param kind string
---@param lexical_root? string
---@param resolved_root? string
---@return table
local function present_candidate(path, kind, lexical_root, resolved_root)
  path = vim.fs.normalize(path)
  lexical_root = lexical_root and vim.fs.normalize(lexical_root) or nil
  if lexical_root and path ~= lexical_root and path:sub(1, #lexical_root + 1) ~= lexical_root .. '/' then
    return { path = path, real_path = nil, source = kind, state = 'rejected', reason = 'outside_root' }
  end
  local lexical = vim.uv.fs_lstat(path)
  if not lexical then return { path = path, real_path = nil, source = kind, state = 'absent', reason = nil } end
  local real = vim.uv.fs_realpath(path)
  if not real then
    return {
      path = path,
      real_path = nil,
      source = kind,
      state = 'rejected',
      reason = lexical.type == 'link' and 'broken_symlink' or 'symlink_loop',
    }
  end
  real = vim.fs.normalize(real)
  if resolved_root then
    local real_root = vim.uv.fs_realpath(resolved_root)
    if not real_root or (real ~= real_root and real:sub(1, #real_root + 1) ~= real_root .. '/') then
      return { path = path, real_path = real, source = kind, state = 'rejected', reason = 'outside_root' }
    end
  end
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return { path = path, real_path = real, source = kind, state = 'rejected', reason = 'not_regular_file' }
  end
  if vim.fn.executable(path) ~= 1 then
    return { path = path, real_path = real, source = kind, state = 'rejected', reason = 'not_executable' }
  end
  return { path = path, real_path = real, source = kind, state = 'present', reason = nil }
end

--- Select the active buffer directory, falling back to the CWD.
---@return string
local function start_directory()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= '' and vim.bo.buftype == '' then
    local stat = vim.uv.fs_stat(name)
    return vim.fs.normalize(
      vim.fn.fnamemodify(stat and stat.type == 'directory' and name or vim.fs.dirname(name), ':p')
    )
  end
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.getcwd(), ':p'))
end

--- Enumerate candidates in ownership-policy order.
---@param requirement table
---@return table[]
local function candidates(requirement)
  local result = {}
  if requirement.ownership == 'project' or requirement.ownership == 'hybrid' then
    local directory = start_directory()
    while directory do
      for _, relative in ipairs(requirement.workspace_paths or {}) do
        result[#result + 1] = present_candidate(directory .. '/' .. relative, 'workspace', directory, directory)
      end
      local parent = vim.fs.dirname(directory)
      if parent == directory then break end
      directory = parent
    end
  end
  if requirement.ownership == 'mason' or requirement.ownership == 'hybrid' then
    local data = vim.fn.stdpath('data')
    result[#result + 1] = present_candidate(
      data .. '/mason/bin/' .. requirement.executable,
      'mason',
      data .. '/mason',
      data .. '/mason/packages/' .. requirement.mason
    )
  end
  local path = vim.fn.exepath(requirement.executable)
  if path ~= '' then result[#result + 1] = present_candidate(path, 'PATH') end
  return result
end

--- Directly probe one authoritative candidate.
---@param candidate table
---@return table|nil, string|nil
local function probe(candidate)
  if candidate.state == 'rejected' then return nil, candidate.reason end
  local stdout, stderr, exceeded = '', '', false
  local process
  --- Capture one bounded process stream.
  ---@param stream 'stdout'|'stderr'
  ---@return fun(error: string|nil, data: string|nil)
  local function capture(stream)
    return function(error, data)
      if error or not data or exceeded then return end
      local current = stream == 'stdout' and stdout or stderr
      local remaining = output_limit - #current
      if #data > remaining then
        exceeded = true
        if process then process:kill(15) end
      end
      data = data:sub(1, math.max(remaining, 0))
      if stream == 'stdout' then
        stdout = stdout .. data
      else
        stderr = stderr .. data
      end
    end
  end
  local ok
  ok, process = pcall(vim.system, { assert(candidate.real_path), '--version' }, {
    text = true,
    cwd = vim.fs.dirname(assert(candidate.real_path)),
    stdout = capture('stdout'),
    stderr = capture('stderr'),
  })
  if not ok then return nil, 'exit_nonzero' end
  local result = process:wait(2000)
  if exceeded then return nil, 'output_limit' end
  if result.code == 124 or result.signal == 15 then return nil, 'timeout' end
  if result.code ~= 0 then return nil, 'exit_nonzero' end
  local token = stdout:match('%f[%d](%d+%.%d+%.%d+%-?[%w%.%-]*%+?[%w%.%-]*)%f[^%w%.%+%-]')
    or stderr:match('%f[%d](%d+%.%d+%.%d+%-?[%w%.%-]*%+?[%w%.%-]*)%f[^%w%.%+%-]')
  local parsed = token and parse_semver(token)
  if not parsed then return nil, 'version_missing' end
  return { parsed = parsed, text = token }
end

--- Resolve all effective tool requirements without network access.
---@param resolution table
---@return table[], table[], table<string, table>
function M.resolve(resolution)
  local requirements = {}
  for _, definition in ipairs(compatibility.tools) do
    if vim.list_contains(resolution.effective_contributions, 'tooling.tools.' .. definition.identity) then
      local value = vim.deepcopy(definition)
      value.affected_operations = value.affected_operations or {}
      value.sources = {}
      for _, module in ipairs(resolution.modules) do
        if vim.list_contains(module.contributions, 'tooling.tools.' .. value.identity) then
          vim.list_extend(value.sources, vim.deepcopy(module.selection_sources))
        end
      end
      value.source = value.sources[1]
      requirements[value.identity] = value
    end
  end
  for target, peer in pairs(resolution.contribution_values or {}) do
    local identity = target:match('^tooling%.tools%.(.+)$')
    if identity then
      local value = vim.deepcopy(peer.value)
      value.identity, value.constraint, value.source, value.sources =
        identity, value.version, peer.source, { vim.deepcopy(peer.source) }
      value.affected_operations = {}
      requirements[identity] = value
    end
  end
  local records, diagnostics = {}, {}
  local identities = vim.tbl_keys(requirements)
  table.sort(identities)
  for _, identity in ipairs(identities) do
    local requirement = requirements[identity]
    local found = candidates(requirement)
    local authoritative
    for index, candidate in ipairs(found) do
      if candidate.state ~= 'absent' then
        authoritative = index
        break
      end
    end
    local record = {
      identity = identity,
      executable = requirement.executable,
      constraint = requirement.constraint,
      ownership = requirement.ownership,
      candidates = found,
      authoritative_candidate = authoritative,
      path = nil,
      source = nil,
      version = nil,
      state = 'absent',
      affected_operations = array(requirement.affected_operations),
      sources = array(requirement.sources),
      repair = 'Install through the declared ownership path, then check again.',
    }
    if authoritative then
      local candidate = found[authoritative]
      record.path, record.source = candidate.path, candidate.source
      local observed, reason = probe(candidate)
      if not observed then
        record.state, record.repair = 'unprobeable', 'Repair the executable/path so the fixed probe succeeds.'
        diagnostics[#diagnostics + 1] = diagnostic('tool.unprobeable', requirement, record, reason)
      else
        record.version = observed.text
        if constraint_allows(observed.parsed, requirement.constraint) then
          record.state, record.repair = 'satisfied', ''
        else
          record.state, record.repair = 'incompatible', 'Install a satisfying version or change the requirement.'
          diagnostics[#diagnostics + 1] = diagnostic('tool.incompatible', requirement, record)
        end
      end
    else
      diagnostics[#diagnostics + 1] = diagnostic('tool.absent', requirement, record)
    end
    records[#records + 1] = record
  end
  return records, diagnostics, requirements
end

--- Derive a command from one satisfied tool's absolute resolved real path.
---@param record table
---@param arguments? string[]
---@return string[]|nil
function M.command(record, arguments)
  if type(record) ~= 'table' or record.state ~= 'satisfied' or not record.authoritative_candidate then return nil end
  local candidate = record.candidates[record.authoritative_candidate]
  if not candidate or type(candidate.real_path) ~= 'string' or candidate.real_path:sub(1, 1) ~= '/' then return nil end
  local command = { candidate.real_path }
  vim.list_extend(command, vim.deepcopy(arguments or {}))
  return command
end

return M
