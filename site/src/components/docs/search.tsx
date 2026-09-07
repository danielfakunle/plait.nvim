import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { useNavigate } from "@tanstack/react-router";
import { useHotkey } from "@tanstack/react-hotkeys";
import { useDocsSearch } from "fumadocs-core/search/client";
import { fetchClient } from "fumadocs-core/search/client/fetch";
import type { SortedResult } from "fumadocs-core/search";
import { Fragment } from "react";

type DocsSearchProps = {
  open: boolean;
  setOpen: React.Dispatch<React.SetStateAction<boolean>>;
};

export function DocsSearch({ open, setOpen }: DocsSearchProps) {
  const navigate = useNavigate();
  const { search, setSearch, query } = useDocsSearch({
    client: fetchClient({ api: "/api/search" }),
  });

  useHotkey("Mod+K", () => {
    setOpen((prev) => !prev);
  });

  function onSelect(result: SortedResult) {
    setOpen(false);
    setSearch("");
    void navigate({ to: result.url });
  }

  const results = query.data !== "empty" ? query.data : null;

  return (
    <CommandDialog
      open={open}
      onOpenChange={setOpen}
      title="Search Documentation"
      description="Search documentation pages and sections."
    >
      <Command shouldFilter={false}>
        <CommandInput
          value={search}
          onValueChange={setSearch}
          placeholder="Search documentation..."
        />
        <CommandList>
          {query.error ? <CommandEmpty>Failed to search documentation.</CommandEmpty> : null}
          {query.isLoading ? <CommandEmpty>Searching documentation...</CommandEmpty> : null}
          {!query.error && !query.isLoading && search.length === 0 ? (
            <CommandEmpty>Start typing to search documentation.</CommandEmpty>
          ) : null}
          {!query.error && !query.isLoading && search.length > 0 && results?.length === 0 ? (
            <CommandEmpty>No results found.</CommandEmpty>
          ) : null}
          {results && results.length > 0 ? (
            <CommandGroup heading="Documentation">
              {results.map((result) => (
                <CommandItem key={result.id} value={result.id} onSelect={() => onSelect(result)}>
                  <div className="flex min-w-0 flex-col gap-0.5">
                    {result.breadcrumbs ? (
                      <p className="truncate text-muted-foreground text-[0.625rem]">
                        {result.breadcrumbs.join(" / ")}
                      </p>
                    ) : null}
                    <p className="line-clamp-2 font-medium">
                      <HighlightedText text={result.content} />
                    </p>
                    <p className="truncate text-muted-foreground text-[0.625rem]">{result.url}</p>
                  </div>
                </CommandItem>
              ))}
            </CommandGroup>
          ) : null}
        </CommandList>
      </Command>
    </CommandDialog>
  );
}

function HighlightedText({ text }: { text: string }) {
  const parts = text.split(/(<mark>|<\/mark>)/g);
  let highlighted = false;

  return parts.map((part, index) => {
    if (part === "<mark>") {
      highlighted = true;
      return null;
    }

    if (part === "</mark>") {
      highlighted = false;
      return null;
    }

    if (part.length === 0) return null;

    return highlighted ? (
      <mark key={index} className="rounded-sm bg-primary/15 px-0.5 text-primary">
        {part}
      </mark>
    ) : (
      <Fragment key={index}>{part}</Fragment>
    );
  });
}
