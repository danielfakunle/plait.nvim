# Isolated Beta Inspection and Failure-Feedback Procedure

This standalone procedure exercises PRO-167 through PRO-170: disabled-chain
explanations, compatible native hover, blocked-application feedback, and concise
configuration-wide inspection. It does not require or reuse any other Beta app.
Run against the checkout containing all four implementations.

Record Neovim version, OS, terminal/shell, checkout commit (and whether it has
uncommitted changes), date, and the scenario for each observation. Judge the
messages before reading the expectations: could you explain what happened and
find the repair from the report alone?

## 1. Create a disposable app and workspace

Use a fresh Fish shell. These literal paths must be unused; if they already
contain an earlier run, finish its cleanup before restarting this procedure.

```fish
set -gx PLAIT_REPO /Users/daniel/Developer/plait.nvim
set -gx NVIM_APPNAME plait-beta-feedback-regression-ux
set -gx PLAIT_FEEDBACK_UX /tmp/plait-beta-feedback-regression-ux
set -gx PLAIT_FEEDBACK_CASE baseline
set -gx PLAIT_FEEDBACK_POLICY errors
mkdir -p ~/.config/plait-beta-feedback-regression-ux $PLAIT_FEEDBACK_UX
cd $PLAIT_FEEDBACK_UX
nvim --version
git --version
```

Expected prerequisites: supported Neovim (`>=0.12.5,<0.13.0`), macOS or supported
glibc Linux, Git, and network access for this app's provider packages and Mason
tools. Do not change `XDG_*` variables or copy an existing Neovim configuration.

Create `main.lua`, `.luarc.json`, and `main.ts` in this workspace:

```lua title="main.lua"
local function greet(name)
  return 'hello ' .. name
end

local message = greet('Plait')
print(message)
```

```json title=".luarc.json"
{}
```

```typescript title="main.ts"
const greeting = "hello";
console.log(greeting);
```

Create `~/.config/plait-beta-feedback-regression-ux/init.lua`:

```lua
vim.opt.runtimepath:prepend(vim.env.PLAIT_REPO)
vim.g.mapleader = ' '

local scenario = vim.env.PLAIT_FEEDBACK_CASE or 'baseline'
if scenario == 'collision' or scenario == 'mapping-disabled' then
  vim.keymap.set('n', '<leader>cf', function()
    print('Foreign formatter remains intact')
  end, { desc = 'Foreign formatter' })
end

local plait = require('plait')
local fixture = plait.module({
  name = 'local.feedback.fixture',
  provides = { 'local.feedback.fixture' },
  requires = { 'formatting', 'tooling' },
  contribute = {
    formatting = {
      -- Synthetic Python chain for provenance inspection only; never execute it.
      by_filetype = { python = { 'stylua' }, typescript = { 'oxfmt' } },
      formatters = { oxfmt = { tool = 'oxfmt' } },
    },
    tooling = {
      tools = {
        oxfmt = {
          executable = 'oxfmt',
          version = '=0.66.0',
          ownership = 'project',
          workspace_paths = { '.missing-feedback-tools/oxfmt' },
        },
      },
    },
  },
})

local config = plait.config()
config:select({ 'language', 'formatting', 'tooling', 'lang.lua', fixture })
config:configure({
  operation_feedback = vim.env.PLAIT_FEEDBACK_POLICY or 'errors',
  formatting = {
    on_save = false,
    timeout_ms = 5000,
    lsp_fallback = scenario == 'fallback-never' and 'never' or 'if_no_formatter',
  },
})
config:override({ formatting = { by_filetype = { python = plait.disable() } } })

if scenario == 'fallback' or scenario == 'fallback-never' then
  config:override({ formatting = { by_filetype = { lua = plait.disable() } } })
end
if scenario == 'explicit-hover' then
  config:configure({ language = { mappings = { hover = 'K' } } })
end
if scenario == 'mapping-disabled' then
  config:configure({ formatting = { mappings = { format = false } } })
end
if scenario == 'late-foreign-hover' then
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'lua',
    callback = function(event)
      vim.keymap.set('n', 'K', function()
        print('Foreign hover remains intact')
      end, { buffer = event.buf, desc = 'hover' })
    end,
  })
end

_G.feedback_config = config
_G.plait_validation = config:validate()
assert(_G.plait_validation.status == 'valid', plait.render(_G.plait_validation))
if scenario ~= 'preflight-native' and scenario ~= 'preflight-foreign' then
  _G.plait_apply = config:apply()
end
```

This selects no completion or editor module. Python is an inspection fixture;
actual disabled-chain fallback is exercised in Lua with a managed LuaLS client.
The nonexistent project-owned `oxfmt` path keeps TypeScript formatting unavailable
even if your normal environment has that executable installed.

## 2. Bootstrap this app only

```fish
nvim main.lua
```

Accept the provider-package installation prompt. Inspect application and tools:

```vim
:lua print(require('plait').render(_G.plait_apply))
:Plait inspect packages
:Plait tooling install lua-language-server
:Plait tooling install stylua
:Plait inspect operations
```

