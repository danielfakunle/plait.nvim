local M = {
  version = '0.1.0-dev',
  neovim = {
    constraint = '>=0.12.5,<0.13.0',
    minimum = { 0, 12, 5 },
    maximum_exclusive = { 0, 13, 0 },
  },
  platforms = {
    Darwin = { arm64 = true, x86_64 = true },
    Linux = { arm64 = true, x86_64 = true, libc = 'glibc' },
  },
  providers = {
    {
      identity = 'nvim-lspconfig',
      source = 'https://github.com/neovim/nvim-lspconfig',
      commit = '615d7b2712efb2f530a83a9d0466acafba6b1d6f',
    },
    {
      identity = 'blink.cmp',
      source = 'https://github.com/Saghen/blink.cmp',
      commit = '78336bc89ee5365633bcf754d93df01678b5c08f',
    },
    {
      identity = 'conform.nvim',
      source = 'https://github.com/stevearc/conform.nvim',
      commit = '016802de402556da54c36bd7359b441266b01cdd',
    },
    {
      identity = 'mason.nvim',
      source = 'https://github.com/mason-org/mason.nvim',
      commit = '2a6940af80375532e5e9e7c1f2fc6319a1b7a69d',
    },
  },
  registry = {
    release = '2026-09-07-abaft-pruner',
    commit = '93b6e9e56b647c1aa6a2ae529e50e0ae3367a885',
  },
  tools = {
    {
      identity = 'lua-language-server',
      executable = 'lua-language-server',
      constraint = '=3.19.1',
      exact = { 3, 19, 1 },
      mason = true,
    },
    { identity = 'stylua', executable = 'stylua', constraint = '=2.5.2', exact = { 2, 5, 2 }, mason = true },
    {
      identity = 'tsc',
      executable = 'tsc',
      constraint = '>=7.0.0,<8.0.0',
      minimum = { 7, 0, 0 },
      maximum_exclusive = { 8, 0, 0 },
      workspace = true,
    },
    {
      identity = 'oxfmt',
      executable = 'oxfmt',
      constraint = '=0.66.0',
      exact = { 0, 66, 0 },
      mason = true,
      workspace = true,
    },
    {
      identity = 'node',
      executable = 'node',
      constraint = '>=22.12.0 (covers tsc and oxfmt)',
      minimum = { 22, 12, 0 },
    },
  },
}

return M
