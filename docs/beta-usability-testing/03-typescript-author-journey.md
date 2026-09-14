# Beta TypeScript Author Journey

This procedure validates project-owned and hybrid tool resolution, the TypeScript language service, JavaScript/TypeScript formatting, and deterministic precedence among tool candidates.

## 1. Create an isolated TypeScript project

Use Fish and the same Neovim app prepared by the bootstrap procedure:

```fish
set -gx PLAIT_REPO /Users/daniel/Developer/plait.nvim
set -gx NVIM_APPNAME plait-beta-ux
set -gx PLAIT_UX /tmp/plait-beta-ux

mkdir -p $PLAIT_UX/typescript-project/src
cd $PLAIT_UX/typescript-project
npm init -y
npm install --save-dev typescript@'>=7.0.0 <8.0.0' @oxc-project/oxfmt@0.66.0
printf '{"compilerOptions":{"strict":true},"include":["src"]}\n' >tsconfig.json
printf 'const greeting: string = "hello"\nconsole.log(greeting)\n' >src/main.ts
```

If npm cannot resolve those qualified versions, record a blocked environment result rather than substituting incompatible versions. Confirm the project executables directly:

```fish
./node_modules/.bin/tsc --version
./node_modules/.bin/oxfmt --version
node --version
```

Expected: TypeScript `>=7.0.0,<8.0.0`, oxfmt `0.66.0`, and Node `>=22.12.0`.

## 2. Enable the TypeScript module

Add `'lang.typescript'` to the `config:select` list in `~/.config/$NVIM_APPNAME/init.lua`. If the Lua procedure added custom settings, they may remain.

Open the project from its root so project-owned candidates can be discovered:

```fish
cd $PLAIT_UX/typescript-project
nvim src/main.ts
```

Run:

```vim
:lua vim.print(_G.plait_apply)
:Plait inspect modules lang.typescript
:Plait inspect tools tsc
:Plait inspect tools oxfmt
:Plait inspect effects
:checkhealth plait
```

Expected:

- Apply is `performed`.
- `lang.typescript` contributes `tsc`, `oxfmt`, four filetype formatting chains, and the TypeScript server.
- `tsc` is project-owned and resolves from `node_modules/.bin/tsc`.
- `oxfmt` is hybrid and the compatible project candidate takes precedence over Mason/PATH candidates.
- The server command uses the resolved `tsc` followed by `--lsp --stdio`.
- Every effect is completed and health agrees with inspection.

## 3. Test TypeScript behavior

Wait for the `tsc` client to attach. Add a type error and a reusable symbol:

```typescript
function greet(name: string): string {
  return `hello ${name}`
}

const message: number = greet('Plait')
console.log(message)
```

Verify diagnostics appear, then exercise `gd`, `gr`, `K`, rename, diagnostic navigation, and completion as in the Lua journey.

Make the file visibly misformatted and run `:Plait format`. Expected: oxfmt formats the buffer and the formatting operation completes successfully. Repeat in `.js`, `.jsx`, and `.tsx` files to confirm the declared filetype coverage.

## 4. Test project ownership feedback

Quit, temporarily hide the project TypeScript executable, and reopen:

```fish
mv node_modules/.bin/tsc node_modules/.bin/tsc.plait-hidden
nvim src/main.ts
```

Run:

```vim
:Plait inspect tools tsc
:Plait tooling ensure
:lua vim.print(require('plait').actions.language.hover())
```

Expected:

- `tsc` is absent and its repair points to the project environment.
- Tooling refuses to install a project-owned tool and returns `environment_unavailable`.
- The TypeScript language action is unavailable with tool-state details; Lua can remain operational.
- Plait does not silently use an unrelated global TypeScript executable.

Restore the executable in Fish:

```fish
mv node_modules/.bin/tsc.plait-hidden node_modules/.bin/tsc
```

Restart and confirm `tsc` returns to `satisfied`.

## Feedback rubric

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Project candidate discovery | | | | |
| Hybrid candidate precedence | | | | |
| TypeScript language service | | | | |
| Four-filetype formatting | | | | |
| Project ownership boundary | | | | |
| Degraded action feedback | | | | |

Record whether the tool records made candidate choice and ownership understandable without reading implementation code.
