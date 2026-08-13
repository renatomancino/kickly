import { NextResponse, type NextRequest } from "next/server";

import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { inviteCodeSchema } from "@/features/leagues/schema";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);

  const parsed = inviteCodeSchema.safeParse(request.nextUrl.searchParams.get("code"));
  if (!parsed.success) return apiError("Codice invito non valido.");
  const { data, error } = await supabase.rpc("get_league_invite_preview", {
    invite: parsed.data,
  });
  if (error || !Array.isArray(data) || !data[0]) return apiError("Codice invito non valido.", 404);
  return NextResponse.json(data[0]);
}

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);

  const body = (await request.json()) as { code?: string };
  const parsed = inviteCodeSchema.safeParse(body.code);
  if (!parsed.success) return apiError("Codice invito non valido.");

  const { data, error } = await supabase.rpc("join_league_by_code", {
    invite: parsed.data,
  });
  if (error) return apiError(leagueRpcMessage(error.message));
  return NextResponse.json({ slug: data });
}
