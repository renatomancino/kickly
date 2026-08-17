import type { Metadata } from "next";
import Link from "next/link";
import { WifiOff } from "lucide-react";
import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";

/**
 * Fallback della PWA servito dal service worker quando la rete non c'e'.
 * Noindex perche' e' un guscio senza contenuto: se finisse in indice sarebbe un
 * doppione scadente della landing, e un utente che cercasse "Kickly" potrebbe
 * atterrare su una pagina che gli dice solo "sei offline". `follow: false` per
 * coerenza: gli unici link qui puntano dentro l'area autenticata.
 */
export const metadata: Metadata = { title: "Sei offline", robots: { index: false, follow: false } };

export default function OfflinePage() {
  return <main className="grid min-h-dvh place-items-center px-6"><div className="max-w-sm text-center"><BrandMark className="mx-auto size-14" /><WifiOff className="mx-auto mt-8 size-8 text-muted-foreground" /><h1 className="mt-4 text-2xl font-black">Sei offline</h1><p className="mt-2 text-sm text-muted-foreground">Riconnettiti per aggiornare leghe, partite e notifiche.</p><Button asChild className="mt-6"><Link href="/dashboard">Riprova</Link></Button></div></main>;
}
