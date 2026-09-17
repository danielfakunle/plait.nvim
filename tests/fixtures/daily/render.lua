local M = {}

function M.normalize(value)
  local function replace(old, new)
    value = value:gsub(old:gsub('([^%w])', '%%%1'), function() return new end)
  end
  replace(vim.uv.fs_realpath(_G.daily_project), '<project>')
  replace(_G.daily_project, '<project>')
  replace(vim.env.VIMRUNTIME, '<runtime>')
  replace(vim.fn.getcwd() .. '/', '')
  replace('/private/tmp/', '/tmp/')
  return (value:gsub('%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ', '<timestamp>'))
end

M.sections =
  { 'modules', 'capabilities', 'effects', 'packages', 'tools', 'diagnostics', 'operations', 'language_servers' }

function M.capture(section)
  local buffer = vim.api.nvim_get_current_buf()
  local json = vim.api.nvim_exec2('Plait inspect ' .. section .. ' --json', { output = true }).output
  vim.cmd('Plait inspect ' .. section)
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  vim.api.nvim_set_current_buf(buffer)
  return { json = M.normalize(json:sub(#section + 3)), text = M.normalize(text) }
end

return M
