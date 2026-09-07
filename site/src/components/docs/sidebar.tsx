import { cn } from "#/lib/utils.ts";
import { Link, useLocation } from "@tanstack/react-router";
import { buttonVariants } from "../ui/button";
import type { Root } from "fumadocs-core/page-tree";
import { getDocsSidebarGroups } from "#/lib/docs-sidebar.ts";

export function DocsSidebar({
  tree,
  className,
  ...props
}: React.ComponentProps<typeof DocsSidebarRoot> & { tree: Root }) {
  const pathname = useLocation().pathname;
  return (
    <DocsSidebarRoot className={className} {...props}>
      {getDocsSidebarGroups(tree).map((group, index) => (
        <DocsSidebarGroup key={index}>
          {group.label ? <DocsSidebarGroupLabel>{group.label}</DocsSidebarGroupLabel> : null}
          <DocsSidebarGroupContent>
            {group.pages.map((page) => (
              <DocsSidebarLink
                data-active={pathname === page.url ? true : undefined}
                key={page.url}
                to={page.url}
              >
                {page.name}
              </DocsSidebarLink>
            ))}
          </DocsSidebarGroupContent>
        </DocsSidebarGroup>
      ))}
    </DocsSidebarRoot>
  );
}

export function DocsSidebarRoot({ className, ...props }: React.ComponentProps<"aside">) {
  return (
    <aside
      className={cn("h-full w-58 py-6 overflow-y-auto scrollbar-none scroll-fade", className)}
      {...props}
    />
  );
}

export function DocsSidebarGroup({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col p-2 gap-2", className)} {...props} />;
}

export function DocsSidebarGroupLabel({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span
      className={cn(
        "text-[0.625rem] tracking-widest leading-normal px-2 uppercase text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}

export function DocsSidebarGroupContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col gap-1", className)} {...props} />;
}

export function DocsSidebarLink({
  className,
  children,
  ...props
}: Omit<React.ComponentProps<typeof Link>, "children"> & { children: React.ReactNode }) {
  return (
    <Link
      className={cn(
        buttonVariants({
          variant: "link",
          size: "xs",
          className:
            "self-start w-full px-2 text-foreground hover:text-primary hover:no-underline data-active:text-primary",
        }),
        className,
      )}
      {...props}
    >
      <span className="w-full truncate">{children}</span>
    </Link>
  );
}
