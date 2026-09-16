vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:append(vim.fn.stdpath('data') .. '/site')

package.preload.mason = function()
  return { setup = function() end }
end
require('plait.packages').install_for_apply = function() return true end

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/bin', 'p')
local tool_path = root .. '/bin/plait-freshness-demo'
vim.fn.writefile({ '#!/bin/sh', 'echo 0.1.0' }, tool_path)
vim.fn.setfperm(tool_path, 'rwxr-xr-x')
tool_path = assert(vim.uv.fs_realpath(tool_path))
_G.tool_path = tool_path
vim.api.nvim_set_option_value('swapfile', false, { buf = 0 })
vim.api.nvim_buf_set_name(0, root .. '/main.lua')

_G.tool_probes = 0
local system = vim.system
vim.system = function(command, ...) -- luacheck: ignore 122
  if command[1] == tool_path then _G.tool_probes = _G.tool_probes + 1 end
  return system(command, ...)
end

local M = require('plait')
_G.M = M
local demo = M.module({
  name = 'local.tools.freshness',
  provides = { 'local.tools.freshness' },
  requires = { 'tooling' },
  contribute = {
    tooling = {
      tools = {
        demo = {
          executable = 'plait-freshness-demo',
          version = '=1.2.3',
          ownership = 'project',
          workspace_paths = { 'bin/plait-freshness-demo' },
        },
      },
    },
  },
})
local config = M.config()
config:select({ 'tooling', demo })
config:configure({
  tooling = { check_on_startup = _G.check_on_startup ~= false },
  operation_feedback = _G.feedback_policy or 'errors',
})
if not _G.skip_validation then
  _G.validated = config:validate()
  _G.startup_probes = _G.tool_probes
end
_G.applied = config:apply()
