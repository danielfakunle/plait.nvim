# Canonical extension boundary

`python.lua` declares the local module; `config.lua` selects it, supplies the opaque
provider settings, validates/applies, and sets `colorcolumn` through ordinary Lua.
`init.lua` supplies isolated package metadata, executable probes, and external
provider doubles. This is behavioral fixture evidence; real provider revision
qualification remains the responsibility of the release qualification gate.

`tests/test_extension_boundary.lua` contains the normative journey assertions.
The `rendered/` section goldens were generated from the canonical public commands
once those assertions passed. They lock every public record value and nested array
order, plus exact text/JSON rendering. Only temporary bin/root paths and the
repository prefix are normalized. There is no whole-plan golden authority.
The chain variant adds qualified `oxfmt`, orders it after incompatible `ruff`, and
makes `oxfmt` absent. The guard variant attempts managed command-path mutations.
