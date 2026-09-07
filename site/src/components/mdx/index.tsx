import type { MDXComponents } from "mdx/types";
import { cn } from "#/lib/utils.ts";
import Link from "fumadocs-core/link";
import { Image } from "@unpic/react";
import {
  CodeBlock,
  CodeBlockTab,
  CodeBlockTabs,
  CodeBlockTabsList,
  CodeBlockTabsTrigger,
  Pre,
} from "./code-block";
import { Step, Steps } from "./steps";

export const mdxComponents: MDXComponents = {
  a: ({ className, ...props }: React.ComponentProps<"a">) => (
    <Link className={cn("underline underline-offset-4", className)} {...props} />
  ),
  img: ({ src, className, width, height, alt, ...props }: React.ComponentProps<"img">) => (
    <Image
      className={cn(className)}
      src={(src as string) || ""}
      width={Number(width)}
      height={Number(height)}
      alt={alt || ""}
      {...props}
    />
  ),
  CodeBlockTab,
  CodeBlockTabs,
  CodeBlockTabsList,
  CodeBlockTabsTrigger,
  pre: ({ children, ...props }: React.ComponentProps<"pre">) => (
    <CodeBlock {...props}>
      <Pre>{children}</Pre>
    </CodeBlock>
  ),
  Steps,
  Step,
};

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...mdxComponents,
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
