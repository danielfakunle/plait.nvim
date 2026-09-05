# Neovim and `vim.pack` integration constraints

Research for [PRO-122](https://linear.app/daniel-tf/issue/PRO-122/research-neovim-and-vimpack-integration-constraints), conducted 2026-09-05.

## Answer

Plait can use `vim.pack` as its installation and runtime-path mechanism, but it cannot delegate module discovery, dependency semantics, or configuration ordering to it. On the latest stable release reviewed, Neovim 0.12.5, `vim.pack` installs Git repositories into one managed optional-package directory, records revisions in a lockfile, and adds packages to the runtime path. Its plugin specification has no dependency field, installations are parallel, and normal startup deliberately separates `init.lua` execution from later sourcing of plugin entrypoints. Plait therefore needs an explicit module-to-plugin resolution phase, its own dependency graph and deterministic configuration phase, and an error policy around a synchronous, side-effecting, experimental API.

Supporting `vim.pack` directly establishes Neovim 0.12 as the minimum possible version. Although 0.12.5 is a stable Neovim release, its help still marks `vim.pack` itself experimental. Plait should treat the exact 0.12 contract as a versioned integration boundary rather than assuming current development-branch behavior is stable.

## Evidence baseline

The stable baseline is Neovim 0.12.5, the latest non-prerelease published by Neovim at the time of research. Neovim 0.12 release notes list the built-in `vim.pack` manager as a new feature. Claims below marked **documented** come from the 0.12.5 help; claims marked **source-confirmed** describe the tagged 0.12.5 implementation where the help does not fully specify a consequence. Claims marked **inferred** are design consequences for Plait, not Neovim guarantees.

The development `master` implementation is considered separately because it already differs from 0.12.5 in user-visible areas, including a configurable `'packlockfile'`, Ex management commands, package manifests, and event batching. Those are not safe v0.1 dependencies unless Plait explicitly targets a later released version.

## Module discovery

- **Documented:** `require('foo.bar')` searches each active runtime directory in order for `lua/foo/bar.lua` and then `lua/foo/bar/init.lua`, then repeats the search for native libraries before falling back to Lua's default searchers. The first match wins.
- **Documented:** `require()` caches the returned module in `package.loaded`; subsequent calls do not search or execute the module again. Changing a plugin revision in a running process does not reload already-required modules.
- **Documented:** the relevant search order is the output of `nvim_list_runtime_paths()`, which includes `'runtimepath'` and package runtime paths. Discovering modules by scanning only `'runtimepath'` or the filesystem would not faithfully reproduce Neovim resolution.
- **Documented:** `vim.pack.add()` places every managed repository under `stdpath('data')/site/pack/core/opt/<name>` and invokes `:packadd` or a caller-provided loader to make it reachable.
- **Inferred constraint:** Plait module names and plugin repository names are separate namespaces. `vim.pack` derives or accepts only a package directory name; it does not map a Plait module identifier to a Lua `require()` name. Plait must define that mapping and detect collisions before invoking `require()`.
- **Inferred constraint:** because runtime discovery is ordered and first-match-wins, duplicate Lua module paths across plugins are order-dependent. Plait should either reject ambiguous providers or make provider precedence an explicit, inspectable rule.

## Dependency declaration

- **Documented:** a stable 0.12 `vim.pack.Spec` contains `src`, optional `name`, optional `version`, and arbitrary `data`. It has no dependency field and assigns no dependency semantics to `data`.
- **Documented:** new plugin installations within one `add()` are performed in parallel, though `add()` waits for all of them before returning.
- **Documented:** duplicate additions in one session do nothing after the first registration. Conflicting duplicate `src` or `version` values are rejected by the implementation.
- **Inferred constraint:** dependency order cannot be represented as `vim.pack` metadata and input list order must not be mistaken for installation order. Plait must resolve, validate, and flatten its own dependency graph into a deduplicated plugin-spec list.
- **Inferred constraint:** install order and configuration order must be modeled separately. A topological plugin list is still useful for deterministic diagnostics and configuration, but parallel installation means plugins cannot rely on another plugin's install operation having completed first unless Plait adds an explicit post-install phase.

## Installation and loading

- **Documented:** Git must be executable and every source must be cloneable by Git. `version = nil` tracks the repository's current default branch; a string names a branch, tag, or commit; a `vim.version.range()` selects the greatest matching strict semver tag (`vX.Y.Z` or `X.Y.Z`).
- **Documented:** installation is synchronous from the caller's perspective: clones run in parallel, but `add()` waits for all attempts before subsequent Lua executes. Initial install prompts by default, so an unattended or first-run startup can block on confirmation unless the caller selects a policy.
- **Documented:** after `add()` returns successfully, plugin Lua can be required immediately.
- **Documented:** `opts.load` defaults to `false` while `init.lua` is being sourced and `true` afterwards. `false` behaves like `:packadd!`: it adds the package to `'runtimepath'` without sourcing `plugin/` and `ftdetect/` files. `true` sources those files; a function is fully responsible for loading.
- **Documented:** Neovim's normal startup sources user configuration first, sets `v:vim_did_init`, then sources plugin scripts. Per runtime directory, matching Vimscript files are sourced before Lua files and files are alphabetical within each group. Package `after/` scripts run later.
- **Documented sharp edge:** repeated `:packadd!` calls during startup insert each optional package before existing package paths, so their later plugin-entrypoint loading order is reversed relative to call order.
- **Inferred constraint:** Plait should not use incidental runtime-path order as its composition protocol. A deterministic Plait phase should call provider configuration explicitly after all required packages have been added. Code that depends on a plugin's `plugin/` entrypoint must either request eager loading deliberately or run after Neovim's plugin-loading phase.

## Startup and configuration ordering

A stable startup sequence available to Plait is:

1. User `init.lua` calls Plait.
2. Plait resolves all enabled modules and their plugin requirements before side effects.
3. Plait calls `vim.pack.add()` with deduplicated specs. Missing repositories are installed and the call waits; package directories become discoverable.
4. Plait requires and configures provider Lua modules in its own declared order, if they do not depend on `plugin/` entrypoints.
5. After `init.lua`, Neovim sources normal plugin entrypoints, package entrypoints, and finally `after/` entrypoints according to startup rules.

This sequence is **inferred**, not prescribed by Neovim. It exposes a required Plait decision: either provider `setup()` is defined to be safe before plugin entrypoints, or Plait must define a later lifecycle hook. Mixing implicit startup sourcing with explicit eager loading would make ordering difficult to explain and risks double initialization in plugins that do not guard against it.

The managed `site` directory must remain in `'packpath'`. Neovim documents that this is normally true but may not be true under `--clean` or if `$XDG_DATA_HOME` is changed during startup. Plait should diagnose this precondition rather than silently reporting modules as missing.

## Lockfile, updates, and removal

- **Documented:** stable 0.12 stores `nvim-pack-lock.json` in `stdpath('config')`. The first `vim.pack` call reads it, reconciles it with disk, installs lockfile entries missing from disk at locked revisions, and repairs corrupt metadata where possible. The lockfile should be version-controlled and not hand-edited.
- **Documented:** an already-installed plugin is not checked against the newly declared `version` during `add()`. Changing a version updates lock metadata, but `vim.pack.update()` is required to move the checkout.
- **Documented:** updates fetch and compute target revisions, then default to an interactive confirmation buffer. Accepted updates change on-disk checkouts and the lockfile; actual updates are logged. Restart is recommended to use updated code, consistent with Lua module caching.
- **Documented:** changing a repository's default branch is not followed automatically when `version` is nil; reinstalling is required.
- **Documented:** removing a spec from configuration does not remove its checkout. The user must restart and call `vim.pack.del()`; deleting an active plugin fails unless forced. A removed spec that is still added by configuration will be reinstalled.
- **Inferred constraint:** Plait must decide whether it owns the shared Neovim lockfile and update/removal UX or merely declares active plugins. Automatic garbage collection is unsafe because the directory and lockfile may contain `vim.pack` plugins declared outside Plait.
- **Inferred constraint:** reproducible startup requires preserving the lockfile, but declaration changes and checkout changes are separate operations. Plait diagnostics should distinguish "declared", "active", "installed", and "at requested revision".

## Error behavior

- **Documented/source-confirmed:** invalid specs and conflicting duplicates throw Lua errors. Git failures, missing refs, and load failures are collected per plugin; successfully processed plugins are still added before `add()` raises one aggregate error.
- **Documented/source-confirmed:** a failed fresh installation is removed from disk and from lock data. Thus an `add()` error does not imply that no side effects occurred: other plugins may have installed and become active.
- **Documented:** changing `src` for an existing name causes immediate deletion followed by a clean install from the new source.
- **Documented:** deleting active plugins errors unless forced. Update and install operations can invoke user confirmation, and installation/update hooks may perform additional side effects.
- **Inferred constraint:** Plait should validate its complete graph and normalized specs before calling `vim.pack.add()`, wrap the call to add module/provider context to failures, and define whether one failed plugin aborts all configuration or permits independent modules to continue. It cannot promise transactional installation because `vim.pack.add()` itself is not transactional across the list.

## Supported Neovim versions and stability

- **Documented:** `vim.pack` first appears as a new feature in Neovim 0.12. It is absent from the tagged 0.11.5 runtime source. Direct integration therefore requires Neovim 0.12 or newer; graceful rejection is preferable to a later `nil` access on older versions.
- **Documented:** Neovim 0.12.5 is a stable release, but `:help vim.pack` says the subsystem remains experimental, "yet should be stable enough for daily use." Neovim's maintenance policy explicitly allows exceptions to normal deprecation guarantees for experimental subsystems.
- **Observed development behavior, not stable:** current `master` has already expanded the contract beyond 0.12.5 with `'packlockfile'`, `:packupdate`/`:packdel`, package manifests and scripts, and different event sequencing. Plait v0.1 should not depend on those details while claiming 0.12 support.
- **Inferred constraint:** the honest v0.1 floor is `nvim >= 0.12.0`, with CI against the oldest supported 0.12 patch and current stable. Because the integration is experimental, Plait needs a small adapter boundary and explicit version-gated tests rather than exposing `vim.pack` tables as its public module schema.

## Decisions exposed for Plait

1. Define whether Plait configures providers during `init.lua` before plugin entrypoints, eagerly loads selected plugins, or introduces a post-plugin lifecycle phase.
2. Define Plait's dependency graph, duplicate-spec reconciliation, cycle errors, and provider precedence independently of `vim.pack`.
3. Decide ownership of the shared `vim.pack` lockfile, update command, stale-plugin removal, confirmation policy, and external `vim.pack` declarations.
4. Decide the failure boundary for partial installation and partial module configuration.
5. Confirm a minimum of Neovim 0.12 and an experimental-API compatibility policy, including which 0.12 patch is tested as the floor.

## Primary sources

- [Neovim 0.12.5 `pack.txt`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/pack.txt): packages, stable-release `vim.pack` contract, examples, lockfile, events, and API fields.
- [Neovim 0.12.5 `vim.pack` source](https://github.com/neovim/neovim/blob/v0.12.5/runtime/lua/vim/pack.lua): validation, parallel installation, lock reconciliation, partial-failure cleanup, loading defaults, update, and deletion behavior.
- [Neovim 0.12.5 `lua.txt`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt): runtime-path module search order, file patterns, first-match behavior, and `require()` caching.
- [Neovim 0.12.5 `starting.txt`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt): complete initialization and plugin sourcing order.
- [Neovim 0.12.5 `repeat.txt`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/repeat.txt): exact `:packadd[!]` behavior and startup insertion-order warning.
- [Neovim 0.12 release news](https://github.com/neovim/neovim/blob/v0.12.0/runtime/doc/news.txt): identifies `vim.pack` as new in 0.12 and records `:packadd` runtime-path cache changes.
- [Neovim 0.12.5 release](https://github.com/neovim/neovim/releases/tag/v0.12.5): stable baseline and publication metadata.
- [Neovim maintenance policy at 0.12.5](https://github.com/neovim/neovim/blob/v0.12.5/MAINTAIN.md): release channels and exceptions to compatibility/deprecation policy for experimental subsystems.
- [Current development `vim.pack` source](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/pack.lua): evidence of post-0.12 evolution; cited only as experimental/unreleased behavior.
