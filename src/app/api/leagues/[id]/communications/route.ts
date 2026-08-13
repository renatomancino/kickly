import { NextResponse } from "next/server";

import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { leagueCommunicationSchema } from "@/features/leagues/schema";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);

  const parsed = leagueCommunicationSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return apiError(parsed.error.issues[0]?.message ?? "Dati non validi.");

  const { data, error } = await supabase.rpc("publish_league_communication", {
    target_league: id,
    communication_title: parsed.data.title,
    communication_body: parsed.data.body,
    communication_pinned: parsed.data.pinned,
  });
  if (error) return apiError(leagueRpcMessage(error.message), 403);
  return NextResponse.json({ id: data }, { status: 201 });
}
