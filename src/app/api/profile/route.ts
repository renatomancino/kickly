import { NextResponse, type NextRequest } from "next/server";

import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { profileSchema } from "@/features/profile/schema";

const maxAvatarBytes = 5 * 1024 * 1024;
const avatarTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

export async function POST(request: NextRequest) {
  if (!hasSupabaseEnv()) {
    return NextResponse.json(
      { message: "Configura Supabase prima di salvare il profilo." },
      { status: 503 },
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ message: "Non autorizzato." }, { status: 401 });

  const formData = await request.formData();
  const parsed = profileSchema.safeParse({
    first_name: formData.get("first_name"),
    last_name: formData.get("last_name"),
    username: formData.get("username"),
    birth_date: formData.get("birth_date") || undefined,
    city: formData.get("city"),
    primary_position: formData.get("primary_position"),
    secondary_position: formData.get("secondary_position") || "",
    preferred_foot: formData.get("preferred_foot"),
    skill_level: formData.get("skill_level"),
    profile_public: formData.get("profile_public") !== "false",
  });

  if (!parsed.success) {
    return NextResponse.json(
      { message: "Controlla i campi evidenziati.", errors: parsed.error.flatten().fieldErrors },
      { status: 400 },
    );
  }

  let avatarPath: string | undefined;
  const avatar = formData.get("avatar");
  if (avatar instanceof File && avatar.size > 0) {
    if (avatar.size > maxAvatarBytes || !avatarTypes.has(avatar.type)) {
      return NextResponse.json(
        { message: "La foto deve essere JPG, PNG o WebP e pesare meno di 5 MB." },
        { status: 400 },
      );
    }

    const extension = avatar.type.split("/")[1].replace("jpeg", "jpg");
    avatarPath = `${user.id}/avatar.${extension}`;
    const { error: uploadError } = await supabase.storage
      .from("avatars")
      .upload(avatarPath, avatar, {
        cacheControl: "3600",
        contentType: avatar.type,
        upsert: true,
      });
    if (uploadError) {
      return NextResponse.json({ message: "Caricamento foto non riuscito." }, { status: 400 });
    }
  }

  const payload = {
    id: user.id,
    ...parsed.data,
    birth_date: parsed.data.birth_date || null,
    secondary_position: parsed.data.secondary_position || null,
    onboarding_completed: true,
    ...(avatarPath ? { avatar_path: avatarPath } : {}),
  };

  const { error } = await supabase.from("profiles").upsert(payload, { onConflict: "id" });
  if (error?.code === "23505") {
    return NextResponse.json({ message: "Questo username è già stato scelto." }, { status: 409 });
  }
  if (error) {
    return NextResponse.json({ message: "Salvataggio non riuscito. Riprova." }, { status: 400 });
  }

  return NextResponse.json({ ok: true });
}
