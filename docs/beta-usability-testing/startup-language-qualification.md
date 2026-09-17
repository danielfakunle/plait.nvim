# Beta startup and language qualification

PRO-166 qualification recorded on 2026-09-16 on macOS arm64 with Neovim
0.12.5 (Release, LuaJIT 2.1.1788856981). The baseline is
`da39795` (before PRO-163, PRO-164, and PRO-165); the corrected implementation is
`a4be86c` plus the qualification changes. Both canonical configurations retain
explicit `config:validate()` followed by `config:apply()`.

## Startup evidence

Run from the repository root:

```sh
nvim --headless --clean -u scripts/qualify_startup.lua
PLAIT_QUALIFY_JOURNEY=typescript nvim --headless --clean -u scripts/qualify_startup.lua
```

For the baseline, archive `da39795` into a temporary directory, copy the current
`scripts/qualify_startup.lua` and `tests/fixtures/lua_quickstart/init.lua` there,
and run the same commands from that directory. Copying the Lua harness provides
identical observation instrumentation and a named non-project Lua buffer;
the canonical configuration and production code come from the archived revision.

| Journey | Command | Before probes | After probes |
| --- | --- | --- | --- |
| Non-project Lua | lua-language-server --version | 4 | 1 |
| Non-project Lua | stylua --version | 4 | 1 |
| Project-local TypeScript | lua-language-server --version | 5 | 1 |
| Project-local TypeScript | stylua --version | 5 | 1 |
| Project-local TypeScript | tsc --version | 5 | 1 |
| Project-local TypeScript | oxfmt --version | 5 | 1 |
| Project-local TypeScript | node --version | 10 | 1 |

Both before and after application results were `performed`. Advisory single-run
fixture elapsed times were 3319.61 → 1320.50 ms for Lua and 484.18 → 301.44 ms
for TypeScript. These measure fixture execution inside synchronous initialization,
including harness setup; the Lua fixture also exercises inspection and collector
misuse after application. Lua probe counts are captured immediately after the
canonical configuration returns, excluding those later checks. These are controlled
fixture measurements, not interactive editor launch or language-server readiness
benchmarks: providers are stubbed, Lua tool responses are stubbed, and TypeScript
uses executable version fixtures. **The release gate is at most one probe per
unique command during unchanged startup, never an elapsed-time threshold.**

`tests/test_lua_quickstart.lua` checks two unique commands, each probed once.
`tests/test_local_integrations.lua` checks five unique commands, each probed once,
and one provider/package/tool resolution through validation and application.

## Language evidence

`tests/test_language_lifecycle.lua` exercises initial and subsequently opened Lua
and TypeScript buffers. In each case `gr` dispatches references with a configured
10-second prefix timeout and buffer-local `nowait`; definition, hover, rename,
and code action callbacks dispatch their native LSP behaviors. The native global
`grr`, `gra`, `grn`, `gri`, and `grt` mappings remain intact. An unmanaged buffer
retains its global references mapping without a Plait `gr` mapping.

The same suite checks attach, per-action support across multiple-client detach,
owner/plugin replacement preservation, actionable late collision diagnostics, and
callback release on buffer wipeout. These controlled-client tests qualify mapping
and dispatch behavior. Real server attachment, diagnostics, completion, and
formatting remain covered by the interactive Lua and TypeScript author journeys;
this automated evidence does not claim those human procedures were performed.

## Environment snapshots and repair

Validation observes a point-in-time environment snapshot. Unchanged validation,
application, tool resolution, and the default startup check reuse it. After an
external repair, run `:Plait tooling check` to explicitly refresh tool records and
diagnostics without restarting. Inspection does not launch probes. See
[Tool Observations](../../site/content/reference/tool-observations.mdx) for the
complete semantics and feedback policy. `tests/test_tools.lua` qualifies startup
reuse, explicit refresh, repaired state publication, and feedback compatibility.

## Verification

Focused gates: `make test_file FILE=tests/test_lua_quickstart.lua`,
`make test_file FILE=tests/test_local_integrations.lua`,
`make test_file FILE=tests/test_language_lifecycle.lua`, and
`make test_file FILE=tests/test_tools.lua`. The complete gate is `make check`
(formatting, lint, LuaLS, generated schema, and all tests).

All four focused gates passed. `make check` passed with 182 tests, zero failures
and zero notes; formatting, lint, LuaLS, and schema checks also passed. The
required Standards and Spec reviews of the uncommitted work each reported zero
findings.
