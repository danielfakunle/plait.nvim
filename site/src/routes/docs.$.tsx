import { createFileRoute, notFound } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import browserCollections from "collections/browser";
import { useFumadocsLoader } from "fumadocs-core/source/client";
import { Suspense } from "react";
import { useMDXComponents } from "@/components/mdx";
import { type Root } from "fumadocs-core/page-tree";
import { DocsSidebar } from "#/components/docs/sidebar.tsx";
import {
  DocsLayout,
  DocsPage,
  DocsPageContent,
  DocsPageFooter,
  DocsPageHeader,
} from "#/components/docs/page.tsx";
import { DocsTOC } from "#/components/docs/toc.tsx";

type DocsContentProps = {
  tree: Root;
};

export const Route = createFileRoute("/docs/$")({
  component: RouteComponent,
  params: {
    parse: (params) => {
      if (params._splat?.endsWith(".md")) return false;
      return params;
    },
  },
  loader: async ({ params }) => {
    const slugs = params._splat?.split("/") ?? [];
    const data = await serverLoader({ data: slugs });
    await clientLoader.preload(data.path);
    return data;
  },
});

export const serverLoader = createServerFn({
  method: "GET",
})
  .validator((slugs: string[]) => slugs)
  .handler(async ({ data: slugs }) => {
    const { source } = await import("#/lib/source.ts");
    const page = source.getPage(slugs);
    if (!page) throw notFound();

    return {
      path: page.path,
      pageTree: await source.serializePageTree(source.getPageTree()),
    };
  });

const clientLoader = browserCollections.docs.createClientLoader({
  component(
    { toc, frontmatter, default: MDX },
    // you can define props for the component
    { tree }: DocsContentProps,
  ) {
    return (
      <DocsLayout toc={toc}>
        <DocsSidebar
          className="h-(--page-height) sticky top-(--navbar-height) hidden sm:block"
          tree={tree}
        />
        <DocsPage>
          <DocsPageHeader title={frontmatter.title} description={frontmatter.description} />
          <DocsPageContent>
            <MDX components={useMDXComponents()} />
          </DocsPageContent>
          <DocsPageFooter tree={tree} />
        </DocsPage>
        <DocsTOC
          className="h-(--page-height) sticky top-(--navbar-height) hidden lg:flex"
          toc={toc}
        />
      </DocsLayout>
    );
  },
});

function RouteComponent() {
  const data = useFumadocsLoader(Route.useLoaderData());
  return <Suspense>{clientLoader.useContent(data.path, { tree: data.pageTree })}</Suspense>;
}
