import type { Metadata } from "next";

import { BrandMark } from "@/components/brand-mark";
import { ProfileForm } from "@/features/profile/profile-form";
import { getCurrentUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import type { ProfileRow } from "@/types/database";

export const metadata: Metadata = { title: "Completa il profilo" };

export default async function OnboardingPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next } = await searchParams;
  let profile: ProfileRow | null = null;
  if (hasSupabaseEnv()) {
    const user = await getCurrentUser();
    if (user) {
      const supabase = await createClient();
      const result = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
      profile = result.data;
    }
  }

  return (
    <main className="min-h-dvh bg-background px-4 py-8 sm:py-12">
      <div className="mx-auto max-w-2xl">
        <div className="mb-9 flex items-center gap-3"><BrandMark /><span className="font-bold">Kickly</span></div>
        <p className="text-xs font-semibold tracking-[0.2em] text-primary uppercase">Step 1 di 1</p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">Che giocatore sei?</h1>
        <p className="mt-3 max-w-xl text-sm leading-6 text-muted-foreground">Completa il profilo: useremo queste informazioni per statistiche, player card e squadre più equilibrate.</p>
        <div className="mt-8"><ProfileForm mode="onboarding" next={next} profile={profile} /></div>
      </div>
    </main>
  );
}
