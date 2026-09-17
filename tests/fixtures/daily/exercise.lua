local plait = require('plait')
-- luacheck: push ignore 122
_G.daily_observations = {}
for _, filetype in ipairs({ 'lua', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }) do
  vim.bo.filetype = filetype
  local record = { requests = {} }
  for _, name in ipairs({ 'definition', 'references', 'hover', 'rename', 'code_action' }) do
    record.requests[name] = plait.actions.language[name]()
  end
  record.format = plait.actions.formatting.format()
  if record.format.status == 'started' then
    vim.wait(1000, function() return plait.inspect('operations', record.format.operation_id).state ~= 'pending' end)
    record.operation = plait.inspect('operations', record.format.operation_id)
  end
  local diagnostic = vim.iter(plait.inspect('diagnostics')):find(
    function(item) return item.code == 'formatting.chain_unavailable' and item.details.filetype == filetype end
  )
  record.format_diagnostic = diagnostic and diagnostic.details or vim.NIL
  record.previous = plait.actions.language.previous_diagnostic()
  record.next_diagnostic = plait.actions.language.next_diagnostic()
  local get_mode = vim.api.nvim_get_mode
  vim.api.nvim_get_mode = function() return { mode = 'i' } end
  record.completion = plait.actions.completion.trigger()
  vim.api.nvim_get_mode = get_mode
  local namespace = vim.api.nvim_create_namespace('daily-native-diagnostics')
  vim.diagnostic.set(namespace, 0, { { lnum = 0, col = 0, message = 'native diagnostic' } })
  record.native_navigation = plait.actions.language.next_diagnostic()
  vim.diagnostic.reset(namespace)
  _G.daily_observations[filetype] = record
end
-- luacheck: pop