Wait for each installation to finish before starting the next. Inspect its
operation and record any failure. Target these two tools individually; do not
use `ensure` to attempt installation of the intentionally missing project tool.
Quit and restart `nvim main.lua` once they are installed.

```vim
:Plait tooling check
:Plait inspect tools
:Plait inspect language_servers
```

Expected: apply is `performed`, packages are satisfied, LuaLS and StyLua are
satisfied, `oxfmt` is absent, and LuaLS attaches to `main.lua`. Tool qualification
uses this checkout's compatibility manifest (currently LuaLS 3.19.1 and StyLua
2.5.2). If installation or attachment fails, record an environment blocker rather
than treating later hover/fallback checks as passed.

## 3. Judge concise, verbose, and structured inspection

From `main.lua`, run each command separately and close the report with `q`:

```vim
:Plait inspect capabilities formatting
:Plait inspect capabilities formatting --verbose
:Plait inspect --verbose capabilities formatting
:Plait inspect capabilities formatting --json
:Plait inspect capabilities formatting --json --verbose
:Plait inspect capabilities formatting
```

Expected:

- Concise output identifies the disabled Python chain, its owner disable override,
  and the superseded module contribution. It explains that `if_no_formatter`
  permits managed LSP fallback; it does not claim all Python formatting is disabled.
- Effective Lua and TypeScript chains remain understandable. Full file/line/path
  source lists do not dominate the concise report.
- Formatting remains `DEGRADED`, explicitly described as configuration-wide health
  from a completed snapshot. The problem identifies `oxfmt`, TypeScript, and a
  repair; it does not imply that Lua formatting is unavailable.
- Both placements of `--verbose` work and show full source locations and available
  contribution history, including `local.feedback.fixture` and its superseded
  Python declaration. The final concise command proves verbosity is per command.
- Both JSON commands retain full structured evidence and return equivalent data.
  For exact comparison, save each report with `:write /tmp/feedback-json-a.json`
  and `:write /tmp/feedback-json-b.json`, respectively, then run
  `diff -u /tmp/feedback-json-a.json /tmp/feedback-json-b.json` in Fish.

Reopen `main.lua`, change a deliberately unformatted line to
`local message=greet( 'Plait' )`, and run `:Plait format`. Expected: Lua formatting
works despite configuration-wide TypeScript degradation. No blocked-application
notification appears for this routine partial unavailability under `errors`.

Open `main.ts` and repeat formatting capability inspection. The report still
describes the same configured capability. Run `:Plait format`: it should now give
action-time unavailable feedback with a repair. Do not install the missing tool.

## 4. Verify native hover and ownership on attachment/detachment

Quit. For each scenario below, start a fresh process:

```fish
set -gx PLAIT_FEEDBACK_CASE baseline
nvim main.lua
```

Repeat later with `PLAIT_FEEDBACK_CASE explicit-hover`. Wait for LuaLS attachment,
then place the cursor on `greet` and press `K`.

```vim
:verbose nmap <buffer> K
:Plait inspect diagnostics language.mapping_collision
```

Expected for both scenarios: hover works, the native mapping remains intact, and
there is no `language.mapping_collision` for `K`. Record mapping evidence before
detaching (this callback capture is a test probe, not an authoring requirement):

```vim
:lua _G.feedback_hover = vim.fn.maparg('K', 'n', false, true).callback
:lua for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do vim.lsp.buf_detach_client(0, c.id) end
:lua print(vim.fn.maparg('K', 'n', false, true).callback == _G.feedback_hover)
```

Expected: the comparison is `true`; Plait did not delete a native-owned mapping.
Do not expect hover requests to succeed without an attached client. Restart to
check attachment again.

Now restart with `PLAIT_FEEDBACK_CASE late-foreign-hover`. Wait for attachment,
press `K`, and inspect the same diagnostics. Expected: the foreign callback prints
its message and remains intact, and `language.mapping_collision` identifies `K`
and gives a repair. A description of `hover` does not establish compatibility.

## 5. Verify native compatibility during application preflight

The preceding check exercised attachment after apply. This check deliberately
attaches a client before apply, using only this disposable app's installed LuaLS.

Quit and launch:

```fish
set -gx PLAIT_FEEDBACK_CASE preflight-native
nvim main.lua
```

Start a temporary client, wait for attachment, and capture the native mapping:

```vim
:lua vim.lsp.start({ name = 'feedback-preflight', cmd = { vim.fn.stdpath('data') .. '/mason/bin/lua-language-server' }, root_dir = vim.fn.getcwd() })
:lua print(#vim.lsp.get_clients({ bufnr = 0 }))
:lua _G.feedback_hover = vim.fn.maparg('K', 'n', false, true).callback
:lua _G.plait_apply = _G.feedback_config:apply(); print(require('plait').render(_G.plait_apply))
:lua print(vim.fn.maparg('K', 'n', false, true).callback == _G.feedback_hover)
:Plait inspect diagnostics effect.collision
```

Expected: a client is attached before apply, apply is `performed`, the callback
comparison is `true`, and no collision is attributed to native `K`. Other mappings
remain subject to normal ownership protection; record unexpected collisions.

