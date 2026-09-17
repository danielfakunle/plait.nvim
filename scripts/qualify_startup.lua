-- Run from the repository root: nvim --headless --clean -u scripts/qualify_startup.lua
-- Set PLAIT_QUALIFY_JOURNEY=typescript for the project-local fixture. Elapsed time is advisory.
local journey = vim.env.PLAIT_QUALIFY_JOURNEY or 'lua'
assert(journey == 'lua' or journey == 'typescript', 'expected lua or typescript')
local counts = {}
local system = vim.system
-- luacheck: push ignore 122
vim.system = function(command, ...)
  if command[2] == '--version' then
    local identity = table.concat(command, '\0')
    counts[identity] = (counts[identity] or 0) + 1
  end
  return system(command, ...)
end
-- luacheck: pop
local started = vim.uv.hrtime()
local fixture = journey == 'lua' and 'tests/fixtures/lua_quickstart/init.lua'
  or 'tests/fixtures/typescript_apply/init.lua'
dofile(fixture)
local measured = journey == 'lua' and _G.lua_startup_probe_counts_at_apply or counts
local elapsed = (vim.uv.hrtime() - started) / 1e6
local probes = {}
for command, count in pairs(measured) do
  local executable = command:match('^[^%z]+')
  probes[vim.fs.basename(executable)] = count
end
local result = journey == 'lua' and _G.lua_quickstart.result or _G.typescript_apply_result
io.write(vim.json.encode({ journey = journey, elapsed_ms = elapsed, probes = probes, status = result.status }) .. '\n')
vim.cmd('qa!')
