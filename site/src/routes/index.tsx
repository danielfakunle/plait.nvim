import { buttonVariants } from "#/components/ui/button.tsx";
import { cn } from "#/lib/utils.ts";
import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/")({ component: Home });

function Home() {
  return (
    <main className="container container-padding-x mx-auto py-24">
      <h1 className="mt-3 heading-md">Title.</h1>
      <p className="mt-4 text-base max-w-2xl text-muted-foreground">Subtitle</p>
      <Link
        className={cn(buttonVariants({ variant: "link", size: "lg", className: "px-0 mt-4" }))}
        to="/docs/$"
        params={{
          _splat: "",
        }}
      >
        Read the documentation
      </Link>
    </main>
  );
}
