local renderer = dofile('tests/fixtures/daily/render.lua')
local mode = vim.g.daily_tool and (vim.g.daily_tool .. '-' .. vim.g.daily_tool_state) or 'satisfied'
local root = 'tests/fixtures/daily/rendered/' .. mode
vim.fn.mkdir(root, 'p')
for _, section in ipairs(renderer.sections) do
  if mode == 'satisfied' or (section ~= 'modules' and section ~= 'packages' and section ~= 'operations') then
    local record = renderer.capture(section)
    vim.fn.writefile(vim.split(record.json, '\n', { plain = true }), root .. '/' .. section .. '.json')
    vim.fn.writefile(vim.split(record.text, '\n', { plain = true }), root .. '/' .. section .. '.txt')
  end
end
dofile('tests/fixtures/daily/exercise.lua')
for _, section in ipairs({ 'operations', 'diagnostics' }) do
  local record = renderer.capture(section)
  vim.fn.writefile(vim.split(record.json, '\n', { plain = true }), root .. '/actions-' .. section .. '.json')
  vim.fn.writefile(vim.split(record.text, '\n', { plain = true }), root .. '/actions-' .. section .. '.txt')
end
vim.cmd('qa!')
