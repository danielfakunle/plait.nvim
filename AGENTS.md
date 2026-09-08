# Repository Guide

## Plugin

- `lua/plait/init.lua` is the public `require('plait')` entrypoint. Tests in `tests/test_*.lua` use
  mini.test and exercise the plugin inside a clean child Neovim configured by `scripts/minimal_init.lua`.
- Run plugin commands from the repository root; the test harness relies on the current working directory.
- `make install` clones the ignored `deps/mini.nvim` test dependency. It does not install the required
  executables: `nvim`, `stylua`, `luacheck`, and `lua-language-server`.
- `make check` runs, in order, formatting checks, lint, LuaLS type checking, and all tests.
- Run one test file with `make test_file FILE=tests/test_plait.lua`. Other focused checks are `make format`,
  `make lint`, `make typecheck`, and `make test`; use `make format_fix` to rewrite Lua formatting.
- New production functions require LuaDoc descriptions and appropriate LuaLS annotations. Comments should
  explain non-obvious decisions or Neovim API constraints, not restate code.

## Code Style

- Keep source files focused. Treat roughly 500 lines as a reorganization signal: split files approaching that
  size along coherent module boundaries unless keeping the file together materially improves the design.

## Documentation Site

- `site/` is a separate pnpm 11.24.0 project using Vite+, TanStack Start, and Fumadocs. Run its commands
  from the repository root as `vp -C site ...`.
- Vite+ built-ins and package scripts are distinct. Use `vp -C site run dev` for the scripted port 3000
  server and `vp -C site run build` for the production build; use `vp -C site check` for format, lint, and
  type checks.
- Run `vp -C site install` after dependency changes or a fresh checkout. Its postinstall regenerates the
  tracked `site/src/routeTree.gen.ts` and ignored Fumadocs types under `site/.source/`. The explicit generators
  are `vp -C site run generate-routes` and `vp -C site run generate-mdx-types`.
- The site currently has no tests; `vp -C site test` exits unsuccessfully and is not a verification step.
- Author docs in `site/content/` with `title` and `description` frontmatter. Navigation is explicit in
  `site/content/meta.json`; its `pages` array accepts page paths and group markers such as `"---Guides---"`.
  Keep MDX to standard Markdown, fenced code blocks (`title` and `tab` metadata are supported), and step
  headings such as `#### Install [step]`.

## Project Context

- Before domain work, read `CONTEXT.md` and any relevant ADR under `docs/adr/`; use the glossary's terms
  rather than introducing synonyms. See `docs/agents/domain.md` for the domain-doc convention.
- Issues belong to Linear team `My Projects`, project `Plait.nvim`. Tracker workflows and the exact triage
  labels are documented in `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`.
