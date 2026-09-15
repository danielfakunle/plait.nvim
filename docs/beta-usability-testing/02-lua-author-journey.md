# Beta Lua Author Journey

This procedure validates Mason-owned tools, Lua language intelligence, completion, formatting, provider-independent actions, and capability customization. Complete the bootstrap procedure first and return to `NVIM_APPNAME=plait-beta-ux`.

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
2. Press `gr` and verify references are shown.
3. Press `K` over `message` or `greet`.
4. Press `<leader>cr` on `message`, choose a new name, and verify its references change.
5. Put the cursor on `unknown_name` and exercise `[d`, `]d`, and `<leader>ca`.

Expected: each mapping invokes a native LSP behavior, diagnostics use the configured native presentation, and failures are surfaced as bounded Plait results rather than provider errors.

Also sample the public facade:

```vim
:lua local p = require('plait'); print(p.render(p.actions.language.hover()))
:lua local p = require('plait'); print(p.render(p.actions.language.definition()))
```

Expected: asynchronous requests return `started` with operation IDs when supported. `:Plait inspect operations` eventually records their success or failure with buffer, position, method, and completion evidence.

## 3. Test completion

Enter insert mode after `vim.` and observe the completion menu.

Exercise:

- `<C-n>` and `<C-p>` to move through candidates
- `<C-f>` and `<C-b>` when documentation is visible
- `<C-y>` to accept
- `<C-e>` to cancel
- `<C-Space>` to trigger completion explicitly

Expected: automatic LSP completion appears, accepted text is inserted, documentation and signature help follow the defaults, and normal Enter/Tab behavior remains untouched.

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
- The action returns `started`; its operation later records success or failure.
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

## 6. Preserve the shared app

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

Record any action whose status did not match what appeared in the editor, and any time provider knowledge was required.
