import { NextResponse } from "next/server";
import { z } from "zod";
import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { createClient } from "@/lib/supabase/server";

const schema = z.object({ leagueId: z.string().uuid() });

export async function POST(request: Request) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return apiError("Lega non valida.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);
  const { data, error } = await supabase.rpc("join_public_league", { target_league: parsed.data.leagueId });
  if (error) return apiError(leagueRpcMessage(error.message));
  return NextResponse.json({ slug: data });
}
