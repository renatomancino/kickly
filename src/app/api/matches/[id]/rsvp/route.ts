import { NextResponse, type NextRequest } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { responseSchema } from "@/features/matches/schema";
import { createClient } from "@/lib/supabase/server";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);
  const parsed = responseSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return matchApiError("Risposta non valida.");
  const { data, error } = await supabase.rpc("set_match_response", {
    target_match: id,
    target_response: parsed.data.response,
  });
  if (error) return matchApiError(matchRpcMessage(error.message));
  const result = Array.isArray(data) ? data[0] : data;
  if (!result) return matchApiError("Risposta non salvata.");
  return NextResponse.json(result);
}
