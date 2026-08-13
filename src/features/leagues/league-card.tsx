import Link from "next/link";
import { ChevronRight, MapPin, UsersRound } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";

import { LeagueLogo } from "./league-logo";
import { RoleBadge } from "./role-badge";
import type { LeagueSummary } from "./types";

export function LeagueCard({ league }: { league: LeagueSummary }) {
  return (
    <Link className="group block" href={`/leagues/${league.slug}`}>
      <Card className="h-full transition-all duration-200 group-hover:-translate-y-0.5 group-hover:border-primary/25 group-hover:bg-card/85">
        <CardContent className="flex items-center gap-4">
          <LeagueLogo className="size-14 rounded-2xl" name={league.name} url={league.logoUrl} />
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h2 className="truncate font-bold">{league.name}</h2>
              <RoleBadge className="hidden sm:inline-flex" role={league.currentUserRole} />
            </div>
            <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
              <span className="flex items-center gap-1"><MapPin className="size-3" />{league.city}</span>
              <span className="flex items-center gap-1"><UsersRound className="size-3" />{league.memberCount}/{league.maxMembers}</span>
              <Badge className="h-5 px-1.5 text-[10px]" variant="secondary">{league.footballFormat.replace("v", " vs ")}</Badge>
            </div>
          </div>
          <ChevronRight className="size-5 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:text-primary" />
        </CardContent>
      </Card>
    </Link>
  );
}
