# Plait v0.1 provider guard-path matrix

Research for [Research the v0.1 provider guard-path matrix](https://linear.app/daniel-tf/issue/PRO-128/research-the-v01-provider-guard-path-matrix), conducted 2026-09-06.

## Question and baseline

At the exact provider revisions qualified for Plait v0.1, which paths under each supported provider escape-hatch target must Plait guard to preserve capability-owned invariants, and which paths can remain opaque configuration-owner payloads?

The qualified baseline is Neovim `0.12.5` and these exact provider revisions:

| Provider | Qualified revision |
| --- | --- |
| `nvim-lspconfig` | [`615d7b2712efb2f530a83a9d0466acafba6b1d6f`](https://github.com/neovim/nvim-lspconfig/tree/615d7b2712efb2f530a83a9d0466acafba6b1d6f) |
| `blink.cmp` | [`78336bc89ee5365633bcf754d93df01678b5c08f`](https://github.com/Saghen/blink.cmp/tree/78336bc89ee5365633bcf754d93df01678b5c08f) |
| `conform.nvim` | [`016802de402556da54c36bd7359b441266b01cdd`](https://github.com/stevearc/conform.nvim/tree/016802de402556da54c36bd7359b441266b01cdd) |
| `mason.nvim` | [`2a6940af80375532e5e9e7c1f2fc6319a1b7a69d`](https://github.com/mason-org/mason.nvim/tree/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d) |

The supported targets are only `vim.lsp` `global` and `servers.lua_ls`/`servers.tsc`, `blink.cmp` `setup`, `conform.nvim` `setup` and `formatters.stylua`/`formatters.oxfmt`, and `mason.nvim` `setup`. Paths outside those named targets are not escape hatches.

## Answer

Plait should implement the matrix below as versioned adapter metadata. A **guarded prefix** rejects a contribution at the prefix or anywhere below it. A **guarded leaf** rejects only that leaf or an ancestor value that would replace it; disjoint sibling leaves remain available. Lists and functions remain atomic leaves under the established escape-hatch composition rule.

Everything not guarded below remains an opaque owner payload. "Available" means Plait performs path-conflict detection and passes the value through; it does not promise that the provider will accept the value or preserve its behavior across revisions.

### Matrix

| Escape-hatch target | Guarded paths | Opaque owner payloads |
| --- | --- | --- |
| `language["vim.lsp"].global` | Guarded prefixes: `cmd`, `filetypes`, `root_dir`, `root_markers`, `workspace_folders`, `workspace_required`, `reuse_client`, and `name`. Guarded completion leaves: every generated leaf listed under [LSP completion capabilities](#lsp-completion-capabilities). | All other disjoint `vim.lsp.Config` paths, including other client-capability leaves, `settings`, `init_options`, `handlers`, `on_init`, `on_attach`, `on_exit`, `flags`, `cmd_env`, and `cmd_cwd`. |
| `language["vim.lsp"].servers.lua_ls` | The same lifecycle/identity prefixes and completion leaves as `global`; plus guarded leaves `settings.Lua.runtime.version`, `settings.Lua.workspace.checkThirdParty`, `settings.Lua.workspace.library`, and `settings.Lua.telemetry.enable`. | Other disjoint LuaLS settings and client options, including `settings.Lua.runtime.path`, `settings.Lua.codeLens`, and `settings.Lua.hint`. |
| `language["vim.lsp"].servers.tsc` | The same lifecycle/identity prefixes and completion leaves as `global`. There are no additional guarded server-setting leaves. | Other disjoint TypeScript client and server settings, including `settings["js/ts"]`. |
| `completion["blink.cmp"].setup` | Guarded prefixes: `keymap`, `sources.default`, and `sources.per_filetype`. Guarded leaves: `enabled`, `completion.menu.enabled`, `completion.menu.auto_show`, `completion.trigger.show_on_keyword`, `completion.trigger.show_on_trigger_character`, `completion.documentation.auto_show`, `signature.enabled`, and `sources.providers.{lsp,path,snippets,buffer}.{module,enabled,fallbacks,score_offset}`. | All other setup leaves, notably `appearance`, `fuzzy`, `snippets`, drawing/window details, list-selection behavior, source-provider internals, `cmdline`, and `term`. |
| `formatting["conform.nvim"].setup` | Guarded prefixes: `formatters_by_ft`, `formatters`, `default_format_opts`, `format_on_save`, and `format_after_save`. Guarded leaves: `notify_on_error` and `notify_no_formatters`. | `log_level` is the only setup leaf at this revision that is both disjoint from those prefixes and owner-configurable. |
| `formatting["conform.nvim"].formatters.stylua` | Guarded leaves: `command`, `format`, and `inherit`. | `args`, `range_args`, `prepend_args`, `append_args`, `cwd`, `require_cwd`, `stdin`, `tmpfile_format`, `condition`, `exit_codes`, `env`, and `options`. |
| `formatting["conform.nvim"].formatters.oxfmt` | Guarded leaves: `command`, `format`, and `inherit`. | The same formatter-tuning leaves as `stylua`. |
| `tooling["mason.nvim"].setup` | Guarded leaves: `PATH` and `firewall.auto_managed`. Plait generates `PATH = "skip"` and `firewall.auto_managed = false`. | All other setup leaves, including `install_root_dir`, registry sources/cache policy, metadata providers, concurrency, logging, download/package-manager arguments, `firewall.enabled`, and UI configuration. |

## Why these paths are guarded

### Native LSP lifecycle and identity

Neovim `0.12.5` uses `filetypes` to decide whether a config applies, `root_dir`/`root_markers` to decide whether and where it activates, `workspace_required` to suppress startup without a workspace, and `reuse_client` plus workspace roots to decide client reuse. It validates and invokes `cmd` to start the server. These fields therefore control the server declaration, executable resolution, automatic startup, and attachment behavior owned by Plait's `language` and `tooling` capabilities.[^nvim-lsp-source]

The same prefixes must be guarded at `global` and at each server target. Neovim resolves `*`, runtime `lsp/<name>.lua`, and explicit named config in increasing priority with forceful deep merge; a server-local owner value can therefore replace a generated global value.[^nvim-lsp-doc]

`nvim-lspconfig`'s exact `lua_ls` config supplies `cmd`, `filetypes`, `root_markers`, and default `settings.Lua` values.[^lua-ls] Its exact `tsc` config supplies a function-valued `cmd`, four filetypes, and a function-valued `root_dir` that rejects Deno roots, finds the project root, searches workspace-local and `PATH` binaries, verifies TypeScript major version 7+, and starts `tsc --lsp --stdio`.[^tsc] Plait's declared project-first executable policy and `>=7,<8` constraint require its adapter to own that whole `cmd`/root lifecycle rather than accepting a competing opaque function.

The four LuaLS setting leaves are guarded because they are the fixed `lang.lua` contribution: LuaJIT runtime semantics, Neovim runtime library, suppressed third-party workspace prompts, and disabled telemetry. Other LuaLS settings remain genuine provider tuning.

Callbacks and handlers are not guarded merely because they are functions. They do not choose Plait's enabled-server set or resolved executable, and the escape-hatch contract explicitly permits opaque function leaves. Their behavior is consequently outside capability-level guarantees.

### LSP completion capabilities

At the qualified revision, Blink's plugin entrypoint reads `vim.lsp.config["*"].capabilities` and writes a merged `capabilities` value back to the global config.[^blink-plugin] Its capability helper generates these leaves:[^blink-capabilities]

```text
capabilities.textDocument.completion.completionItem.snippetSupport
capabilities.textDocument.completion.completionItem.commitCharactersSupport
capabilities.textDocument.completion.completionItem.documentationFormat
capabilities.textDocument.completion.completionItem.deprecatedSupport
capabilities.textDocument.completion.completionItem.preselectSupport
capabilities.textDocument.completion.completionItem.tagSupport.valueSet
capabilities.textDocument.completion.completionItem.insertReplaceSupport
capabilities.textDocument.completion.completionItem.resolveSupport.properties
capabilities.textDocument.completion.completionItem.insertTextModeSupport.valueSet
capabilities.textDocument.completion.completionItem.labelDetailsSupport
capabilities.textDocument.completion.completionList.itemDefaults
capabilities.textDocument.completion.contextSupport
capabilities.textDocument.completion.insertTextMode
```

Plait should generate those leaves itself during plan application and suppress reliance on Blink's plugin-entrypoint timing. They are guarded under both global and server targets because server configuration has higher merge priority. Other capability leaves remain available, including disjoint siblings under `textDocument.completion`.

### Blink setup

Blink deep-merges setup input into defaults and validates an exact top-level schema.[^blink-config] `enabled` gates keymaps, completion, and signature help. `completion.menu.enabled`/`auto_show` and the two trigger leaves are the minimum direct controls for Plait's automatic-suggestion setting. `completion.documentation.auto_show` implements the fixed "documentation on explicit selection" behavior, while `signature.enabled` activates the selected signature-help behavior.[^blink-trigger][^blink-menu][^blink-doc][^blink-signature]

Blink's keymap schema combines presets and per-key command/function lists.[^blink-keymap] The entire `keymap` prefix is guarded because Plait's semantic mappings own completion interaction and deliberately leave Enter and Tab untouched; accepting a provider preset or callback there bypasses that contract.

`sources.default` and `sources.per_filetype` select active source categories. For the four managed categories, `module`, `enabled`, `fallbacks`, and `score_offset` determine identity, participation, fallback topology, and priority.[^blink-sources] Those paths are guarded so the capability configuration remains authoritative and LSP remains highest priority. Other source internals such as timeouts, item transforms, limits, and provider `opts` remain provider-specific tuning.

### Conform setup and formatters

Conform copies `formatters`, `formatters_by_ft`, and `default_format_opts` into module state during setup and creates separate pre-write and post-write autocmds from `format_on_save` and `format_after_save`.[^conform-setup] Those prefixes directly control Plait-owned formatter declarations, ordered filetype chains, fallback/timeout policy, and save behavior. Both notification leaves are guarded because Plait owns formatting failure diagnostics; allowing them would either suppress provider errors Plait expects or duplicate Plait diagnostics.

At this revision formatter definitions permit command- or Lua-function implementations and an `inherit` switch/name that can discard or redirect the built-in definition.[^conform-types] Conform resolves `inherit` before merging an override.[^conform-resolution] Those three leaves choose the formatter implementation and executable, so Plait guards them to preserve `tooling` resolution. Formatter arguments and execution details remain opaque by explicit product decision. This is safe as an ownership boundary, not a behavioral guarantee: an escaped `condition`, `cwd`, or argument can make an operation unavailable or fail.

The qualified built-ins use `command = "stylua"` for StyLua and `util.from_node_modules("oxfmt")` for oxfmt.[^stylua][^oxfmt] Plait must replace each with its resolved executable while preserving the provider defaults and then reject owner contact with `command`.

### Mason setup

Mason's setup deep-merges settings, mutates process `PATH`, and registers configured registry sources.[^mason-settings][^mason-setup] Plait's source policy distinguishes workspace-local, Mason-managed, and ordinary `PATH` executables. Letting Mason prepend or append its bin directory would silently collapse that distinction before Plait resolves a tool, so Plait must generate and guard `PATH = "skip"`.

Mason's firewall can automatically install and update the Socket Firewall client.[^mason-firewall] That undeclared external tool would violate Plait's rule that external-state mutation occurs only through explicit actions over effective requirements. Plait should therefore generate and guard `firewall.auto_managed = false`; `firewall.enabled` can remain owner-configurable when the owner supplies `sfw` independently.

`install_root_dir` need not be guarded: Mason consistently derives its global package, bin, staging, and registry locations from the current setting, so the adapter can query Mason rather than assume the default.[^mason-location] Registry sources, cache refresh, and metadata providers influence opaque Mason behavior but do not bypass Plait's effective requirement identities or post-resolution executable/version checks. They remain visibly escaped and outside capability-level compatibility guarantees.

## Adapter and validation consequences

1. Store this matrix beside the four provider revisions in the compatibility manifest; a provider-pin advance must review both together.
2. Materialize generated values before opaque payload composition, then reject any owner leaf equal to or below a guarded prefix or equal to a guarded leaf. Report both provenances and the capability-level repair.
3. Guard generated LSP completion leaves in every precedence layer exposed as a target, not only where Plait initially contributes them.
4. Apply formatter payloads only through their natural named targets; reject `conform.nvim.setup.formatters` so owners cannot bypass formatter-target validation.
5. Test each guarded path with one direct collision and one ancestor collision. Test representative disjoint siblings to prevent accidental over-guarding.
6. Inspection should mark every accepted remainder as opaque and revision-coupled. It must not imply that an accepted callback, formatter condition, registry source, or other payload preserves the built-in outcome.

No new wayfinder decision is exposed. The integrated v0.1 specification can consume this matrix directly.

## Primary sources

All provider links are immutable commit permalinks; Neovim links use the qualified `v0.12.5` tag.

[^nvim-lsp-source]: Neovim 0.12.5, [`vim.lsp` config resolution, validation, activation, root selection, and client reuse](https://github.com/neovim/neovim/blob/v0.12.5/runtime/lua/vim/lsp.lua#L430-L789).
[^nvim-lsp-doc]: Neovim 0.12.5, [`lsp-config-merge`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lsp.txt#L183-L242).
[^lua-ls]: nvim-lspconfig, [`lsp/lua_ls.lua` at `615d7b2`](https://github.com/neovim/nvim-lspconfig/blob/615d7b2712efb2f530a83a9d0466acafba6b1d6f/lsp/lua_ls.lua#L67-L93).
[^tsc]: nvim-lspconfig, [`lsp/tsc.lua` at `615d7b2`](https://github.com/neovim/nvim-lspconfig/blob/615d7b2712efb2f530a83a9d0466acafba6b1d6f/lsp/tsc.lua#L53-L150).
[^blink-plugin]: blink.cmp, [automatic global LSP capability contribution at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/plugin/blink-cmp.lua#L1-L7).
[^blink-capabilities]: blink.cmp, [`get_lsp_capabilities()` at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/sources/lib/init.lua#L301-L344).
[^blink-config]: blink.cmp, [top-level config defaults, merge, and validation at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/init.lua#L1-L120).
[^blink-trigger]: blink.cmp, [completion trigger schema at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/completion/trigger.lua#L1-L54).
[^blink-menu]: blink.cmp, [completion menu controls at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/completion/menu.lua#L3-L46).
[^blink-doc]: blink.cmp, [documentation behavior at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/completion/documentation.lua#L1-L55).
[^blink-signature]: blink.cmp, [signature behavior at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/signature.lua#L1-L58).
[^blink-keymap]: blink.cmp, [keymap presets and custom mappings at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/keymap.lua#L127-L168).
[^blink-sources]: blink.cmp, [source selection and provider schema at `78336bc`](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/lua/blink/cmp/config/sources.lua#L1-L89).
[^conform-setup]: conform.nvim, [`setup()` state and autocmd behavior at `016802d`](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/init.lua#L65-L212).
[^conform-types]: conform.nvim, [setup, format, and formatter override types at `016802d`](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/types.lua#L9-L41).
[^conform-resolution]: conform.nvim, [formatter inheritance resolution at `016802d`](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/init.lua#L687-L748).
[^stylua]: conform.nvim, [StyLua formatter definition at `016802d`](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/formatters/stylua.lua#L1-L33).
[^oxfmt]: conform.nvim, [oxfmt formatter definition at `016802d`](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/formatters/oxfmt.lua#L1-L23).
[^mason-settings]: mason.nvim, [default settings and deep merge at `2a6940a`](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason/settings.lua#L5-L195).
[^mason-setup]: mason.nvim, [setup side effects at `2a6940a`](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason/init.lua#L16-L36).
[^mason-firewall]: mason.nvim, [firewall behavior at `2a6940a`](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/doc/mason.txt#L139-L164).
[^mason-location]: mason.nvim, [install-location derivation and `PATH` mutation at `2a6940a`](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-core/installer/InstallLocation.lua#L19-L96).
