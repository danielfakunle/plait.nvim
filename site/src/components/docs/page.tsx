import { cn } from "#/lib/utils.ts";
import { Link, useLocation } from "@tanstack/react-router";
import { DocsCopyButton } from "./copy-button";
import { findNeighbour, type Root } from "fumadocs-core/page-tree";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, ArrowRight01Icon } from "@hugeicons/core-free-icons";
import { buttonVariants } from "../ui/button";
import { AnchorProvider, type TOCItemType } from "fumadocs-core/toc";

export function DocsLayout({
  className,
  toc,
  ...props
}: React.ComponentProps<"section"> & { toc: TOCItemType[] }) {
  return (
    <AnchorProvider toc={toc}>
      <section
        className={cn(
          "container container-padding-x sm:px-2.5 sm:pr-6 lg:pr-4 mx-auto flex justify-between gap-6",
          className,
        )}
        {...props}
      />
    </AnchorProvider>
  );
}

export function DocsPage({ className, ...props }: React.ComponentProps<"article">) {
  return (
    <article
      className={cn("flex-1 flex flex-col min-w-0 max-w-[37em] pt-6 pb-18 h-fit", className)}
      {...props}
    />
  );
}

export function DocsPageHeader({
  className,
  ...props
}: React.ComponentProps<"div"> & {
  title: string;
  description?: string;
}) {
  const { title, description } = props;
  return (
    <div className={cn("flex flex-col gap-2 mb-2", className)} {...props}>
      <div className="flex gap-2 items-center">
        <h1 className="text-2xl flex-1 font-semibold">
          <span className="truncate">{title} </span>
        </h1>
        <DocsCopyButton />
      </div>
      <p className="text-muted-foreground text-base">{description}</p>
    </div>
  );
}

export function DocsPageContent({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={cn("typeset typeset-docs mt-4 [&>table]:min-w-full", className)} {...props} />
  );
}

export function DocsPageFooter({
  className,
  tree,
  ...props
}: React.ComponentProps<"div"> & { tree: Root }) {
  const pathname = useLocation().pathname;
  const { previous, next } = findNeighbour(tree, pathname);
  return (
    <div className={cn("flex gap-2 items-center justify-between mt-12", className)} {...props}>
      {previous ? (
        <Link
          to={previous.url}
          className={buttonVariants({ variant: "secondary", className: "min-w-0" })}
        >
          <HugeiconsIcon icon={ArrowLeft01Icon} />
          <span className="truncate">{previous.name}</span>
        </Link>
      ) : (
        <div />
      )}
      {next ? (
        <Link
          to={next.url}
          className={buttonVariants({ variant: "secondary", size: "sm", className: "min-w-0" })}
        >
          <span className="truncate">{next.name}</span>
          <HugeiconsIcon icon={ArrowRight01Icon} />
        </Link>
      ) : null}
    </div>
  );
}
