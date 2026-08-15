import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";

import { BrandMark } from "@/components/brand-mark";
import { siteConfig } from "@/config/site";

/**
 * Noindex per tutto il gruppo (auth). Sta sul layout e non sulle singole pagine
 * per lo stesso motivo per cui sta sul layout di (protected): cosi' e' una
 * proprieta' del GRUPPO, e una pagina di autenticazione aggiunta domani nasce
 * gia' protetta invece di dipendere dal fatto che qualcuno si ricordi di
 * copiare la riga giusta. Prima di questo file le quattro pagine dichiaravano
 * ognuna il proprio `robots` ed erano gia' divergenti (noindex si', nofollow no).
 *
 * TRAPPOLA DA CONOSCERE PRIMA DI TOCCARE LE PAGINE FIGLIE: Next.js unisce i
 * metadata dei segmenti in modo SHALLOW, quindi un campo annidato come `robots`
 * dichiarato piu' in basso non si fonde con questo — lo SOSTITUISCE per intero.
 * Una pagina figlia che scrivesse `robots: { index: false }` cancellerebbe
 * silenziosamente il `follow: false` definito qui. Le pagine figlie devono
 * quindi limitarsi al `title`.
 *
 * Perche' anche `follow: false`: queste pagine linkano dentro l'area privata
 * (e /update-password si raggiunge con un token nel link). Non c'e' nessun
 * percorso che valga la pena far esplorare a un crawler partendo da qui.
 *
 * Questo e' comunque lo strato 2: il blocco di crawling vero e' in
 * src/app/robots.ts. Il meta serve per i bot che robots.txt lo ignorano.
 */
export const metadata: Metadata = { robots: { index: false, follow: false } };

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="relative min-h-dvh overflow-hidden bg-background">
      <div aria-hidden="true" className="absolute inset-0 bg-[radial-gradient(circle_at_75%_20%,color-mix(in_oklch,var(--primary)_15%,transparent),transparent_32%)]" />
      <div className="relative mx-auto flex min-h-dvh max-w-6xl flex-col px-5 py-6 sm:px-8">
        <Link className="flex w-fit items-center gap-3 font-bold" href="/">
          <BrandMark />
          <span>{siteConfig.name}</span>
        </Link>
        <div className="flex flex-1 items-center justify-center py-12">{children}</div>
      </div>
    </main>
  );
}
