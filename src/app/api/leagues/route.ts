import { randomUUID } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";

import { apiError } from "@/features/leagues/api-utils";
import { leagueSchema } from "@/features/leagues/schema";
import {
  hasInvalidLogo,
  logoExtension,
  makeLeagueSlug,
  validateLogo,
} from "@/features/leagues/server-utils";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
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
  if (!parsed.success) {
    return NextResponse.json(
      { message: "Controlla i campi inseriti.", errors: parsed.error.flatten().fieldErrors },
      { status: 400 },
    );
  }

  const { data: league, error } = await supabase
    .rpc("create_league", {
      league_name: parsed.data.name,
      league_slug: makeLeagueSlug(parsed.data.name),
      league_description: parsed.data.description || "",
      league_city: parsed.data.city,
      league_country: parsed.data.country,
      league_visibility: parsed.data.visibility,
      league_format: parsed.data.football_format,
      league_max_members: parsed.data.max_members,
    });

  const created = Array.isArray(league) ? (league[0] as { id: string; slug: string } | undefined) : undefined;
  if (error || !created) return apiError("Creazione della lega non riuscita.");

  if (validateLogo(logo)) {
    const path = `${created.id}/${randomUUID()}.${logoExtension(logo)}`;
    const { error: uploadError } = await supabase.storage
      .from("league-logos")
      .upload(path, logo, { contentType: logo.type, cacheControl: "31536000" });
    if (uploadError) {
      await supabase.from("leagues").delete().eq("id", created.id);
      return apiError("Caricamento del logo non riuscito.");
    }
    const logoUrl = supabase.storage.from("league-logos").getPublicUrl(path).data.publicUrl;
    const { error: logoUpdateError } = await supabase
      .from("leagues")
      .update({ logo_url: logoUrl })
      .eq("id", created.id);
    if (logoUpdateError) return apiError("Lega creata, ma il logo non è stato salvato.");
  }

  return NextResponse.json({ slug: created.slug }, { status: 201 });
}
