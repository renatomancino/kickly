import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { BrandMark } from "@/components/brand-mark";
import { JoinLeaguePreview } from "@/features/leagues/join-league";
import { getInvitePreview } from "@/features/leagues/data";
import { getCurrentUser } from "@/lib/auth";

/**
 * Questa e' la rotta piu' delicata dell'app: l'URL stesso E' il segreto, perche'
 * contiene il codice invito a una lega privata. Il noindex qui e' il secondo
 * strato di difesa, non il primo.
 *
 * Differenza fra i due strati, che e' il motivo per cui servono entrambi:
 * - `robots.txt` (src/app/robots.ts) e' una direttiva sul CRAWLING: dice al bot
 *   di non richiedere proprio l'URL. Il bot educato obbedisce, ma proprio perche'
 *   non scarica la pagina non legge nemmeno questo meta tag.
 * - il meta `robots` qui sotto e' una direttiva sull'INDICIZZAZIONE: agisce solo
 *   su chi la pagina l'ha gia' scaricata, cioe' i crawler che ignorano
 *   robots.txt (o che arrivano qui da un redirect, dove robots.txt non entra in
 *   gioco). Per loro questo tag e' l'unica cosa che impedisce l'indicizzazione.
 *
 * `follow: false` oltre a `index: false` e' deliberato: senza, un crawler che
 * ignora robots.txt non indicizzerebbe la pagina ma seguirebbe comunque i link
 * verso l'interno della lega, scoprendo altre rotte da tentare. Su una pagina
 * che nasce da un link privato non c'e' nessun link che valga la pena seguire.
 *
 * Nota: la difesa sostanziale resta il redirect a /login qui sotto — un crawler
 * e' sempre anonimo, quindi il contenuto dell'invito (nome lega, membri) non gli
 * viene mai servito. Il redirect e' coperto dall'header X-Robots-Tag in
 * next.config.ts, perche' su una risposta 307 un tag <meta> non esiste.
 */
export const metadata: Metadata = { title: "Invito lega", robots: { index: false, follow: false } };

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
