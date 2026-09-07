# v0.1 environmental prerequisite matrix

Research for [PRO-127](https://linear.app/daniel-tf/issue/PRO-127/research-the-v01-environmental-prerequisite-matrix), conducted 2026-09-06.

## Answer

Plait v0.1 has a small startup-critical environment: Neovim `>=0.12.5,<0.13`, a supported `vim.pack` layout, functional Git, and the four provider checkouts at their qualified revisions. Everything else should be checked without mutating external state and scoped to the capability that needs it. Missing or incompatible language servers, formatters, Node, Mason download tools, clipboard backends, and network access must not invalidate the effective plan or stop unrelated capabilities.

The supported runtime tuples are glibc Linux and macOS on x86_64 or arm64. Other environments are not inherently invalid, so they receive a qualification warning and may continue. By contrast, an unsupported Neovim version or provider checkout drift is startup-blocking because Plait cannot claim or safely apply its versioned integration contract.

Mason introduces a reproducibility requirement not captured by the plugin and executable pins alone. Its default GitHub registry follows the latest release, and package receipts record the registry release used. Plait's compatibility manifest should therefore pin `mason-org/mason-registry` release `2026-09-07-abaft-pruner` (source commit `93b6e9e56b647c1aa6a2ae529e50e0ae3367a885`) for the initial matrix. That release contains the exact recipes for `lua-language-server` 3.19.1, `stylua` 2.5.2, and npm-backed `oxfmt` 0.66.0.[^mason-registry-source][^registry-release][^registry-lua-ls][^registry-stylua][^registry-oxfmt]

## Classification

- **Startup-blocking:** Plait cannot validate or apply the selected providers safely. Stop before provider configuration; report completed package side effects if any.
- **Operation degradation:** startup and unaffected capabilities continue, but a named capability action, language attachment, formatting operation, clipboard direction, or explicit maintenance operation is unavailable.
- **Qualification warning:** the configuration is meaningful and may run, but the environment or optional fast path is outside the release-qualified evidence. A warning alone must not become a startup failure.

## Host and runtime matrix

| Prerequisite | Exact v0.1 requirement | Used by | Missing or incompatible behavior |
| --- | --- | --- | --- |
| Neovim | `>=0.12.5,<0.13`; qualify exactly 0.12.5 | Plait, `vim.pack`, all providers | **Startup-blocking.** Reject before any managed side effect. `vim.pack` is present in 0.12 but remains experimental, so 0.13 and nightly are not assumed compatible.[^nvim-pack][^lspconfig-readme] |
| OS/libc/architecture | glibc Linux or macOS; x86_64 or arm64 | Release qualification and native tool assets | **Qualification warning** outside the four supported families unless a concrete binary cannot execute, in which case only its operation degrades. The selected Mason recipes publish assets for all four qualified tuples.[^registry-lua-ls][^registry-stylua] |
| Git | A functional `git` on `PATH`; no upstream minimum version is documented | `vim.pack` clone, checkout, fetch, revision inspection, and submodules | **Startup-blocking** when Plait cannot verify active provider revisions or activate required packages. Git older than 2.27 loses blobless clone optimization but is not rejected solely for age; record the exact Git version in qualification.[^nvim-pack-source] |
| `stdpath('data')/site` in `'packpath'` | Must contain the native managed package root | `vim.pack.add()` activation | **Startup-blocking.** Diagnose `--clean`, a startup-time `$XDG_DATA_HOME` change, or a custom `'packpath'` before reporting providers as absent.[^nvim-pack] |
| Installed provider source and revision | Canonical source plus exact commit for every selected provider | Provider application | **Startup-blocking.** Source collision or revision drift stops before provider configuration; package synchronization is the repair.[^nvim-pack] |
| Writable config/data paths | Config path for `nvim-pack-lock.json`; data path for package checkouts; Mason data path for tools | Fresh package activation and explicit package/tool mutation | **Operation degradation** for the explicit mutation. If a required provider is not already installed, startup remains blocked pending successful synchronization. An unchanged installed startup should not require a write.[^nvim-pack][^mason-doc] |
| Network, DNS, and TLS trust | Reach configured Git and release/npm endpoints | Fresh provider activation, package synchronization, Mason registry/tool install or update, Blink binary download | **Operation degradation** for the requested mutation/download. If a provider is absent, provider application remains startup-blocked until synchronization succeeds. Normal installed startup and tool inspection must be network-free.[^nvim-pack][^mason-doc][^blink-install] |
| `curl` or GNU `wget` | At least one functional downloader | Mason registry and selected Mason installs; Blink Rust fuzzy download specifically requires `curl` | **Operation degradation.** Mason ensure/update fails. Blink must fall back to Lua rather than fail completion; emit the provider's warning once.[^mason-readme][^blink-install][^blink-fuzzy] |
| GNU `tar` and `gzip` | Functional archive tools | Mason install of `lua-language-server`'s `.tar.gz` asset | **Operation degradation** of Lua tool ensure/update, not Lua editing startup when a compatible tool already resolves elsewhere.[^mason-readme][^registry-lua-ls] |
| `unzip` | Functional unzip | Mason install of StyLua's `.zip` asset | **Operation degradation** of StyLua ensure/update, not formatting when a compatible executable already resolves elsewhere.[^mason-readme][^registry-stylua] |
| Node.js | `>=16.20.0` for project-owned TypeScript 7.0.2; `^20.19.0 || >=22.12.0` for oxfmt 0.66.0, so the complete TypeScript journey has the latter effective floor | Project-local `node_modules/.bin/tsc`; project/Mason/PATH `oxfmt` launcher | **Operation degradation** of TypeScript LSP and/or formatting. Do not block Lua, editor, tooling inspection, or completion. Version-probe the executable, not merely its path.[^typescript-package][^oxfmt-package] |
| npm | A functional npm compatible with the selected Node runtime | Mason install/update of npm-backed `oxfmt` only | **Operation degradation** of Mason's oxfmt mutation. It is not required to run an already installed compatible `oxfmt` or to inspect unrelated tools.[^registry-oxfmt][^mason-npm] |
| System clipboard backend | macOS `pbcopy`/`pbpaste`, Wayland `wl-copy`/`wl-paste`, X11 `xsel` or `xclip`, another documented provider, or terminal OSC 52 | `editor` clipboard policy | **Operation degradation** limited to unavailable copy and/or paste directions. OSC 52 copy is built in; paste is not universally supported. Never block startup.[^nvim-provider] |
| Blink Rust fuzzy library | v1.10.2 prebuilt for the qualified tuple, or a Rust toolchain to build it; Lua implementation is always available | Completion ranking fast path | **Qualification warning plus bounded operation degradation** to Lua matching when unavailable. Keep `prefer_rust_with_warning`; never select strict `rust` for the built-in because that would turn an optional accelerator into a setup failure.[^blink-install][^blink-fuzzy][^blink-commit] |

Python, Ruby, Perl, the Neovim Node host, Cargo, Go, LuaRocks, Tree-sitter, a C compiler, and a shell command API are **not** v0.1 prerequisites. The chosen providers are Lua plugins, Mason's selected recipes use release archives or npm, and formatter execution uses argument-vector `vim.system()` calls. Neovim remote-plugin hosts are needed only by plugins outside this catalog.[^nvim-provider][^conform-runner]

## Qualified providers

| Provider | Qualified revision | Runtime consequence |
| --- | --- | --- |
| `nvim-lspconfig` | `615d7b2712efb2f530a83a9d0466acafba6b1d6f` | Configuration data only; requires Neovim 0.11.3+, satisfied by 0.12.5. `lua_ls` invokes `lua-language-server`. `tsc` probes local and PATH `tsc`/`tsgo` candidates with `--version`, requires major 7+, then starts `--lsp --stdio`.[^lspconfig-readme][^lua-ls-config][^tsc-config] |
| `blink.cmp` | `78336bc89ee5365633bcf754d93df01678b5c08f` (tag v1.10.2) | Neovim 0.10+ is sufficient. Rust fuzzy matching may download a tuple-specific library using curl and Git; Lua fallback preserves completion without an external runtime.[^blink-install][^blink-fuzzy][^blink-commit] |
| `conform.nvim` | `016802de402556da54c36bd7359b441266b01cdd` | Neovim 0.10+ is sufficient. It resolves and spawns formatter executables with `vim.system`; StyLua is a bare executable, while oxfmt searches upward for `node_modules/.bin/oxfmt` before `PATH`.[^conform-readme][^conform-stylua][^conform-oxfmt][^conform-runner] |
| `mason.nvim` | `2a6940af80375532e5e9e7c1f2fc6319a1b7a69d` (v2.3.1) | Neovim 0.10+ is sufficient. Setup prepends Mason's `bin` by default. Inspection can read installation receipts; install/reinstall is asynchronous through `Package:install()`, and registry refresh can be synchronous only when explicitly requested.[^mason-readme][^mason-doc][^mason-package] |

All four provider revisions are startup requirements, not host executables. A missing provider is repaired through package synchronization; an incorrect revision is drift and must not be tolerated merely because `require()` succeeds.

## Mason operation matrix

Plait should configure `registries = { "github:mason-org/mason-registry@2026-09-07-abaft-pruner" }` and disable automatic stale-cache refresh for normal startup checks. Mason's source parser accepts an `@version`, and a fixed installed version is not updated; the GitHub source downloads that release's `registry.json.zip` and checksums.[^mason-registry-source][^mason-registry-parse]

| Plait operation | Required runtime | Failure boundary |
| --- | --- | --- |
| Startup check / inspect | Mason setup, pinned local registry/receipts where relevant, executable lookup, and direct version probes | Missing receipt, stale registry identity, missing executable, or bad version degrades only the owning language/operation. Do not refresh a registry, install, or update during inspection.[^mason-package] |
| Ensure `lua-language-server@3.19.1` | Network, downloader, GNU tar, gzip, writable Mason paths, pinned registry recipe | Explicit tooling operation fails; Lua LSP remains degraded. The recipe provides native assets for all qualified tuples.[^registry-lua-ls] |
| Ensure `stylua@2.5.2` | Network, downloader, unzip, writable Mason paths, pinned registry recipe | Explicit tooling operation fails; Lua formatting remains degraded.[^registry-stylua] |
| Ensure `oxfmt@0.66.0` | Network, Node `^20.19.0 || >=22.12.0`, npm, writable Mason paths, pinned registry recipe | Explicit tooling operation fails; TypeScript formatting may still use a compatible workspace-local or PATH executable.[^registry-oxfmt][^mason-npm][^oxfmt-package] |
| Update a selected tool | Same prerequisites as its ensure path; exact requested version retained | Failure is non-startup and reported per tool. Never broaden to latest or update unrelated packages. A successful update changes external state but does not require provider reapplication.[^mason-package] |
| Registry refresh | Network, downloader, writable Mason cache/data | Not part of startup. Refresh only the pinned release; a floating latest refresh would invalidate release reproducibility.[^mason-doc][^mason-registry-source] |

Mason's documented Unix baseline also lists Git. Plait already requires it for `vim.pack`, but the selected Mason package recipes do not add a second startup reason for it. Mason may shell out to other ecosystem package managers for other packages; those are outside the built-in catalog and must not become global health requirements.[^mason-readme]

## Built-in journeys

### Shared startup

1. Validate Neovim and the platform tuple before managed effects.
2. Validate `site` in `'packpath'`, functional Git, canonical provider sources, and exact active revisions.
3. Activate all provider packages with one `vim.pack.add(..., { load = false })` call. A missing package needs explicit consent; denial, non-interactive absence of consent, or install failure stops provider application.
4. Apply providers only after every checkout validates. Missing external tools produce diagnostics and effective-plan state but do not stop provider setup.

This makes package/provider defects startup-blocking while preserving the existing contract that tool defects are localized degradation.[^nvim-pack][^nvim-pack-source]

### Lua journey

- `lua-language-server` must resolve at exactly 3.19.1 for Lua LSP attachment. The Mason recipe supplies self-contained native assets for every qualified tuple; no separate Lua runtime is required.[^registry-lua-ls][^lua-ls-release]
- `stylua` must resolve at exactly 2.5.2 for manual and on-save formatting. Its release binary reads stdin and supports the exact arguments used by Conform; no Rust toolchain is needed to run the prebuilt binary.[^registry-stylua][^stylua-readme][^conform-stylua]
- If either executable is absent or fails its version probe, only that operation degrades. Completion's buffer/path/snippet sources remain available; LSP completion is naturally absent when Lua LSP does not attach.

### TypeScript journey

- Resolve the nearest workspace-local `node_modules/.bin/tsc` before `PATH`; require `>=7.0.0,<8.0.0`, qualified at 7.0.2. TypeScript 7's npm launcher requires Node `>=16.20.0`; nvim-lspconfig independently rejects a candidate whose `--version` does not report major 7+ and starts the accepted binary with `--lsp --stdio`.[^typescript-package][^typescript-release][^tsc-config]
- Resolve `oxfmt` workspace-local, then Mason, then `PATH`; require exactly 0.66.0. Its npm package requires Node `^20.19.0 || >=22.12.0`, making that the effective Node floor when the complete TypeScript journey is selected.[^conform-oxfmt][^registry-oxfmt][^oxfmt-package]
- Missing Node or `tsc` degrades TypeScript language intelligence and its LSP completion only. Missing `oxfmt` degrades manual/on-save TypeScript formatting only. Neither condition affects Lua or generic completion sources.
- TypeScript 7.0 does not support editor journeys that require language-server plugins for Vue, MDX, Astro, Svelte, or Angular templates. Those project kinds are outside v0.1 and should produce a qualification warning rather than silently claiming the plain TypeScript journey covers them.[^typescript-release]

## Required diagnostics and probes

- Probe executability and capture actual output from `git version`, each provider checkout's `HEAD` and origin, `lua-language-server --version`, `stylua --version`, `tsc --version`, `oxfmt --version`, `node --version`, and `npm --version` where npm mutation is requested.
- Treat a runnable path with the wrong version as incompatible, not present. Preserve source selection in inspection: workspace, Mason, or `PATH`.
- Record the Mason registry release and receipt registry metadata alongside executable versions in qualification evidence. An exact executable version installed from an unreviewed recipe may run, but is not reproducibly qualified.
- Collapse duplicate startup diagnostics by root cause. For example, one incompatible Node may degrade both `tsc` and `oxfmt`, but each affected operation must remain visible.
- Keep normal startup non-mutating and network-free once providers and tools are installed. Package synchronization and Mason ensure/update are explicit owner actions.

## Decision gist

Only Neovim compatibility, the native package path, Git, and exact provider checkouts block startup; tools and mutation utilities degrade their owning operations, while unsupported tuples and optional fast paths warn. Pin the Mason registry release in addition to provider and executable versions.

## Primary sources

All sources are first-party documentation, tagged source, release metadata, or package-registry metadata accessed 2026-09-06.

[^nvim-pack]: [Neovim 0.12.5 `pack.txt`](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/pack.txt).
[^nvim-pack-source]: [Neovim 0.12.5 `vim.pack` source](https://github.com/neovim/neovim/blob/v0.12.5/runtime/lua/vim/pack.lua).
[^nvim-provider]: [Neovim 0.12.5 provider and clipboard documentation](https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/provider.txt).
[^lspconfig-readme]: [`nvim-lspconfig` qualified-revision README](https://github.com/neovim/nvim-lspconfig/blob/615d7b2712efb2f530a83a9d0466acafba6b1d6f/README.md).
[^lua-ls-config]: [`nvim-lspconfig` qualified `lua_ls` configuration](https://github.com/neovim/nvim-lspconfig/blob/615d7b2712efb2f530a83a9d0466acafba6b1d6f/lsp/lua_ls.lua).
[^tsc-config]: [`nvim-lspconfig` qualified `tsc` configuration](https://github.com/neovim/nvim-lspconfig/blob/615d7b2712efb2f530a83a9d0466acafba6b1d6f/lsp/tsc.lua).
[^blink-install]: [`blink.cmp` qualified-revision installation documentation](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/doc/installation.md).
[^blink-fuzzy]: [`blink.cmp` qualified-revision fuzzy matcher documentation](https://github.com/Saghen/blink.cmp/blob/78336bc89ee5365633bcf754d93df01678b5c08f/doc/configuration/fuzzy.md).
[^blink-commit]: [`blink.cmp` v1.10.2 qualified commit](https://github.com/Saghen/blink.cmp/commit/78336bc89ee5365633bcf754d93df01678b5c08f).
[^conform-readme]: [`conform.nvim` qualified-revision README](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/README.md).
[^conform-stylua]: [`conform.nvim` qualified StyLua adapter](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/formatters/stylua.lua).
[^conform-oxfmt]: [`conform.nvim` qualified oxfmt adapter](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/formatters/oxfmt.lua).
[^conform-runner]: [`conform.nvim` qualified process runner](https://github.com/stevearc/conform.nvim/blob/016802de402556da54c36bd7359b441266b01cdd/lua/conform/runner.lua).
[^mason-readme]: [`mason.nvim` v2.3.1 README and Unix requirements](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/README.md).
[^mason-doc]: [`mason.nvim` v2.3.1 help](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/doc/mason.txt).
[^mason-package]: [`mason.nvim` v2.3.1 package API](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-core/package/AbstractPackage.lua).
[^mason-npm]: [`mason.nvim` v2.3.1 npm manager](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-core/installer/managers/npm.lua).
[^mason-registry-source]: [`mason.nvim` v2.3.1 GitHub registry source](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-registry/sources/github.lua).
[^mason-registry-parse]: [`mason.nvim` v2.3.1 registry source parser](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-registry/sources/init.lua).
[^registry-release]: [Mason registry release `2026-09-07-abaft-pruner`](https://github.com/mason-org/mason-registry/releases/tag/2026-09-07-abaft-pruner).
[^registry-lua-ls]: [Pinned Mason `lua-language-server` recipe](https://github.com/mason-org/mason-registry/blob/93b6e9e56b647c1aa6a2ae529e50e0ae3367a885/packages/lua-language-server/package.yaml).
[^registry-stylua]: [Pinned Mason `stylua` recipe](https://github.com/mason-org/mason-registry/blob/93b6e9e56b647c1aa6a2ae529e50e0ae3367a885/packages/stylua/package.yaml).
[^registry-oxfmt]: [Pinned Mason `oxfmt` recipe](https://github.com/mason-org/mason-registry/blob/93b6e9e56b647c1aa6a2ae529e50e0ae3367a885/packages/oxfmt/package.yaml).
[^lua-ls-release]: [Lua Language Server 3.19.1 release](https://github.com/LuaLS/lua-language-server/releases/tag/3.19.1).
[^stylua-readme]: [StyLua v2.5.2 README](https://github.com/JohnnyMorganz/StyLua/blob/v2.5.2/README.md).
[^typescript-package]: [Official npm metadata for TypeScript 7.0.2](https://registry.npmjs.org/typescript/7.0.2).
[^typescript-release]: [Microsoft's TypeScript 7.0 announcement](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/).
[^oxfmt-package]: [Official npm metadata for oxfmt 0.66.0](https://registry.npmjs.org/oxfmt/0.66.0).
