import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { BrandMark } from "@/components/brand-mark";
import { JoinLeaguePreview } from "@/features/leagues/join-league";
import { getInvitePreview } from "@/features/leagues/data";
import { getCurrentUser } from "@/lib/auth";

export const metadata: Metadata = { title: "Invito lega", robots: { index: false } };

export default async function InvitePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const user = await getCurrentUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/join/${code}`)}`);
  const preview = await getInvitePreview(code);

  return (
    <main className="grid min-h-dvh place-items-center px-4 py-10">
      <div className="w-full max-w-lg">
        <div className="mb-8 flex items-center gap-3"><BrandMark /><span className="font-bold">Kickly</span></div>
        <p className="text-xs font-semibold tracking-[0.18em] text-primary uppercase">Invito ricevuto</p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight">Scendi in campo</h1>
        <p className="mt-2 text-sm text-muted-foreground">Controlla i dettagli e unisciti alla lega.</p>
        <div className="mt-7">{preview ? <JoinLeaguePreview code={code} preview={preview} /> : <div className="rounded-2xl border border-dashed p-8 text-center"><h2 className="font-bold">Invito non valido</h2><p className="mt-2 text-sm text-muted-foreground">Il codice potrebbe essere scaduto o rigenerato.</p></div>}</div>
      </div>
    </main>
  );
}
