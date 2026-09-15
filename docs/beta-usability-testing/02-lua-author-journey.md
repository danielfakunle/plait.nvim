# Beta Lua Author Journey

This procedure validates Mason-owned tools, Lua language intelligence, completion, formatting, provider-independent actions, and capability customization. Complete the bootstrap procedure first and return to `NVIM_APPNAME=plait-beta-ux`.

The default mapping leader is Space. Relative line numbers are on by default; check `:set number? relativenumber?` in the applied editor, and press Space then `c` then `r` for `<leader>cr`.

## 1. Resolve the Lua tools

In Fish:

```fish
set -gx PLAIT_REPO /Users/daniel/Developer/plait.nvim
set -gx NVIM_APPNAME plait-beta-ux
set -gx PLAIT_UX /tmp/plait-beta-ux
nvim $PLAIT_UX/lua-project/main.lua
```

Run:

```vim
:Plait tooling check
:Plait inspect tools
```

If `lua-language-server` or `stylua` is absent or incompatible, run:

```vim
:Plait tooling ensure
:Plait inspect operations
```

With the default `operation_feedback = 'errors'`, `ensure` does not announce the start or success automatically. Inspection still shows its operation ID, targets, and eventual state.

Wait for the operation to finish, then run `:Plait tooling check` again. Expected:

- `ensure` targets only unsatisfied mutable tools.
- Both tools resolve through Mason at the qualified versions: Lua Language Server `3.19.1` and StyLua `2.5.2`.
- Tool records retain all candidates and clearly identify the authoritative one.
- Repeating `:Plait tooling ensure` is a no-op reported as `performed`.
- `:Plait tooling install stylua` and `:Plait tooling update stylua` are also no-ops while the exact version is satisfied.

Restart Neovim after installation if the current language service remains degraded.

## 2. Test Lua language intelligence

Replace the file contents with:

```lua
local function greet(name)
  return 'hello ' .. name
end

local message = greet('Plait')
print(message)
print(unknown_name)
```

Run `:checkhealth vim.lsp`, confirm `lua_ls` appears under the active clients for the buffer, and wait for it to attach. Then test:

1. Put the cursor on `greet` in the call and press `gd`.
2. Press `gr` and verify references are shown immediately, without waiting for a second key. Confirm `grr`, `gra`, `grn`, `gri`, and `grt` no longer trigger the superseded native LSP mappings.
3. Press `K` over `message` or `greet`.
4. Press `<leader>cr` on `message`, choose a new name, and verify its references change.
5. Put the cursor on `unknown_name` and exercise `[d`, `]d`, and `<leader>ca`.

Expected: each mapping invokes a native LSP behavior, diagnostics use the configured native presentation, and failures are surfaced as bounded Plait results rather than provider errors.

Also sample the public facade:

```vim
:lua local p = require('plait'); print(p.render(p.actions.language.hover()))
:lua local p = require('plait'); print(p.render(p.actions.language.definition()))
```

Expected: explicit `p.render(...)` calls return `started` with operation IDs when supported, regardless of `operation_feedback`. `:Plait inspect operations` eventually records success or failure with buffer, position, method, and completion evidence; default automatic notifications appear only on failure.

## 3. Test completion

Enter insert mode after `vim.` and observe the completion menu.

Exercise:

- `<C-n>` and `<C-p>` to move through candidates
- `<C-f>` and `<C-b>` when documentation is visible
- `<C-y>` to accept
- `<C-e>` to cancel
- `<C-Space>` to trigger completion explicitly

Expected: automatic LSP completion appears without preselecting its first candidate. Navigate to select a candidate before accepting it; `<C-y>` can also select and accept. Documentation appears after a selection (200 ms delay), signature help follows its default, and normal Enter/Tab behavior remains untouched. Source priority is LSP, path, snippets, buffer. In `:` command-line mode completion opens automatically; search command lines do not auto-open the menu. `<Left>` and `<Right>` retain their native command-line behavior.

Outside insert mode run:

```vim
:lua local p = require('plait'); print(p.render(p.actions.completion.trigger()))
```

Expected: a closed `unavailable` result with reason `completion_inactive`, not an exception.

## 4. Test formatting

Make `main.lua` visibly misformatted, save it, and verify StyLua formats it. Make it untidy again, then test normal and visual formatting:

```vim
:Plait format
```

Select a few lines and run `:Plait format`, then repeat with `<leader>cf` in normal and visual mode.

Expected:

- Save formatting and explicit formatting use the `stylua` chain.
- Explicitly rendering the action returns `started`; its operation later records success or failure. Automatic start/success messages stay suppressed under the default feedback policy.
- Visual formatting sends the selected range.
- No provider command or provider-specific result leaks into the normal authoring path.

## 5. Test supported customization

In the config, add before `validate()`:

```lua
config:configure({
  language = {
    inlay_hints = true,
    diagnostics = { virtual_text = false },
    mappings = { hover = '<leader>ch' },
  },
  completion = {
    automatic = false,
    documentation = 'off',
    signature_help = false,
  },
  formatting = {
    on_save = false,
    timeout_ms = 3000,
    mappings = { format = '<leader>f' },
  },
})
```

Restart and verify the observed behavior matches every configured value: completion requires an explicit trigger, documentation/signature help stay off, save does not format, `<leader>f` formats, `K` is unmanaged, and `<leader>ch` hovers. Inspect the three capabilities and confirm their effective values explain the result.

## 6. Verify all operation feedback modes

Use the canonical config with no `operation_feedback` declaration first (`errors`). Run `:Plait format` on a Lua buffer and `:Plait inspect operations`: the command has no start/success chatter, but the operation is inspectable. Induce a safely recoverable failure (for example, temporarily make StyLua unavailable in an isolated app) and verify that failure is notified. Explicitly render a returned result with `:lua print(require('plait').render(_G.plait_apply))`; the output must not change with the feedback policy.

Then add `config:configure({ operation_feedback = 'all' })` before `validate()`, restart, and repeat. The command prints the started operation and ID with `:Plait inspect operations <id>` guidance; Lua-facade asynchronous actions also announce their start with the same inspection guidance. Success and failure notifications include the operation name and ID. Inspect both records afterward.

Finally use `config:configure({ operation_feedback = 'silent' })` in a fresh restart. Neither command progress nor asynchronous completion notifications appear, including for failures. Inspect the operation records and diagnostics to confirm they remain available, and render `_G.plait_apply` explicitly again. Restore the canonical config after this check.

## 7. Preserve the shared app

Quit Neovim, but do not delete `plait-beta-ux` or `/tmp/plait-beta-ux` yet. The TypeScript and composition procedures reuse this app, its qualified provider packages, and its project workspace. They are removed by the final cleanup in the composition and failure-feedback procedure.

## Feedback rubric

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Tool discovery/repair | | | | |
| Lua server attachment | | | | |
| Language actions | | | | |
| Completion behavior | | | | |
| Formatting behavior | | | | |
| Capability customization | | | | |
| Operation feedback modes | | | | |

Record any action whose status did not match what appeared in the editor, and any time provider knowledge was required.
