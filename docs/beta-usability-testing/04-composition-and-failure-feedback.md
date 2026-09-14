# Beta Composition and Failure-Feedback Procedure

This procedure tests owner-local composition, override intent, provider escape hatches, preflight collisions, and actionable invalid-state inspection. It uses separate app names so each scenario gets exactly one process-wide collector.

## 1. Test a local module and explicit overrides

In Fish:

```fish
set -gx PLAIT_REPO /Users/daniel/Developer/plait.nvim
set -gx NVIM_APPNAME plait-beta-compose-ux
set -gx PLAIT_UX /tmp/plait-beta-ux
mkdir -p ~/.config/$NVIM_APPNAME
```

Create `~/.config/$NVIM_APPNAME/init.lua`:

```lua
vim.opt.runtimepath:prepend(vim.env.PLAIT_REPO)

local plait = require('plait')
local python = plait.module({
  name = 'local.lang.python',
  provides = { 'local.lang.python' },
  requires = { 'language', 'formatting', 'tooling' },
  contribute = {
    language = {
      servers = {
        basedpyright = {
          filetypes = { 'python' },
          tool = 'basedpyright',
        },
      },
    },
    formatting = {
      formatters = { ruff = { tool = 'ruff' } },
      by_filetype = { python = { 'ruff' } },
    },
    tooling = {
      tools = {
        basedpyright = {
          executable = 'basedpyright-langserver',
          version = '>=1.31.1',
          ownership = 'project',
          workspace_paths = { '.venv/bin/basedpyright-langserver' },
        },
        ruff = {
          executable = 'ruff',
          version = '>=0.11.0',
          ownership = 'project',
          workspace_paths = { '.venv/bin/ruff' },
        },
      },
    },
  },
})

local config = plait.config()
config:select({ 'language', 'formatting', 'tooling', python })
config:override({
  formatting = { by_filetype = { python = plait.disable() } },
  tooling = {
    tools = {
      ruff = plait.replace({
        executable = 'ruff',
        version = '>=0.11.0',
        ownership = 'project',
        workspace_paths = { '.venv/bin/ruff' },
      }),
    },
  },
})

_G.plait_validation = config:validate()
```

Start Neovim and inspect:

```fish
nvim
```

```vim
:lua print(require('plait').render(_G.plait_validation))
:Plait inspect modules local.lang.python
:Plait inspect capabilities formatting
:Plait inspect tools ruff
:Plait inspect diagnostics
```

Expected: validation is valid; the local module and its dependency edges are visible; Python formatting is deliberately disabled rather than silently won by call order; and the replacement retains explicit provenance.

## 2. Test an accepted provider escape hatch

Use a new app name and copy the canonical Beta config:

```fish
set -gx NVIM_APPNAME plait-beta-provider-ux
mkdir -p ~/.config/$NVIM_APPNAME
cp ~/.config/plait-beta-ux/init.lua ~/.config/$NVIM_APPNAME/init.lua
```

Before `validate()`, add:

```lua
config:providers({
  language = {
    ['vim.lsp'] = {
      servers = {
        lua_ls = { settings = { Lua = { hint = { enable = true } } } },
      },
    },
  },
  completion = {
    ['blink.cmp'] = {
      setup = { appearance = { nerd_font_variant = 'mono' } },
    },
  },
  formatting = {
    ['conform.nvim'] = {
      setup = { log_level = vim.log.levels.DEBUG },
      formatters = { stylua = { args = { '--search-parent-directories', '-' } } },
    },
  },
  tooling = {
    ['mason.nvim'] = { setup = { ui = { border = 'single' } } },
  },
})
```

Start Neovim. Expected: validation and apply succeed; the Mason window uses a single border; the inspected capability configurations show provider payloads and provenance; and Plait-owned setup remains intact beside the opaque options.

## 3. Test guarded provider ownership

Use another new app name with the canonical config and add this before `validate()`:

```lua
config:providers({
  completion = {
    ['blink.cmp'] = { setup = { keymap = { preset = 'none' } } },
  },
  language = {
    ['vim.lsp'] = {
      servers = { lua_ls = { cmd = { 'other-language-server' } } },
    },
  },
  formatting = {
    ['conform.nvim'] = { formatters = { stylua = { command = 'other-stylua' } } },
  },
  tooling = {
    ['mason.nvim'] = { setup = { PATH = 'prepend' } },
  },
})
```

Expected:

- Validation is invalid with `provider.guarded_path` diagnostics for each attempt to replace integration-owned behavior.
- Diagnostics identify the provider path, source, ownership boundary, and repair.
- No packages, tools, or effects are applied.
- `:Plait inspect diagnostics provider.guarded_path` groups all matching diagnostics.

Assess whether the accepted and rejected examples make the provider escape-hatch boundary coherent.

## 4. Test managed-effect collision preflight

Use a new app name with the canonical config. Before requiring Plait, add a foreign mapping:

```lua
vim.keymap.set('n', '<leader>cf', function() end, { desc = 'Foreign formatter' })
```

Start Neovim and render `_G.plait_apply` before inspecting diagnostics:

```vim
:lua print(require('plait').render(_G.plait_apply))
:Plait inspect diagnostics
```

Expected: apply is invalid before any managed effect runs; a collision diagnostic identifies the mapping and the Plait effect that would overwrite it; all effects remain pending; and the foreign mapping remains intact.

Repeat with the collision removed and confirm application succeeds. Then test a compatible repair by setting `formatting.mappings.format = false`; expected: Plait deliberately owns no format mapping and does not report a collision.

## 5. Test conflict and dependency diagnostics

Use a final new app name with this minimal config:

```lua
vim.opt.runtimepath:prepend(vim.env.PLAIT_REPO)
local plait = require('plait')
local config = plait.config()

config:select({ 'completion' })
config:configure({ formatting = { timeout_ms = 0 } })
config:configure({ formatting = { timeout_ms = 2000 } })

_G.plait_validation = config:validate()
```

Start Neovim and render the invalid validation result before inspecting its structured snapshot:

```vim
:lua print(require('plait').render(_G.plait_validation))
:Plait inspect diagnostics
```

Expected diagnostics include the missing `language` dependency, invalid conflicting configuration, precise source locations, related sources where applicable, and concrete repairs. The invalid snapshot contains diagnostics but no effective modules, capabilities, packages, tools, or effects.

## Feedback rubric

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Local-module vocabulary | | | | |
| Replacement/disable intent | | | | |
| Accepted provider customization | | | | |
| Guarded-path explanation | | | | |
| Collision preflight | | | | |
| Conflict/dependency repair | | | | |
| Provenance usefulness | | | | |

Record any boundary that required provider or implementation knowledge to understand.
