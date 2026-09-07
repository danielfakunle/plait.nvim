# Documentation

The documentation site for the library, built with [TanStack Start](https://tanstack.com/start),
[Fumadocs](https://fumadocs.dev/), and Tailwind CSS.

## Development

Run commands from the monorepo root:

```bash
vp run dev
```

Documentation content lives in `apps/docs/content/`. Add or edit MDX files there; Fumadocs uses
`meta.json` files to configure navigation. Application routes and shared UI live in `src/`.

## Commands

Run package-specific commands from `apps/docs`:

| Command                     | Description                            |
| --------------------------- | -------------------------------------- |
| `vp run dev`                | Start the site at `localhost:3000`     |
| `vp run build`              | Create a production build              |
| `vp run preview`            | Preview the production build           |
| `vp run generate-routes`    | Regenerate TanStack Router route types |
| `vp run generate-mdx-types` | Regenerate Fumadocs content types      |
| `vp run clean`              | Remove generated output                |

The production build is emitted to `dist/` and runs as a Nitro server. Configure a
[Nitro deployment preset](https://nitro.build/deploy) for the target hosting provider.
