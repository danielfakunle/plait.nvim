local M = {}

--- Build one closed managed-effect record.
---@param responsible_capability string
---@param identity string
---@param stage integer
---@param provider string|nil
---@param dependencies string[]
---@param sources table[]
---@return table
function M.new(responsible_capability, identity, stage, provider, dependencies, sources)
  return {
    identity = identity,
    stage = stage,
    responsible_capability = responsible_capability,
    provider = provider or vim.NIL,
    dependencies = dependencies,
    state = 'pending',
    sources = vim.deepcopy(sources),
    error = vim.NIL,
  }
end

return M
