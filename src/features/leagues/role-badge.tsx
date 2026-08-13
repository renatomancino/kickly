import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

import type { LeagueRole } from "./types";

export function RoleBadge({ role, className }: { role: LeagueRole; className?: string }) {
  return (
    <Badge
      className={cn(
        role === "owner" && "border-primary/30 bg-primary/10 text-primary",
        role === "admin" && "border-white/15 bg-white/8 text-foreground",
        role === "member" && "text-muted-foreground",
        className,
      )}
      variant="outline"
    >
      {role.toUpperCase()}
    </Badge>
  );
}
