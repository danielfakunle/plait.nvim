import { defineDocs, defineConfig } from "fumadocs-mdx/config";
import { remarkSteps } from "fumadocs-core/mdx-plugins/remark-steps";

export const docs = defineDocs({
  dir: "content",
  docs: {
    async: true,
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
});

export default defineConfig({
  mdxOptions: {
    remarkPlugins: [remarkSteps],
  },
});
