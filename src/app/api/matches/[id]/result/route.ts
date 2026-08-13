import { NextResponse } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { postGameSchema } from "@/features/matches/schema";
import { requireUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  await requireUser();
  const { id } = await params;
  const parsed = postGameSchema.safeParse(await request.json());
  if (!parsed.success) return matchApiError("Controlla squadre, risultato e statistiche.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("finalize_match", {
    target_match: id,
    team_a_players: parsed.data.team_a_players,
    team_b_players: parsed.data.team_b_players,
    score_a: parsed.data.score_a,
    score_b: parsed.data.score_b,
    player_totals: parsed.data.player_totals,
  });
  if (error) return matchApiError(matchRpcMessage(error.message), 400);
  return NextResponse.json({ ok: true });
}
