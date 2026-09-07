import { ArrowDown01Icon, Copy01Icon, Tick01Icon } from "@hugeicons/core-free-icons";
import { ButtonGroup, ButtonGroupSeparator } from "../ui/button-group";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "../ui/dropdown-menu";
import { HugeiconsIcon } from "@hugeicons/react";
import { Button } from "../ui/button";
import { useCopyButton } from "#/hooks/use-copy-button.ts";
import { docsRoute, encodeMarkdownUrl } from "#/lib/shared.ts";
import { ChatGPT, Claude, Markdown, Scira } from "../icons";
import { useLocation } from "@tanstack/react-router";
import { useEffect, useState } from "react";

function getPromptUrl(baseUrl: string, url: string) {
  return `${baseUrl}?q=${encodeURIComponent(
    `I'm looking at this documentation: ${url}.
Help me understand how to use it. Be ready to explain concepts, give examples, or help debug based on it.`,
  )}`;
}

export function DocsCopyButton() {
  const { pathname } = useLocation();
  const [origin, setOrigin] = useState("");
  const pageUrl = pathname;
  const markdownUrl = encodeMarkdownUrl(
    pathname.slice(docsRoute.length).split("/").filter(Boolean),
  );
  const absolutePageUrl = origin ? `${origin}${pageUrl}` : pageUrl;
  const [copied, onCopy] = useCopyButton(async () => {
    const response = await fetch(markdownUrl, {
      headers: { Accept: "text/html" },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch markdown page: ${response.status}`);
    }

    await navigator.clipboard.writeText(await response.text());
  });

  useEffect(() => {
    setOrigin(window.location.origin);
  }, []);

  return (
    <ButtonGroup className="h-fit">
      <Button variant="secondary" size="sm" onClick={onCopy}>
        <HugeiconsIcon icon={copied ? Tick01Icon : Copy01Icon} />
        Copy page
      </Button>
      <ButtonGroupSeparator />
      <DropdownMenu>
        <DropdownMenuTrigger
          render={
            <Button size="icon-sm" variant="secondary">
              <HugeiconsIcon icon={ArrowDown01Icon} />
            </Button>
          }
        />
        <DropdownMenuContent align="end" className="w-fit">
          <DropdownMenuGroup>
            <DocsCopyMenuItem href={markdownUrl} label="View as Markdown" icon={<Markdown />} />
            <DocsCopyMenuItem
              href={getPromptUrl("https://chatgpt.com", absolutePageUrl)}
              label="Open in ChatGPT"
              icon={<ChatGPT />}
            />
            <DocsCopyMenuItem
              href={getPromptUrl("https://claude.ai/new", absolutePageUrl)}
              label="Open in Claude"
              icon={<Claude />}
            />
            <DocsCopyMenuItem
              href={getPromptUrl("https://scira.ai/", absolutePageUrl)}
              label="Open in Scira"
              icon={<Scira />}
            />
          </DropdownMenuGroup>
        </DropdownMenuContent>
      </DropdownMenu>
    </ButtonGroup>
  );
}

function DocsCopyMenuItem({
  href,
  icon,
  label,
}: {
  href: string;
  icon: React.ReactNode;
  label: string;
}) {
  return (
    <DropdownMenuItem
      render={
        <a href={href} target="_blank" rel="noreferrer">
          {icon}
          {label}
        </a>
      }
    />
  );
}
