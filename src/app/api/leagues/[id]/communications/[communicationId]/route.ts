import { NextResponse } from "next/server";

import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { createClient } from "@/lib/supabase/server";

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string; communicationId: string }> },
) {
  const { communicationId } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);

  const { error } = await supabase.rpc("delete_league_communication", {
    target_communication: communicationId,
  });
  if (error) return apiError(leagueRpcMessage(error.message), 403);
  return NextResponse.json({ ok: true });
}
