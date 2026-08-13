import { Shield } from "lucide-react";

import { cn } from "@/lib/utils";

export function LeagueLogo({
  url,
  name,
  className,
}: {
  url: string | null;
  name: string;
  className?: string;
}) {
  if (url) {
    return (
      <span
        aria-label={`Logo ${name}`}
        className={cn("block shrink-0 bg-cover bg-center", className)}
        role="img"
        style={{ backgroundImage: `url(${JSON.stringify(url).slice(1, -1)})` }}
      />
    );
  }
  return (
    <span
      aria-label={`Logo predefinito ${name}`}
      className={cn(
        "grid shrink-0 place-items-center bg-primary/12 text-primary",
        className,
      )}
      role="img"
    >
      <Shield className="size-1/2" />
    </span>
  );
}
