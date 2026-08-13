import { NextResponse, type NextRequest } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { matchSchema } from "@/features/matches/schema";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);

  const body = await request.json().catch(() => null);
  const parsed = matchSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { message: "Controlla i campi inseriti.", errors: parsed.error.flatten().fieldErrors },
      { status: 400 },
    );
  }

  const input = parsed.data;
  const { data, error } = await supabase.rpc("create_match", {
    target_league: input.league_id,
    match_title: input.title,
    match_description: input.description ?? "",
    match_starts_at: input.starts_at,
    match_location_name: input.location_name,
    match_address: input.address ?? "",
    match_city: input.city,
    match_football_format: input.football_format,
    match_max_players: input.max_players,
    match_cost_total: input.cost_total,
    match_visibility: input.visibility,
  });
  if (error || !data) return matchApiError(matchRpcMessage(error?.message ?? "create_failed"));
  return NextResponse.json({ id: data }, { status: 201 });
}
