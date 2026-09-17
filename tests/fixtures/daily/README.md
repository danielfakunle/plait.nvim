# Canonical daily Lua and TypeScript configuration

`config.lua` is the executable source authority for the daily configuration and
its documentation excerpts. It selects the seven built-in modules, inherits
the editor defaults of two-space indentation using spaces, remaps save, disables
format-on-save and the JSX formatter chain, and replaces `oxfmt` with project
ownership. The inherited width-two behavior supersedes the width-four example
in the original specification.

`init.lua` supplies isolated package metadata, executable version probes, and
external provider doubles. It uses real Plait resolution and application;
real provider/tool qualification remains a release gate. `daily_tool` and
`daily_tool_state` globals choose absent, incompatible, or unprobeable variants
for LuaLS, StyLua, TypeScript, oxfmt, and Node. Node degradation affects both
TypeScript and oxfmt. No developer-installed language executable is consulted.

`tests/test_daily.lua` contains the normative semantic journey assertions at
public configuration, inspection/rendering, action, and Neovim behavior seams.
The generated section goldens lock every public record field and nested array
order plus text/JSON rendering. Temporary project paths, `/private/tmp` aliases,
the repository prefix, and Neovim's runtime path are normalized. There is no
whole-plan golden authority. Unchanged module, package, and operation sections
reuse the satisfied goldens in every degradation variant. Generate them only
after reviewing the semantic assertions:

```sh
nvim --headless --clean -u tests/fixtures/daily/init.lua \
  -l tests/fixtures/daily/generate_rendered.lua
nvim --headless --clean \
  --cmd "lua vim.g.daily_tool = 'tsc'; vim.g.daily_tool_state = 'absent'" \
  -u tests/fixtures/daily/init.lua -l tests/fixtures/daily/generate_rendered.lua
```

`exercise.lua` runs the public action scenarios. The `actions-*` goldens lock
nonempty operations and post-action diagnostics. RFC 3339 timestamps are
normalized; tests separately assert their shape and completion ordering.

Repeat the second command for each declared tool/state combination.
The older TypeScript integration harness also executes `config.lua`.
