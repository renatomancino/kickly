import { apiError, leagueRpcMessage } from "@/features/leagues/api-utils";
import { createClient } from "@/lib/supabase/server";

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);
  const { data, error } = await supabase.rpc("rotate_league_invite_code", {
    target_league: id,
  });
  if (error) return apiError(leagueRpcMessage(error.message), 403);
  return Response.json({ code: data });
}
