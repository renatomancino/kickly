import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const schema = z.object({
  match_created: z.boolean(), match_updates: z.boolean(), match_reminders: z.boolean(),
  waitlist: z.boolean(), mvp: z.boolean(), rating: z.boolean(), league_updates: z.boolean(),
});

export async function POST(request: Request) {
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ message: "Preferenze non valide." }, { status: 400 });
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });
  const { error } = await supabase.from("notification_preferences").upsert({ user_id: user.id, ...parsed.data }, { onConflict: "user_id" });
  return error ? NextResponse.json({ message: "Salvataggio non riuscito." }, { status: 400 }) : NextResponse.json({ ok: true });
}
