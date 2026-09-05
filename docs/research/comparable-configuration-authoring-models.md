# Comparable configuration-authoring models

Research for [PRO-116](https://linear.app/daniel-tf/issue/PRO-116/research-comparable-configuration-authoring-models), conducted 2026-09-05.

## Question and scope

What authoring patterns, strengths, and recurring failure modes in current Neovim frameworks and adjacent configuration systems should constrain Plait's product and API design?

`vim.pack` is a fixed constraint. This note does not compare or select plugin managers. The two initial-idea documents are treated as prompts rather than evidence.

## Executive answer

Plait should make a small capability selection produce an inspectable, validated configuration plan, with deterministic precedence and explicit operations for replace, extend, disable, and escape. It should not expose a generic deep-merge API as its primary customization model.

Current Neovim frameworks prove that automatic discovery, curated imports, good defaults, and local overlays make substantial configurations approachable. Their documentation also exposes the recurring tax: users must learn hidden load phases, import ordering, plugin identity, and field-specific merge behavior. Lists are especially troublesome, and sufficiently advanced changes fall back to functions that mutate an accumulated table at the correct time.

Adjacent systems reinforce two constraints. NixOS gets reliable composition by making option types define validation and merge behavior, but its priority modifiers and freeform exceptions demonstrate how a powerful composition language can become a second system users must learn. VS Code gets discoverability from schemas, searchable settings, defaults, reset affordances, and a single published precedence ladder, but its many scopes and type-dependent merge rules show that even documented precedence becomes difficult when dimensions multiply.

The opportunity is therefore not "configuration modules exist nowhere." It is a deliberately smaller authoring model whose default path is capability-oriented and whose resolved effects remain explainable without reading implementation code.

## Evidence from Neovim

### LazyVim: convention plus overlays

LazyVim automatically loads conventional files for options, keymaps, autocommands, and plugin specs. Defaults load before user files, while plugin specs with the same plugin identity can customize or disable defaults. Optional Extras can be selected through `:LazyExtras` and imported as reusable specs.[^lazy-config][^lazy-general][^lazy-plugins][^lazy-extras]

Strengths:

- A predictable directory convention removes wiring and keeps common concerns recognizable.
- Curated Extras package useful slices, including languages and editor capabilities, behind a selection UI.
- Users retain raw Neovim Lua and direct plugin-spec access rather than entering a sealed environment.
- Customization is incremental: common fields merge, plugin disabling is explicit, and keymaps can be replaced by identity.

Failure modes and constraints for Plait:

- Lifecycle is implicit. The docs warn users not to manually require automatically loaded config modules, and custom keymaps are loaded on a named late event.[^lazy-general]
- Merge behavior is field-specific: `cmd`, `event`, `ft`, `keys`, `opts`, and `dependencies` extend or merge while other properties replace. Replacement or complex edits require function forms.[^lazy-plugins]
- Removal depends on exact identity. Disabling a keymap requires matching its left-hand side and mode exactly.[^lazy-plugins]
- The abstraction remains plugin-centric. Advanced configuration requires locating the owning plugin spec and understanding its upstream option shape.

Plait should keep convention and incremental ownership, but expose lifecycle only where the author must decide it, publish one precedence model, and use stable semantic identities for removable effects.

### AstroNvim and AstroCommunity: ordered packs and mutable overlays

AstroNvim presents a user config as an ordinary repository and says its value is selected plugins, integrated interactions, and reasonable defaults. AstroCommunity provides importable pieces from individual plugins through language packs. Its documented import order is semantically significant: core first, community second, user specs last.[^astro-user][^astro-plugins][^astro-community]

Strengths:

- Language packs demonstrate that one import can coordinate parsers, language servers, and related plugins.
- A user-owned repository and ordinary Lua/plugin escape hatch preserve control.
- Central AstroCore/AstroLSP tables can describe mappings close to their relevant lifecycle, including capability conditions for LSP mappings.[^astro-mappings]

Failure modes and constraints for Plait:

- Correctness can depend on physically ordering imports.
- Dictionary-like tables deep-merge, list-like tables replace, selected lists opt into extension, and function notation is required for manual list edits or safe access to lazy-loaded modules.[^astro-plugins]
- The advanced escape hatch mutates a previously accumulated options table. The result depends on both ordering and the structure of upstream plugin options.
- Configuration concepts are split by lifecycle-owning subsystem: general mappings live in AstroCore, attached LSP mappings in AstroLSP, and plugin-specific mappings may live in plugin specs.[^astro-mappings]
- Community packs are explicitly community-maintained rather than core-supported, creating a provenance and compatibility boundary.[^astro-community]

Plait should represent dependencies and ordering as data rather than source-file position, avoid asking users to mutate a partially resolved plan, and make module provenance/support status visible.

### NvChad: native primitives remain useful, timing still leaks

NvChad uses a starter repository that imports the main framework as a plugin. It encourages direct `vim.keymap.set`/`vim.keymap.del` for mappings and plugin-spec overlays for plugins.[^nvchad-walkthrough][^nvchad-plugins][^nvchad-mappings]

Strengths:

- Native Neovim APIs remain the user's vocabulary for ordinary customization.
- The starter/framework split leaves the personal config small and separately owned.
- Defaults can be disabled and plugin options extended without copying the framework.

Failure modes and constraints for Plait:

- The mapping guide warns that startup-time deletion does not override LSP mappings because those are created later; the override must move into the attach callback.[^nvchad-mappings]
- Plugin customization again shifts from a simple options table to a function that mutates existing configuration when evaluation timing matters.[^nvchad-plugins]
- Users are expected to understand lazy-loading details to avoid performance regressions.

Plait should not replace native APIs for arbitrary custom work. It should, however, own and expose the lifecycle of effects contributed by Plait modules so that removing or overriding one does not require guessing when it was created.

### mini.nvim: consistency and independence scale better than integration breadth

mini.nvim is not a configuration framework, but it is a useful control case. Its modules are independently enabled with a consistent `setup` shape, infer unspecified values from defaults, expose buffer-local configuration where appropriate, and share disabling and naming conventions. The project explicitly rejects filetype/language-specific implementations because of maintenance cost.[^mini]

Strengths:

- Repeated conventions lower the learning cost across a large suite.
- Independent modules reduce graph coupling and permit adoption one piece at a time.
- Defaults are conservative about overwriting existing settings.

Failure mode and constraint for Plait:

- Independence alone does not solve cross-plugin capability integration; conversely, language-specific breadth creates a maintenance surface large enough that mini.nvim explicitly excludes it.[^mini]

Plait should make every module independently understandable and keep its contract consistent, but validate its differentiator with a few integration-heavy slices rather than broad catalog coverage.

## Evidence from adjacent systems

### NixOS modules: typed merge semantics with an explicit cost ceiling

NixOS combines modules that each address a logical concern. Modules separately declare options and define values; declarations provide type, default, example, and documentation. Defining an undeclared option is invalid, and option types govern both validation and how multiple definitions combine. For example, list definitions concatenate while plain strings reject multiple definitions.[^nixos-modules][^nix-deep-dive]

This is strong evidence that merge behavior belongs to the declared field contract, not to a universal table-merging utility. It also shows the value of validating the assembled configuration before applying it and attaching source locations to errors.

The cost is visible in the escape machinery. Override priorities (`mkOverride`, `mkForce`, `mkDefault`), separate ordering controls, conditional definitions, and freeform submodules add expressive power. NixOS warns that freeform option trees nullify name checking, and recommends confining them to submodules.[^nixos-priority][^nixos-freeform]

Constraints for Plait:

- Each public field needs declared validation and composition behavior.
- Conflicting singleton values should fail rather than silently choose a winner.
- Defaults should have visibly lower precedence than explicit author choices.
- A raw provider escape hatch should be namespaced and intentionally less validated; it must not turn the whole capability tree freeform.
- v0.1 should avoid a user-facing priority algebra. If normal customization needs numeric priorities or conditional merge combinators, the API is too deep.

### VS Code settings: schema-driven discovery, bounded scopes, visible reset

VS Code exposes settings through both JSON and a searchable UI generated from extension-contributed schemas. Schemas carry types, defaults, descriptions, constraints, enum labels, scope, and deprecation messages; JSON editing gets completion and validation. The UI can filter modified settings and reset values to defaults.[^vscode-contributions][^vscode-settings]

VS Code also publishes a precedence ladder from defaults through user, remote, workspace, folder, language-specific, and policy scopes. Primitive and array values replace, while object values merge. The docs call out non-obvious interactions such as language-specific user settings overriding non-language-specific workspace settings and combined-language blocks having identity distinct from individual language blocks.[^vscode-settings]

Constraints for Plait:

- Module metadata should be sufficient to generate documentation, completion annotations, validation, and an effective-config/modified view from one source.
- Authors need a first-class way to answer "what changed from the default?" and reset a choice.
- Scope and precedence dimensions must remain few. v0.1 should not combine module, provider, language, project, buffer, and machine overlays unless each is essential and inspectable.
- Lists should default to replacement or use domain-specific keyed identities; implicit concatenation creates duplicates and makes removal unclear.

## Cross-system synthesis

These are inferences from the primary-source behavior above, not claims made verbatim by any one project.

### Patterns worth adopting

1. **Capability selection with curated defaults.** One author choice should activate a coherent result, as Extras and AstroCommunity packs demonstrate.
2. **User-owned ordinary Lua.** Plait should coexist with direct Neovim configuration and arbitrary plugins.
3. **One consistent module contract.** Repeat names and setup concepts across modules as mini.nvim does.
4. **Schema-like declarations.** Public options need descriptions, defaults, examples, validation, and field-specific composition semantics.
5. **Validate, then apply.** Resolve a plan before creating options, keymaps, autocommands, plugin additions, or commands.
6. **Explain the resolved result.** Show active modules, dependency/provenance edges, effective values, contributors, and disabled/replaced effects.
7. **Bounded escape hatches.** Allow direct Neovim Lua and namespaced provider options without mirroring provider APIs.

### Recurring failures to design out

1. **Hidden temporal coupling.** An override should not work or fail based on whether a provider attached later.
2. **Source-order semantics.** Import order should not be the primary dependency or precedence mechanism.
3. **Generic deep merge.** Lua's mixed map/list tables make "merge" ambiguous; documented exceptions inevitably multiply.
4. **Anonymous list effects.** A keymap, autocmd, tool, or provider contribution needs semantic identity if users can replace or remove it.
5. **Mutation callbacks as the normal escape.** Functions over partially accumulated tables are powerful but difficult to validate, explain, and reproduce.
6. **Abstraction inversion.** Requiring provider names and option layouts for common capability choices merely relocates fragmented configuration.
7. **Unbounded scope/provider matrices.** Every added dimension multiplies precedence, compatibility, documentation, and testing obligations.
8. **Silent conflict resolution.** Last-writer-wins is convenient until two modules claim an exclusive capability or mapping; actionable errors are safer.
9. **Catalog-first growth.** Community pack breadth and language-specific integrations have a distinct support burden; module provenance and a narrow supported core are necessary.

## Product/API constraints for v0.1

1. A module request should express desired capability, not plugin installation or load events.
2. Resolution must be deterministic and independent of file enumeration order.
3. Public fields must define one of a small vocabulary of operations such as set, keyed extend, replace, or disable. Do not infer behavior from whether a Lua table happens to look list-like.
4. Effects that may be overridden need stable identities: at minimum module, keymap mode/lhs, autocmd identity/group, command, provider role, and external tool.
5. Exclusive capability/provider conflicts must fail with both contributors and a repair suggestion.
6. The framework must be able to render the effective plan and trace every effect to its module before or after application.
7. Ordinary overrides should be declarative and validated. An imperative hook may exist only as a clearly marked terminal escape hatch whose effects cannot be fully explained.
8. Raw provider options should live below an explicit provider boundary and link users to provider documentation; Plait should not copy provider schemas wholesale.
9. Direct `vim.*` configuration and provider commands/APIs must continue to work outside Plait.
10. Keep v0.1's supported module set small enough to test composition, conflict, lifecycle, and provider escape behavior rather than breadth.
11. Treat `vim.pack` as infrastructure below this authoring model, not as a competing or user-selectable abstraction.

## Newly exposed decisions

The research narrows the design but does not settle these choices:

1. **Customization vocabulary:** Which explicit operations are sufficient for v0.1 fields: set, replace, keyed extend, disable, and possibly transform?
2. **Identity model:** Which effects require framework-assigned IDs versus natural keys such as mapping mode/lhs?
3. **Escape timing:** Is one post-resolution hook necessary in v0.1, and if so, what guarantees and introspection limitations does it declare?
4. **Introspection floor:** Is a Lua-returned plan plus `:checkhealth` enough, or must v0.1 include an interactive effective-config/why view?
5. **Provenance policy:** How are core, third-party, and local modules labeled, versioned, and supported without creating a marketplace in v0.1?
6. **Override scopes:** Does v0.1 need only framework defaults, module contributions, and one user layer, or is language/project-local scope essential?

No external blocker was found. These are product decisions for the quality-bar, capability-slice, and integrated-spec tickets already blocked by this research.

## Sources

All sources are first-party project documentation or source repositories, accessed 2026-09-05.

[^lazy-config]: LazyVim, [Configuration](https://www.lazyvim.org/configuration).
[^lazy-general]: LazyVim, [General Settings](https://www.lazyvim.org/configuration/general).
[^lazy-plugins]: LazyVim, [Plugins](https://www.lazyvim.org/configuration/plugins).
[^lazy-extras]: LazyVim, [Extras](https://www.lazyvim.org/extras).
[^astro-user]: AstroNvim, [Managing User Configuration](https://docs.astronvim.com/configuration/manage_user_config/).
[^astro-plugins]: AstroNvim, [Customizing Plugins](https://docs.astronvim.com/configuration/customizing_plugins/).
[^astro-community]: AstroNvim, [AstroCommunity](https://docs.astronvim.com/astrocommunity/).
[^astro-mappings]: AstroNvim, [Customize Mappings](https://docs.astronvim.com/recipes/mappings/).
[^nvchad-walkthrough]: NvChad, [Walkthrough](https://nvchad.com/docs/config/walkthrough).
[^nvchad-plugins]: NvChad, [Manage Plugins](https://nvchad.com/docs/config/plugins).
[^nvchad-mappings]: NvChad, [Mappings](https://nvchad.com/docs/config/mappings).
[^mini]: mini.nvim, [README and general principles](https://github.com/nvim-mini/mini.nvim#general-principles).
[^nixos-modules]: NixOS Manual 26.05, [Writing NixOS Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules).
[^nixos-priority]: NixOS Manual 26.05, [Setting Priorities](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities).
[^nixos-freeform]: NixOS Manual 26.05, [Freeform modules](https://nixos.org/manual/nixos/stable/#sec-freeform-modules).
[^nix-deep-dive]: nix.dev, [Module system deep dive](https://nix.dev/tutorials/module-system/deep-dive.html).
[^vscode-settings]: Visual Studio Code, [User and workspace settings](https://code.visualstudio.com/docs/configure/settings).
[^vscode-contributions]: Visual Studio Code Extension API, [Configuration contribution point](https://code.visualstudio.com/api/references/contribution-points#contributes.configuration).
