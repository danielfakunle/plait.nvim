vim.opt.runtimepath:prepend(vim.fn.getcwd())

_G.M = require('plait')
dofile('tests/fixtures/editor_apply_descendant/apply.lua')
