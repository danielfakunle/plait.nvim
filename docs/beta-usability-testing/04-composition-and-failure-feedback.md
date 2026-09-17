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
:Plait inspect capabilities formatting --verbose
:Plait inspect capabilities formatting --json
:Plait inspect tools ruff
:Plait inspect diagnostics
```

Expected: validation is valid; the local module and its dependency edges are visible; Python's external formatter chain is explicitly disabled by the owner override, which supersedes the local module's contribution; and the replacement retains explicit provenance. The formatting report identifies the disabled Python chain and the responsible override declaration. The concise report omits source lists; `--verbose` and JSON inspection retain full source details and available contribution history. Capability health is configuration-wide and describes the completed snapshot, while `language_servers` reports current-buffer readiness.

Disabling the Python chain does not disable all Python formatting. The default `formatting.lsp_fallback = 'if_no_formatter'` still permits formatting when an attached managed LSP client supports it. With `lsp_fallback = 'never'`, no LSP fallback is permitted; this policy applies to the whole formatting capability, not just Python. After apply, check that a Python buffer with a managed formatting-capable LSP client can still use `:Plait format` with the chain disabled.

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

Use another new app name with the canonical config:

```fish
set -gx NVIM_APPNAME plait-beta-guarded-ux
mkdir -p ~/.config/$NVIM_APPNAME
cp ~/.config/plait-beta-ux/init.lua ~/.config/$NVIM_APPNAME/init.lua
```

Add this before `validate()`:

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

Use a new app name with the canonical config:

```fish
set -gx NVIM_APPNAME plait-beta-collision-ux
mkdir -p ~/.config/$NVIM_APPNAME
cp ~/.config/plait-beta-ux/init.lua ~/.config/$NVIM_APPNAME/init.lua
```

Before requiring Plait, add a foreign mapping:

```lua
vim.keymap.set('n', '<leader>cf', function() end, { desc = 'Foreign formatter' })
```

Start Neovim and check the visible feedback before rendering `_G.plait_apply` and inspecting diagnostics:

```vim
:lua print(require('plait').render(_G.plait_apply))
:Plait inspect diagnostics
```

Expected: one concise error notification says application was blocked and no managed effects were applied, names the foreign format mapping, gives a repair, and points to `:Plait inspect diagnostics effect.collision`. Apply is invalid before any managed effect runs; a collision diagnostic identifies the mapping and the Plait effect that would overwrite it; all effects remain pending in `:Plait inspect effects`; and the foreign mapping remains intact.

Repeat after restarting with `operation_feedback = 'all'` and then `'silent'`. Both `errors` (the default) and `all` produce one notification; `silent` produces none. The explicit apply result and inspection diagnostics remain available under every setting.

Restart with the collision removed and confirm application succeeds without a stale blocked-application notification. Then test a compatible repair by setting `formatting.mappings.format = false`; expected: Plait deliberately owns no format mapping and does not report a collision or a blocked-application notification. Routine partial unavailability still uses existing action-time feedback.

## 5. Test conflict and dependency diagnostics

Use a final new app name:

```fish
set -gx NVIM_APPNAME plait-beta-invalid-ux
mkdir -p ~/.config/$NVIM_APPNAME
```

Create `~/.config/$NVIM_APPNAME/init.lua` with this minimal config:

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

## 6. Clean up all remaining Beta test data

Quit every Beta test Neovim instance. Then remove each app's config, provider packages, state, and cache, followed by the shared Lua and TypeScript project workspace:

```fish
rm -rf \
  ~/.config/plait-beta-ux \
  ~/.local/share/plait-beta-ux \
  ~/.local/state/plait-beta-ux \
  ~/.cache/plait-beta-ux \
  ~/.config/plait-beta-compose-ux \
  ~/.local/share/plait-beta-compose-ux \
  ~/.local/state/plait-beta-compose-ux \
  ~/.cache/plait-beta-compose-ux \
  ~/.config/plait-beta-provider-ux \
  ~/.local/share/plait-beta-provider-ux \
  ~/.local/state/plait-beta-provider-ux \
  ~/.cache/plait-beta-provider-ux \
  ~/.config/plait-beta-guarded-ux \
  ~/.local/share/plait-beta-guarded-ux \
  ~/.local/state/plait-beta-guarded-ux \
  ~/.cache/plait-beta-guarded-ux \
  ~/.config/plait-beta-collision-ux \
  ~/.local/share/plait-beta-collision-ux \
  ~/.local/state/plait-beta-collision-ux \
  ~/.cache/plait-beta-collision-ux \
  ~/.config/plait-beta-invalid-ux \
  ~/.local/share/plait-beta-invalid-ux \
  ~/.local/state/plait-beta-invalid-ux \
  ~/.cache/plait-beta-invalid-ux \
  /tmp/plait-beta-ux
```

All targets are literal Beta-test paths; the command does not depend on the current value of `NVIM_APPNAME` or `PLAIT_UX`. After cleanup, the complete suite can be rerun from the first bootstrap step without stale lockfiles, packages, tools, editor state, caches, or project dependencies.

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
