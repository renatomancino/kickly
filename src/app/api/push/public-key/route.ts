import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });
  const { data, error } = await supabase.rpc("get_push_public_key");
  if (error || !data) return NextResponse.json({ message: "Push non ancora configurato." }, { status: 503 });
  return NextResponse.json({ key: data });
}
