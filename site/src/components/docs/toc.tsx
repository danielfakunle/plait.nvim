import { ScrollProvider, TOCItem, type TOCItemType } from "fumadocs-core/toc";
import { useRef } from "react";
import { buttonVariants } from "../ui/button";
import { cn } from "#/lib/utils.ts";

export function DocsTOC({
  toc,
  className,
  ...props
}: Omit<React.ComponentProps<"nav">, "ref"> & {
  toc: TOCItemType[];
}) {
  const tocRef = useRef(null);
  return (
    <nav
      ref={tocRef}
      className={cn(
        "w-58 flex flex-col gap-2 px-2 py-6 overflow-y-auto scrollbar-none scroll-fade",
        className,
      )}
      {...props}
    >
      <ScrollProvider containerRef={tocRef}>
        {toc.length > 0 && (
          <p className="text-[0.625rem] tracking-widest leading-normal px-2 font-medium text-muted-foreground uppercase">
            On This Page
          </p>
        )}
        <div className="flex flex-col gap-1 w-full">
          {toc.map((item) => (
            <TOCItem
              data-depth={item.depth}
              key={item.url}
              className={cn(
                buttonVariants({
                  variant: "link",
                  size: "xs",
                  className:
                    "text-muted-foreground h-fit py-1 font-normal data-active:text-foreground data-active:font-medium data-[depth=3]:pl-4 data-[depth=4]:pl-6",
                }),
              )}
              href={item.url}
            >
              <span className="w-full self-start truncate">{item.title}</span>
            </TOCItem>
          ))}
        </div>
      </ScrollProvider>
    </nav>
  );
}
