import { defineConfig } from "vite-plus";
import { devtools } from "@tanstack/devtools-vite";

import { tanstackStart } from "@tanstack/react-start/plugin/vite";

import viteReact, { reactCompilerPreset } from "@vitejs/plugin-react";
import babel from "@rolldown/plugin-babel";
import tailwindcss from "@tailwindcss/vite";
import { nitro } from "nitro/vite";
import { lazyPlugins } from "vite-plus";
import { fumadocsMdx } from "fumadocs-mdx/vite";

const ignorePatterns = [
  "**/dist/**",
  "**/dist-ssr/**",
  "**/.output/**",
  "**/.nitro/**",
  "**/.tanstack/**",
  "**/.wrangler/**",
  "**/.source/**",
  "**/.vinxi/**",
  "**/coverage/**",
  "**/*.tsbuildinfo",
  "**/routeTree.gen.ts",
  "**/__unconfig*",
  "**/todos.json",
];

const config = defineConfig({
  resolve: {
    tsconfigPaths: true,
  },
  plugins: lazyPlugins(() => [
    devtools(),
    fumadocsMdx(),
    nitro({ rollupConfig: { external: [/^@sentry\//] } }),
    tailwindcss(),
    tanstackStart({
      prerender: {
        enabled: true,
      },
    }),
    viteReact(),
    babel({ presets: [reactCompilerPreset()] }),
  ]),
  fmt: {
    proseWrap: "always",
    ignorePatterns,
  },
  lint: {
    jsPlugins: [{ name: "vite-plus", specifier: "vite-plus/oxlint-plugin" }],
    rules: { "vite-plus/prefer-vite-plus-imports": "error" },
    options: { typeAware: true, typeCheck: true },
    ignorePatterns,
  },
});

export default config;
