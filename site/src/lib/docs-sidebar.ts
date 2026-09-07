import type { Item, Root } from "fumadocs-core/page-tree";
import type { ReactNode } from "react";

type DocsSidebarGroupData = {
  label?: ReactNode;
  pages: Item[];
};

export function getDocsSidebarGroups(tree: Root): DocsSidebarGroupData[] {
  const groups: DocsSidebarGroupData[] = [];
  let current: DocsSidebarGroupData | undefined;

  for (const node of tree.children) {
    if (node.type === "separator") {
      current = {
        label: node.name,
        pages: [],
      };
      groups.push(current);
      continue;
    }

    if (node.type === "page") {
      if (!current) {
        current = { pages: [] };
        groups.push(current);
      }

      current.pages.push(node);
    }
  }

  return groups;
}