Quit and repeat with `PLAIT_FEEDBACK_CASE preflight-foreign`. Start the temporary
client as above, but before applying replace `K`:

```vim
:lua vim.keymap.set('n', 'K', function() print('Foreign hover remains intact') end, { buffer = 0, desc = 'hover' })
:lua _G.plait_apply = _G.feedback_config:apply(); print(require('plait').render(_G.plait_apply))
:Plait inspect diagnostics effect.collision
:Plait inspect effects
```

Expected: apply is invalid, the collision identifies buffer-local `K`, all Plait
managed effects remain pending, and pressing `K` still invokes the foreign callback.
The temporary client was started outside Plait; its attachment does not count as a
Plait managed effect running after failed preflight.

## 6. Judge blocked-application feedback and repairs

Quit. Run this scenario once for each feedback policy (`errors`, `all`, `silent`),
always quitting before changing the environment:

```fish
set -gx PLAIT_FEEDBACK_CASE collision
set -gx PLAIT_FEEDBACK_POLICY errors
nvim main.lua
```

Before opening inspection, judge whether startup makes the blocked application
obvious and whether its message provides the next step. Use `:messages` if needed
to recover transient text. Then run:

```vim
:lua print(require('plait').render(_G.plait_apply))
:Plait inspect diagnostics effect.collision
:Plait inspect effects
:verbose nmap <leader>cf
```

Expected: `errors` and `all` each show one blocked-application error notification
for this single apply attempt. It states no managed effects were applied, names
the foreign format mapping, gives a repair, and points to diagnostic inspection.
`silent` suppresses automatic notification but retains the same explicit result
and evidence. All effects are pending and Space `c` `f` invokes the foreign callback.
Do not count your explicit result rendering as an automatic notification.

Test both repairs in fresh processes with policy restored to `errors`:

```fish
set -gx PLAIT_FEEDBACK_POLICY errors
set -gx PLAIT_FEEDBACK_CASE baseline
nvim main.lua
```

Expected: removing the collision allows application, with no stale blocked message.
Quit and restart with `PLAIT_FEEDBACK_CASE mapping-disabled`. Expected: apply
succeeds, the foreign formatter mapping remains usable, Plait owns no format
mapping, and there is no mapping collision or blocked-application notification.

## 7. Verify disabled-chain LSP fallback through a real action

Quit and launch:

```fish
set -gx PLAIT_FEEDBACK_CASE fallback
nvim main.lua
```

Wait for managed LuaLS attachment. Confirm it supports formatting:

```vim
:lua for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do print(c.name, c:supports_method('textDocument/formatting', 0)) end
:Plait inspect capabilities formatting
```

Expected: a managed formatting-capable client is attached, the Lua chain is
explicitly disabled, and inspection explains permitted LSP fallback. Change a line
to `local message=greet( 'Plait' )` and run `:Plait format`. Expected: the action
formats through LuaLS despite the disabled external chain. If LuaLS does not
support formatting, record this check as blocked rather than passed.

Quit without saving that edit and restart with `PLAIT_FEEDBACK_CASE fallback-never`.
Wait for attachment, introduce the same edit, inspect formatting, and run
`:Plait format`. Expected: inspection explains that LSP fallback is prohibited;
with the Lua chain disabled, the action is unavailable and leaves the text unchanged.
This is a capability-wide policy, not a new Python-specific disable control.

## 8. Record results and clean up

Mark exactly one outcome per row. Record commands, observed messages, repairs,
and any hesitation; unexecuted checks remain untested.

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Independent bootstrap and controlled missing tool | | | | |
| Disabled-chain explanation and override provenance (PRO-167) | | | | |
| Real LSP fallback / never comparison (PRO-167) | | | | |
| Default and explicit native hover (PRO-168) | | | | |
| Native mapping survives detach (PRO-168) | | | | |
| Native / foreign preflight distinction (PRO-168) | | | | |
| Foreign mapping protected on later attachment (PRO-168) | | | | |
| Blocked feedback under errors / all / silent (PRO-169) | | | | |
| Removed collision / disabled mapping repairs (PRO-169) | | | | |
| Concise report and configuration-wide scope (PRO-170) | | | | |
| Per-command verbose detail and contribution history (PRO-170) | | | | |
| Complete, equivalent structured evidence (PRO-170) | | | | |

Save results outside the disposable workspace before cleanup. Quit every process
using this app, then run in Fish:

```fish
cd $PLAIT_REPO
rm -rf \
  ~/.config/plait-beta-feedback-regression-ux \
  ~/.local/share/plait-beta-feedback-regression-ux \
  ~/.local/state/plait-beta-feedback-regression-ux \
  ~/.cache/plait-beta-feedback-regression-ux \
  /tmp/plait-beta-feedback-regression-ux
rm -f /tmp/feedback-json-a.json /tmp/feedback-json-b.json
set -e NVIM_APPNAME
set -e PLAIT_FEEDBACK_CASE
set -e PLAIT_FEEDBACK_POLICY
set -e PLAIT_FEEDBACK_UX
```

Cleanup targets only this procedure's literal app/workspace paths. Other Beta
apps, normal Neovim data, and the repository checkout remain available.
