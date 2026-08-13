import { NextResponse } from "next/server";

import { matchApiError, matchRpcMessage } from "@/features/matches/api-utils";
import { matchReminderSchema } from "@/features/matches/schema";
import { createClient } from "@/lib/supabase/server";
import type { Json } from "@/types/database";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return matchApiError("Non autorizzato.", 401);

  const parsed = matchReminderSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return matchApiError(parsed.error.issues[0]?.message ?? "Dati non validi.");

  const { data, error } = await supabase.rpc("send_match_reminder", {
    target_match: id,
    reminder_body: parsed.data.body,
  });
  if (error) return matchApiError(matchRpcMessage(error.message), 403);
  const result = data as Json as { recipient_count?: number };
  return NextResponse.json({ recipientCount: Number(result.recipient_count ?? 0) }, { status: 201 });
}
