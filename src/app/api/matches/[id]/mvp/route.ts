import { NextResponse } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { mvpVoteSchema } from "@/features/matches/schema";
import { requireUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  await requireUser();
  const { id } = await params;
  const parsed = mvpVoteSchema.safeParse(await request.json());
  if (!parsed.success) return matchApiError("Giocatore non valido.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("cast_mvp_vote", { target_match: id, target_player: parsed.data.player_id });
  if (error) return matchApiError(matchRpcMessage(error.message));
  return NextResponse.json({ ok: true });
}

export async function PUT(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  await requireUser();
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("finalize_match_mvp", { target_match: id });
  if (error) return matchApiError(matchRpcMessage(error.message));
  return NextResponse.json({ winnerId: data });
}
