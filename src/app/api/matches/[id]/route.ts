import { NextResponse, type NextRequest } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { adminStateSchema, matchSchema } from "@/features/matches/schema";
import { createClient } from "@/lib/supabase/server";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);
  const parsed = matchSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return matchApiError("Controlla i campi inseriti.");
  const input = parsed.data;
  const { error } = await supabase.rpc("update_match_details", {
    target_match: id,
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
  if (error) return matchApiError(matchRpcMessage(error.message));
  return NextResponse.json({ ok: true });
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);
  const parsed = adminStateSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return matchApiError("Azione non valida.");
  const { data, error } = await supabase.rpc("set_match_admin_state", {
    target_match: id,
    target_action: parsed.data.action,
  });
  if (error) return matchApiError(matchRpcMessage(error.message));
  return NextResponse.json({ state: Array.isArray(data) ? data[0] : data });
}
