import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const subscriptionSchema = z.object({ endpoint: z.string().url().max(2048), keys: z.object({ p256dh: z.string().min(20).max(255), auth: z.string().min(8).max(255) }), deviceName: z.string().max(80).optional() });

export async function POST(request: Request) {
  const parsed = subscriptionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ message: "Sottoscrizione non valida." }, { status: 400 });
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });
  const { error } = await supabase.rpc("register_push_subscription", { subscription_endpoint: parsed.data.endpoint, subscription_p256dh: parsed.data.keys.p256dh, subscription_auth: parsed.data.keys.auth, subscription_user_agent: request.headers.get("user-agent"), subscription_device_name: parsed.data.deviceName ?? null });
  return error ? NextResponse.json({ message: "Attivazione push non riuscita." }, { status: 400 }) : NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  const parsed = z.object({ endpoint: z.string().url().max(2048) }).safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ message: "Sottoscrizione non valida." }, { status: 400 });
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });
  const { error } = await supabase.rpc("remove_push_subscription", { subscription_endpoint: parsed.data.endpoint });
  return error ? NextResponse.json({ message: "Disattivazione non riuscita." }, { status: 400 }) : NextResponse.json({ ok: true });
}
