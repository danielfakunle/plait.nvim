import { cn } from "#/lib/utils.ts";
import { Menu09Icon, Search01Icon } from "@hugeicons/core-free-icons";
import { Button, buttonVariants } from "./ui/button";
import { Kbd } from "./ui/kbd";
import { HugeiconsIcon } from "@hugeicons/react";
import { Link, useLocation } from "@tanstack/react-router";
import { getDocsSidebarGroups } from "#/lib/docs-sidebar.ts";
import type { Root } from "fumadocs-core/page-tree";
import { AnimatePresence, motion, stagger, type Variants } from "motion/react";
import { useState } from "react";
import { useMeasure } from "react-use";
import { ModeToggle } from "./mode-toggle";

type NavbarProps = {
  tree: Root;
  searchOpen: boolean;
  setSearchOpen: React.Dispatch<React.SetStateAction<boolean>>;
};

const menuVariants: Variants = {
  open: {
    opacity: 1,
    transition: {
      delayChildren: stagger(0.05),
    },
  },
  closed: {
    opacity: 0,
  },
};

const itemVariants: Variants = {
  open: {
    opacity: 1,
    y: 0,
    transition: {
      type: "spring",
      bounce: 0,
      duration: 0.6,
    },
  },
  closed: {
    opacity: 0,
    y: -4,
  },
};

export function Navbar({ tree, setSearchOpen }: NavbarProps) {
  const pathname = useLocation().pathname;
  const [open, setOpen] = useState(false);
  const [ref, { height }] = useMeasure<HTMLDivElement>();

  return (
    <>
      <motion.header
        animate={{
          height: open ? height : "var(--navbar-height)",
        }}
        transition={{
          type: "spring",
          bounce: 0,
          duration: 0.8,
        }}
        className="fixed inset-x-0 bg-background z-50"
      >
        <div ref={ref}>
          <div className="h-(--navbar-height) container container-padding-x mx-auto flex items-center justify-between">
            <Link to="/" className="heading-xs flex gap-1">
              <span>Plait</span>
            </Link>
            <div className="flex gap-2 items-center">
              <ModeToggle variant="ghost" />
              <Button
                onClick={() => setSearchOpen((prev) => !prev)}
                variant="outline"
                size="sm"
                className="pl-1 pr-0.75!"
              >
                <HugeiconsIcon icon={Search01Icon} />
                <Kbd data-icon="inline-end" className="">
                  ⌘K
                </Kbd>
              </Button>
              <NavLink className="hidden sm:flex" to="/docs/">
                Docs
              </NavLink>
              <Button
                className="sm:hidden"
                onClick={() => setOpen((prev) => !prev)}
                variant="ghost"
                size="icon"
              >
                <HugeiconsIcon icon={Menu09Icon} />
              </Button>
            </div>
          </div>
          <AnimatePresence>
            {open ? (
              <motion.div
                variants={menuVariants}
                initial="closed"
                animate="open"
                exit="closed"
                className="container container-padding-x mx-auto flex flex-col py-6 gap-8 h-[calc(100vh-(var(--navbar-height)))] overflow-y-auto"
              >
                <MobileMenuGroup>
                  <MobileMenuGroupLabel>Menu</MobileMenuGroupLabel>
                  <MobileMenuGroupItems>
                    <MobileMenuLink onClick={() => setOpen(false)} to="/docs/">
                      Docs
                    </MobileMenuLink>
                  </MobileMenuGroupItems>
                </MobileMenuGroup>
                {getDocsSidebarGroups(tree).map((group, index) => (
                  <MobileMenuGroup key={index}>
                    {group.label ? (
                      <MobileMenuGroupLabel>{group.label}</MobileMenuGroupLabel>
                    ) : null}
                    <MobileMenuGroupItems>
                      {group.pages.map((page) => (
                        <MobileMenuLink
                          onClick={() => setOpen(false)}
                          data-active={pathname === page.url ? true : undefined}
                          key={page.url}
                          to={page.url}
                        >
                          {page.name}
                        </MobileMenuLink>
                      ))}
                    </MobileMenuGroupItems>
                  </MobileMenuGroup>
                ))}
              </motion.div>
            ) : null}
          </AnimatePresence>
        </div>
      </motion.header>
      <div className="h-(--navbar-height)" />
    </>
  );
}

function NavLink({ className, ...props }: React.ComponentProps<typeof Link>) {
  return (
    <Link
      {...props}
      className={cn(
        buttonVariants({
          variant: "link",
          size: "xs",
          className: "text-foreground hover:text-primary hover:no-underline",
        }),
        className,
      )}
    />
  );
}

function MobileMenuGroup({ className, ...props }: React.ComponentProps<typeof motion.div>) {
  return (
    <motion.div
      variants={itemVariants}
      {...props}
      className={cn("flex flex-col gap-4", className)}
    />
  );
}

function MobileMenuGroupLabel({ className, ...props }: React.ComponentProps<"span">) {
  return <span {...props} className={cn("text-xs text-muted-foreground uppercase", className)} />;
}

function MobileMenuGroupItems({ className, ...props }: React.ComponentProps<"div">) {
  return <div {...props} className={cn("flex flex-col gap-3", className)} />;
}

function MobileMenuLink({ className, ...props }: React.ComponentProps<typeof Link>) {
  return (
    <Link
      {...props}
      className={cn(
        buttonVariants({
          variant: "link",
          className:
            "self-start px-0 text-2xl text-foreground hover:text-primary hover:no-underline",
        }),
        className,
      )}
    />
  );
}
