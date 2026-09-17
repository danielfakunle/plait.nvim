# Beta Lua Author Journey

This procedure validates Mason-owned tools, Lua language intelligence, completion, formatting, provider-independent actions, and capability customization. Complete the bootstrap procedure first and return to `NVIM_APPNAME=plait-beta-ux`.

The default mapping leader is Space. Relative line numbers are on by default; check `:set number? relativenumber?` in the applied editor, and press Space then `c` then `r` for `<leader>cr`. In insert and command-line modes, Option/Alt+Backspace (`<A-BS>`) deletes the previous word using `<C-w>`; confirm the terminal sends that key sequence if it does not work.

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

With the default `operation_feedback = 'info'`, a direct Lua `ensure` remains quiet on success; `:Plait tooling ensure` announces maintenance start and completion, or confirms an immediate no-op once. Inspection still shows its operation ID, targets, and eventual state.

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

Run `:checkhealth vim.lsp`, confirm `lua_ls` appears under the active clients for the buffer, and wait for it to attach. Before editing, run `:Plait inspect language_servers lua_ls` from the Lua buffer. It reports the live workspace root for this buffer; if LuaLS is attached without one, it explains that initial diagnostics may be delayed and names project root markers to add. This is inspection-only, with no automatic notification. Then test:

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

Expected: explicit `p.render(...)` calls return `started` with operation IDs when supported, regardless of `operation_feedback`. `:Plait inspect operations` eventually records success or failure with buffer, position, method, and completion evidence; successful direct Lua actions stay quiet at `info`; genuine failures are notified.

## 3. Test completion

Enter insert mode after `vim.` and observe the completion menu.

Exercise:

- `<C-n>` and `<C-p>`, or `<Down>` and `<Up>`, to move through candidates
- `<C-f>` and `<C-b>` when documentation is visible
- `<CR>` to accept a selected candidate, or `<C-y>` to select the first candidate and accept
- `<C-e>` to hide completion
- `<C-Space>` to trigger completion explicitly

Expected: automatic LSP completion appears without preselecting its first candidate. Enter inserts a newline unless a candidate has been selected; `<C-y>` selects the first candidate if needed and accepts it. Repeating `<C-Space>` while completion is open shows or hides documentation. `<C-n>` and `<C-p>` retain their native behavior when completion is unavailable. Documentation appears after a selection (200 ms delay), signature help follows its default, and Tab retains its native behavior. Source priority is LSP, path, snippets, buffer. In `:` command-line mode completion opens automatically; search command lines do not auto-open the menu. `<Left>` and `<Right>` retain their native command-line behavior.

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
- Explicitly rendering the action returns `started`; its operation later records success or failure. Automatic start/success messages stay suppressed for direct Lua invocation at `info`.
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

Use the canonical config with no `operation_feedback` declaration first (`info`). Run
`:Plait tooling ensure`: expect “already satisfied” once when nothing changes. In an isolated app
with an unmet Mason-owned tool, expect one start and one final outcome when mutation occurs.
A satisfied StyLua must never be described as installed or updated. Run the same successful action
through Lua and confirm it returns a structured result without notifications.

Repeat with `errors`, `debug`, `all`, and `silent` in fresh restarts. `errors` shows only genuine
failures and blocked actions with repair guidance. `debug` and `all` include names, lifecycle events,
and operation IDs, with one message per start/completion. `silent` suppresses incidental failures too.
For each policy, run `:Plait tooling check` with an absent or incompatible tool: findings and repair
guidance must always appear. `:Plait inspect operations`, `:Plait validate`, and explicitly rendered
results remain visible. Restore the canonical config after this check.

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
