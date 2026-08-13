import { NextResponse, type NextRequest } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { lineupActionSchema } from "@/features/matches/schema";
import type { MatchLineup } from "@/features/matches/types";
import { createClient } from "@/lib/supabase/server";
import type { Json } from "@/types/database";

interface SnapshotTeam {
  team_number: 1 | 2;
  formation: string;
  captain_user_id: string | null;
}

interface SnapshotPlayer {
  user_id: string;
  team_number: 1 | 2;
  slot_key: string;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);

  const parsed = lineupActionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return matchApiError("Azione formazione non valida.");

  const input = parsed.data;
  if (input.action === "claim") {
    const { data, error } = await supabase.rpc("set_match_lineup_slot", {
      target_match: id,
      target_team: input.team_number,
      target_slot: input.slot_key,
      wants_captain: input.wants_captain,
    });
    if (error) return matchApiError(matchRpcMessage(error.message));
    return NextResponse.json({ lineup: normalizeSnapshot(data) });
  }

  if (input.action === "formation") {
    const { data, error } = await supabase.rpc("set_match_lineup_formation", {
      target_match: id,
      target_team: input.team_number,
      target_formation: input.formation,
    });
    if (error) return matchApiError(matchRpcMessage(error.message));
    return NextResponse.json({ lineup: normalizeSnapshot(data) });
  }

  const { data, error } = await supabase.rpc("leave_match_lineup", { target_match: id });
  if (error) return matchApiError(matchRpcMessage(error.message));
  return NextResponse.json({ lineup: normalizeSnapshot(data) });
}

function normalizeSnapshot(value: Json): MatchLineup {
  const snapshot = value as unknown as { teams?: SnapshotTeam[]; players?: SnapshotPlayer[] };
  return {
    teams: (snapshot.teams ?? []).map((team) => ({
      teamNumber: team.team_number,
      formation: team.formation,
      captainUserId: team.captain_user_id,
    })),
    players: (snapshot.players ?? []).map((player) => ({
      userId: player.user_id,
      teamNumber: player.team_number,
      slotKey: player.slot_key,
    })),
  };
}
