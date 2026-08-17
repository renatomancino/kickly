import type { Metadata } from "next";
import type { ReactNode } from "react";

import { requireUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/env";

/**
 * Noindex ereditato da tutta l'area autenticata (dashboard, leghe, partite,
 * profilo, notifiche, impostazioni, player/[username], onboarding).
 *
 * Sta qui e non sulle singole pagine perche' Next.js unisce i metadata in modo
 * SHALLOW: le pagine figlie dichiarano solo il `title` e quindi questo `robots`
 * sopravvive intatto fino all'HTML finale. Se una figlia dichiarasse un proprio
 * `robots`, lo sostituirebbe per intero — quindi non va fatto.
 *
 * Non e' ridondante rispetto al `requireUser()` qui sotto: il redirect protegge
 * i DATI, il meta protegge gli URL. Senza, le rotte interne resterebbero
 * indicizzabili come guscio vuoto e finirebbero comunque in SERP. Ed e' il
 * secondo strato dopo src/app/robots.ts, che al crawler educato impedisce gia'
 * di richiedere queste pagine: il meta serve per i bot che ignorano robots.txt,
 * gli unici che arrivano fin qui a scaricare l'HTML.
 */
export const metadata: Metadata = { robots: { index: false, follow: false } };

export default async function ProtectedLayout({ children }: { children: ReactNode }) {
  if (hasSupabaseEnv()) await requireUser();
  return children;
}
