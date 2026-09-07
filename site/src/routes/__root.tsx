import { HeadContent, Scripts, createRootRoute } from "@tanstack/react-router";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";
import { TanStackDevtools } from "@tanstack/react-devtools";

import appCss from "../styles/index.css?url";
import { ThemeProvider } from "#/components/theme-provider.tsx";
import { TanstackProvider as FumadocsProvider } from "fumadocs-core/framework/tanstack";
import { useFumadocsLoader } from "fumadocs-core/source/client";
import { DocsSearch } from "#/components/docs/search.tsx";
import { Navbar } from "#/components/navbar.tsx";
import { createServerFn } from "@tanstack/react-start";
import { useState } from "react";

const getRootData = createServerFn({ method: "GET" }).handler(async () => {
  const { source } = await import("#/lib/source.ts");

  return {
    pageTree: await source.serializePageTree(source.getPageTree()),
  };
});

export const Route = createRootRoute({
  loader: () => getRootData(),
  head: () => ({
    meta: [
      {
        charSet: "utf-8",
      },
      {
        name: "viewport",
        content: "width=device-width, initial-scale=1",
      },
      {
        title: "Fumadocs on TanStack Start",
      },
    ],
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
    ],
  }),
  shellComponent: RootDocument,
});

function RootDocument({ children }: { children: React.ReactNode }) {
  const { pageTree } = useFumadocsLoader(Route.useLoaderData());
  const [searchOpen, setSearchOpen] = useState(false);
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <HeadContent />
      </head>
      <body
        className="min-h-screen"
        style={
          {
            "--navbar-height": "3.25rem",
            "--page-height": "calc(100vh - var(--navbar-height))",
          } as React.CSSProperties
        }
      >
        <FumadocsProvider>
          <ThemeProvider defaultTheme="system" storageKey="theme">
            <Navbar searchOpen={searchOpen} setSearchOpen={setSearchOpen} tree={pageTree} />
            {children}
            <DocsSearch open={searchOpen} setOpen={setSearchOpen} />
          </ThemeProvider>
        </FumadocsProvider>
        <TanStackDevtools
          config={{
            position: "bottom-right",
          }}
          plugins={[
            {
              name: "Tanstack Router",
              render: <TanStackRouterDevtoolsPanel />,
            },
          ]}
        />
        <Scripts />
      </body>
    </html>
  );
}
