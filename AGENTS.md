## Agent skills

### Issue tracker

Issues for this repo live in Linear under the `My Projects` team and `Plait.nvim` project. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the repo's title-case triage labels: `Needs Triage`, `Needs Info`, `Ready for Agent`, `Ready for Human`, and `Won't Fix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo. See `docs/agents/domain.md`.

## Code documentation

New production code must include appropriate LuaLS annotations and concise comments. Every function needs a LuaDoc description of its behavior; document its parameters and return value when they are not self-evident. Comments should explain non-obvious decisions and native API constraints rather than restating code.

## Documentation site

`site/` is a TanStack Start documentation app built on a limited Fumadocs integration.

- Author pages in `site/content/` with `title` and `description` frontmatter.
- Define navigation in `site/content/meta.json`. Its `pages` array supports page paths and group markers such as `"---Guides---"`.
- Use standard Markdown, fenced code blocks (including `title` and `tab` metadata), and step headings such as `#### Install [step]`.
- Keep MDX within this supported surface.

<!--VITE PLUS START-->

This docs site is using Vite+, a unified toolchain built on top of Vite, Rolldown, Vitest, tsdown,
Oxlint, Oxfmt, and Vite Task. Vite+ wraps runtime management, package management, and frontend
tooling in a single global CLI called `vp`. Vite+ is distinct from Vite, and it invokes Vite through
`vp dev` and `vp build`. Run `vp help` to print a list of commands and `vp <command> --help` for
information about a specific command.

Docs are local at `site/node_modules/vite-plus/docs` or online at https://viteplus.dev/guide/.

### Built-in Commands vs Scripts

Run Vite+ from the docs project with `vp -C site <name>`. `vp -C site <name>` runs a built-in command. `vp -C site run <name>` runs a `package.json` script or a
`vite.config.ts` task. Scripts cannot overwrite built-ins, so `vp -C site dev` and `vp -C site run dev` may do
different things. Check `package.json` and `vite.config.ts` first, and run `vp -C site run <name>` when the
project defines a script or task with that name.

### Review Checklist

- [ ] Run `vp -C site install` after pulling remote changes and before getting started.
- [ ] Run `vp -C site check` and `vp -C site test` to format, lint, type check and test changes.
- [ ] Check if there are `vite.config.ts` tasks or `package.json` scripts necessary for validation,
      run via `vp -C site run <script>`.
- [ ] If setup, runtime, or package-manager behavior looks wrong, run `vp env doctor` and include
      its output when asking for help.

<!--VITE PLUS END-->
