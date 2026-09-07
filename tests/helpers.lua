local M = {}

function M.new_clean_neovim()
  ---@class MiniTest.child
  ---@field setup fun()
  local child = MiniTest.new_child_neovim()

  child.setup = function()
    child.restart({ '--clean', '-u', 'scripts/minimal_init.lua' })
    child.bo.readonly = false
    child.lua([[M = require('plait')]])
  end

  return child
end

return M
