import type { NextRequest } from "next/server";

import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { memberActionSchema } from "@/features/leagues/schema";
import { createClient } from "@/lib/supabase/server";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; userId: string }> },
) {
  const { id, userId } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);
  const parsed = memberActionSchema.safeParse(await request.json());
  if (!parsed.success) return apiError("Azione non valida.");

  const calls = {
    promote: () =>
      supabase.rpc("set_league_member_role", {
        target_league: id,
        target_user: userId,
        target_role: "admin",
      }),
    demote: () =>
      supabase.rpc("set_league_member_role", {
        target_league: id,
        target_user: userId,
        target_role: "member",
      }),
    remove: () =>
      supabase.rpc("remove_league_member", {
        target_league: id,
        target_user: userId,
      }),
    transfer: () =>
      supabase.rpc("transfer_league_ownership", {
        target_league: id,
        target_user: userId,
      }),
  };
  const { error } = await calls[parsed.data.action]();
  if (error) return apiError(leagueRpcMessage(error.message), 403);
  return Response.json({ ok: true });
}
