import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function POST() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });
  const { error } = await supabase.from("notifications").update({ read_at: new Date().toISOString() }).eq("user_id", user.id).is("read_at", null);
  return error ? NextResponse.json({ message: "Aggiornamento non riuscito." }, { status: 400 }) : NextResponse.json({ ok: true });
}
