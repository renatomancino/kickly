"use client";

import { startTransition, useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

interface RealtimeRow {
  match_id?: string;
}

export function LeagueRealtimeSync({
  leagueId,
  matchIds,
}: {
  leagueId: string;
  matchIds: string[];
}) {
  const router = useRouter();
  const matchIdsKey = matchIds.join(",");

  useEffect(() => {
    const supabase = createClient();
    const visibleMatchIds = new Set(matchIdsKey ? matchIdsKey.split(",") : []);
    let refreshTimer: ReturnType<typeof setTimeout> | undefined;

    const refresh = () => {
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(() => {
        startTransition(() => router.refresh());
      }, 180);
    };

    const refreshParticipantChange = (payload: { new: RealtimeRow; old: RealtimeRow }) => {
      const matchId = payload.new.match_id ?? payload.old.match_id;
      if (!matchId || visibleMatchIds.has(matchId)) refresh();
    };

    const channel = supabase
      .channel(`league-sync:${leagueId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "matches", filter: `league_id=eq.${leagueId}` },
        refresh,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "league_members", filter: `league_id=eq.${leagueId}` },
        refresh,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "player_stats", filter: `league_id=eq.${leagueId}` },
        refresh,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "league_communications", filter: `league_id=eq.${leagueId}` },
        refresh,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "match_participants" },
        refreshParticipantChange,
      )
      .subscribe();

    return () => {
      clearTimeout(refreshTimer);
      void supabase.removeChannel(channel);
    };
  }, [leagueId, matchIdsKey, router]);

  return null;
}
