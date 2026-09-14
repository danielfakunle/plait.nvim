# Beta Usability Testing

These procedures test the complete Beta author journey added after Alpha:

- Owner-local modules, contributions, explicit replacement, and disabling
- Compatibility and managed-effect collision preflight
- Exact provider-package discovery, consent, synchronization, activation, and restart behavior
- Deterministic external-tool discovery and Mason/project ownership
- Guarded provider escape hatches
- Native language diagnostics and language actions
- Blink completion, Conform formatting, Lua, and TypeScript integrations
- Operation and health evidence for successful, degraded, and invalid states

The Alpha editor behavior remains covered by [`../alpha-usability-testing.md`](../alpha-usability-testing.md). Run these Beta procedures in order because later procedures reuse the packages and Mason tools installed by the first one:

1. [`01-bootstrap-and-packages.md`](01-bootstrap-and-packages.md)
2. [`02-lua-author-journey.md`](02-lua-author-journey.md)
3. [`03-typescript-author-journey.md`](03-typescript-author-journey.md)
4. [`04-composition-and-failure-feedback.md`](04-composition-and-failure-feedback.md)

## Using the feedback rubrics

Before testing, copy each procedure's rubric into a results file and record the Neovim version, operating system, terminal, date, and `NVIM_APPNAME`. Fill in the rubric as you perform the procedure rather than from memory afterward.

Mark exactly one outcome in each row:

- **Pass**: The behavior matched the expectation and was understandable without extra investigation.
- **Hesitation**: The behavior worked, but you had to guess, reread instructions, repeat a step, or consult source code.
- **Failure**: The behavior was incorrect, an expected result did not occur, or you could not continue.

In **Notes**, briefly describe what you observed. For every hesitation or failure, include:

- The procedure step and command or action
- The exact message or visible behavior
- What you expected instead
- What you tried next
- Whether the procedure alone made recovery possible

For example, the second row is a hesitation because the operation succeeded but the required next step was unclear. The third row is a failure because the expected completion menu never appeared:

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Install consent | ✓ | | | One prompt covered all four packages. |
| Tool discovery/repair | | ✓ | | In Lua procedure step 1, `:Plait tooling ensure` succeeded, but neither its result nor the procedure made clear whether I needed to restart. I restarted and the tools worked. |
| Completion behavior | | | ✓ | In Lua procedure step 3, `<C-Space>` opened no menu in an attached Lua buffer. `:LspInfo` showed `lua_ls`; retrying in insert mode did not help. |

Also preserve useful evidence such as operation IDs, relevant `:Plait inspect` output, and health messages. Do not mark a confusing experience as a pass merely because the final editor state was correct; usability friction is part of the result.

Inspection commands open one read-only Plait report. They may reuse an empty unnamed window, otherwise they
open a dedicated tab; press `q` to close the report without losing an editing buffer. Repeated inspection should
refresh that report. Command-line validation and actions should remain concise, name affected targets, give a
repair for unavailable work, and direct started operations to `:Plait inspect operations <operation-id>`. Use a
trailing `--json` only when the procedure needs deterministic machine-readable inspection output.

Beta passes when both language journeys work end to end; package and tool ownership remains explicit; supported customization is predictable; unsafe collisions and provider changes stop before application; and inspection, health, and operation records explain every required repair without source-code knowledge.
