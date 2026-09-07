import { loader } from "fumadocs-core/source";
import { docs } from "collections/server";
import { docsRoute } from "./shared";

export const source = loader({
  source: docs.toFumadocsSource(),
  baseUrl: docsRoute,
});

export async function getLLMText(page: (typeof source)["$inferPage"]) {
  const processed = await page.data.getText("processed");

  return `# ${page.data.title} (${page.url})

${processed}`;
}
