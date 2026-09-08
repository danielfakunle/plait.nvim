local state = require('plait.state')

if state.bootstrap_initialized then return end
state.bootstrap_initialized = true

if vim.fn.exists(':Plait') == 0 then
  vim.api.nvim_create_user_command(
    'Plait',
    function(command) require('plait.command').dispatch(command.fargs) end,
    { nargs = '+' }
  )
else
  state.bootstrap_diagnostics = {
    {
      code = 'bootstrap.command_collision',
      severity = 'error',
      summary = 'Command Plait already exists; :Plait was not registered.',
      repair = 'Remove or rename the existing command, then restart.',
      source = nil,
      related_sources = {},
      details = { identity = 'Plait', observed_owner = 'external' },
    },
  }
end
