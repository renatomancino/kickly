import { randomUUID } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";

import { apiError } from "@/features/leagues/api-utils";
import { deleteLeagueSchema, leagueSchema } from "@/features/leagues/schema";
import {
  hasInvalidLogo,
  logoExtension,
  storagePathFromPublicUrl,
  validateLogo,
} from "@/features/leagues/server-utils";
import { createClient } from "@/lib/supabase/server";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);

  const formData = await request.formData();
  const logo = formData.get("logo");
  if (hasInvalidLogo(logo)) {
    return apiError("Il logo deve essere JPG, PNG o WebP e pesare meno di 5 MB.");
  }
  const parsed = leagueSchema.safeParse({
    name: formData.get("name"),
    description: formData.get("description") ?? "",
    city: formData.get("city"),
    country: formData.get("country") || "IT",
    visibility: formData.get("visibility"),
    football_format: formData.get("football_format"),
    max_members: Number(formData.get("max_members") || 30),
  });
  if (!parsed.success) return apiError("Controlla i campi inseriti.");

  const { data: membership } = await supabase
    .from("league_members")
    .select("role")
    .eq("league_id", id)
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();
  const role = (membership as { role?: string } | null)?.role;
  if (role !== "owner" && role !== "admin") return apiError("Non hai i permessi.", 403);

  const { count: activeMembers } = await supabase
    .from("league_members")
    .select("id", { count: "exact", head: true })
    .eq("league_id", id)
    .eq("status", "active");
  if ((activeMembers ?? 0) > parsed.data.max_members) {
    return apiError(`La lega ha già ${activeMembers} membri attivi.`);
  }

  const { data: existing } = await supabase
    .from("leagues")
    .select("logo_url")
    .eq("id", id)
    .single();

  let logoUrl = (existing as { logo_url?: string | null } | null)?.logo_url ?? null;
  if (validateLogo(logo)) {
    const path = `${id}/${randomUUID()}.${logoExtension(logo)}`;
    const { error: uploadError } = await supabase.storage
      .from("league-logos")
      .upload(path, logo, { contentType: logo.type, cacheControl: "31536000" });
    if (uploadError) return apiError("Caricamento del logo non riuscito.");
    const previousPath = storagePathFromPublicUrl(logoUrl);
    logoUrl = supabase.storage.from("league-logos").getPublicUrl(path).data.publicUrl;
    if (previousPath) await supabase.storage.from("league-logos").remove([previousPath]);
  }

  const { error } = await supabase
    .from("leagues")
    .update({
      name: parsed.data.name,
      description: parsed.data.description || null,
      city: parsed.data.city,
      country: parsed.data.country,
      visibility: parsed.data.visibility,
      football_format: parsed.data.football_format,
      max_members: parsed.data.max_members,
      logo_url: logoUrl,
    })
    .eq("id", id);
  if (error) return apiError("Aggiornamento non riuscito.");
  return NextResponse.json({ ok: true, logoUrl });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiError("Non autorizzato.", 401);
  const parsed = deleteLeagueSchema.safeParse(await request.json());
  if (!parsed.success) return apiError("Conferma non valida.");

  const { data: league } = await supabase
    .from("leagues")
    .select("name, owner_id, logo_url")
    .eq("id", id)
    .maybeSingle();
  const row = league as { name: string; owner_id: string; logo_url: string | null } | null;
  if (!row || row.owner_id !== user.id) return apiError("Azione riservata all’owner.", 403);
  if (parsed.data.confirmation !== row.name) return apiError("Il nome della lega non corrisponde.");

  const logoPath = storagePathFromPublicUrl(row.logo_url);
  if (logoPath) await supabase.storage.from("league-logos").remove([logoPath]);
  const { error } = await supabase.from("leagues").delete().eq("id", id);
  if (error) return apiError("Eliminazione non riuscita.");
  return NextResponse.json({ ok: true });
}
