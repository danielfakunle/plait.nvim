# Beta Bootstrap and Package Procedure

This procedure validates app-name isolation, environment qualification, exact provider requirements, interactive installation, package synchronization, and restart feedback.

## 1. Create an isolated Neovim app

Start a fresh Fish shell:

```fish
set -gx PLAIT_REPO /Users/daniel/Developer/plait.nvim
set -gx NVIM_APPNAME plait-beta-ux
set -gx PLAIT_UX /tmp/plait-beta-ux

mkdir -p ~/.config/$NVIM_APPNAME $PLAIT_UX/lua-project
```

`NVIM_APPNAME` makes Neovim use app-specific config, data, state, and cache directories. Do not set any `XDG_*` variables. Use a never-before-used app name to repeat the first-install journey.

Confirm prerequisites:

```fish
nvim --version
git --version
```

Expected: Neovim `>=0.12.5,<0.13.0` and Git are available on a supported macOS or glibc Linux platform.

## 2. Create the canonical Beta configuration

Create `~/.config/$NVIM_APPNAME/init.lua`:

```lua
vim.opt.runtimepath:prepend(vim.env.PLAIT_REPO)

local plait = require('plait')
local config = plait.config()

config:select({
  'editor',
  'language',
  'completion',
  'formatting',
  'tooling',
  'lang.lua',
})

local validation = config:validate()
assert(validation.status == 'valid', vim.inspect(validation.diagnostics))

_G.plait_validation = validation
_G.plait_apply = config:apply()
```

Create a minimal project file:

```fish
printf 'local greeting = "hello"\nprint(greeting)\n' >$PLAIT_UX/lua-project/main.lua
```

## 3. Exercise first-start consent

Run:

```fish
nvim $PLAIT_UX/lua-project/main.lua
```

Expected: Plait asks whether to install four provider packages. First choose **Cancel**.

Inside Neovim, run:

```vim
:lua print(require('plait').render(_G.plait_apply))
:Plait inspect packages
:Plait inspect effects
:Plait inspect diagnostics
```

Expected:

- Apply is `unavailable` with reason `consent_denied`.
- `blink.cmp`, `conform.nvim`, `mason.nvim`, and `nvim-lspconfig` are `absent`.
- Managed effects remain pending rather than partially applied.
- Diagnostics name the missing packages, exact required commits, and a repair.

Quit and start the same command again. Choose **Install**.

Expected:

- One consent covers the complete provider set.
- Startup completes and `_G.plait_apply.status` is `performed`.
- `:Plait inspect packages` reports all four packages as `satisfied`, with matching required and active sources and commits.
- `:Plait inspect effects` reports every effect as `completed`; no plugin entrypoint unexpectedly overrides the managed setup.

## 4. Inspect the effective plan and compatibility evidence

Run:

```vim
:Plait inspect modules
:Plait inspect capabilities
:Plait inspect packages
:Plait inspect tools
:Plait inspect effects
:Plait inspect operations
:checkhealth plait
```

Expected:

- Modules appear in selection/dependency order and each selected module appears once.
- `lang.lua` shows contributions for `lua_ls`, `stylua`, Lua formatting, and both tool requirements.
- Package records identify the responsible capabilities and exact qualified revisions.
- Tool records distinguish path candidates, authoritative candidate, version constraint, ownership, state, and repair.
- Health reports the Neovim/platform qualification, native package path, Git, provider revisions, Mason registry, tools, clipboard path, and Blink fuzzy implementation.
- Inspection and health agree about degraded or satisfied states.

## 5. Exercise package synchronization

With all packages satisfied, run:

```vim
:Plait packages sync
:Plait inspect operations
```

Expected: synchronization is immediately `performed`, changes no packages, and does not create a misleading pending operation.

To test an explicit resynchronization without damaging the checkout, choose a new app name in Fish and copy the same config:

```fish
set -gx NVIM_APPNAME plait-beta-sync-ux
mkdir -p ~/.config/$NVIM_APPNAME
cp ~/.config/plait-beta-ux/init.lua ~/.config/$NVIM_APPNAME/init.lua
nvim $PLAIT_UX/lua-project/main.lua
```

Cancel the startup installation prompt, then run:

```vim
:Plait packages sync!
:Plait inspect operations
```

Wait until the operation is no longer pending and inspect again. Expected:

- The command immediately returns `started` with an operation ID.
- The operation record exposes targets, timestamps, final state, result, and any diagnostic codes.
- Successful packages become `restart_required`; apply is not retried in the mutated process.
- After quitting and restarting, all packages recompute as `satisfied` and apply completes.

## 6. Clean up the synchronization app

Quit Neovim, then remove the disposable synchronization app's config, provider packages, state, and cache:

```fish
rm -rf \
  ~/.config/plait-beta-sync-ux \
  ~/.local/share/plait-beta-sync-ux \
  ~/.local/state/plait-beta-sync-ux \
  ~/.cache/plait-beta-sync-ux
```

Keep `plait-beta-ux` and `/tmp/plait-beta-ux` for the remaining Beta procedures. The final cleanup in the composition and failure-feedback procedure removes them.

## Feedback rubric

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| App-name isolation | | | | |
| Install consent | | | | |
| Exact package evidence | | | | |
| Sync operation feedback | | | | |
| Restart requirement | | | | |
| Compatibility health | | | | |

Record any prompt, state name, or repair instruction that did not make the next safe action obvious.
