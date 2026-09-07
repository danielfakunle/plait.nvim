local expect = MiniTest.expect
local child = require('tests.helpers').new_clean_neovim()

before_each(function() child.setup() end)

teardown(function() child.stop() end)

describe('plugin', function()
  it('works', function()
    child.lua([[M.run()]])
    local output = child.cmd_capture('messages')
    expect.equality(output, 'Hello from plugin!')
  end)
end)
