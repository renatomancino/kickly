import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, BarChart3, CalendarCheck, MapPin, ShieldCheck } from "lucide-react";

import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";
import { siteConfig } from "@/config/site";

/**
 * L'UNICA pagina di Kickly che vogliamo in indice, ed e' anche l'unica voce
 * della sitemap. Titolo, descrizione, OG e Twitter card arrivano gia' dal root
 * layout: qui aggiungiamo solo le due cose che al root layout non possono stare.
 *
 * - `canonical: "/"`: risolto contro il `metadataBase` del root layout. Serve
 *   perche' la landing e' il bersaglio naturale di link con query di
 *   tracciamento (utm, ref, fbclid) e di varianti host: senza canonical ogni
 *   variante e' un URL distinto e il segnale si frammenta su duplicati.
 * - `robots` esplicito: tecnicamente ridondante (senza direttive un motore
 *   indicizza comunque), ma qui e' documentazione eseguibile. Ogni altro
 *   segmento dell'app dichiara noindex; scriverlo in positivo su questa pagina
 *   rende leggibile a colpo d'occhio che l'indicizzazione e' una whitelist di
 *   una voce sola, non una dimenticanza.
 */
export const metadata: Metadata = {
  alternates: { canonical: "/" },
  robots: { index: true, follow: true },
};

export default function Home() {
  return (
    <main className="min-h-dvh overflow-hidden">
      <nav className="mx-auto flex max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
        <Link className="flex items-center gap-3 font-bold" href="/"><BrandMark />{siteConfig.name}</Link>
        <Button asChild variant="outline"><Link href="/login">Accedi</Link></Button>
      </nav>
      <section className="relative mx-auto grid max-w-6xl gap-12 px-5 pb-20 pt-12 sm:px-8 sm:pt-20 lg:grid-cols-[1.05fr_.95fr] lg:items-center">
        <div>
          <p className="text-xs font-semibold tracking-[0.24em] text-primary uppercase">Il calcio di tutti, fatto meglio</p>
          <h1 className="mt-5 max-w-3xl text-5xl leading-[0.98] font-black tracking-[-0.055em] sm:text-7xl">Organizza la partita.<br /><span className="text-primary">Scrivi la tua storia.</span></h1>
          <p className="mt-6 max-w-xl text-base leading-7 text-muted-foreground sm:text-lg">Leghe, convocazioni e statistiche in un’unica app pensata per chi il calcio lo vive davvero.</p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row"><Button asChild className="h-12 rounded-xl px-6 font-bold"><Link href="/sign-up">Inizia ora <ArrowRight /></Link></Button><Button asChild className="h-12 rounded-xl px-6" variant="secondary"><Link href="/dashboard">Esplora la demo</Link></Button></div>
          <div className="mt-10 flex flex-wrap gap-x-6 gap-y-3 text-xs text-muted-foreground"><span className="flex items-center gap-2"><ShieldCheck className="size-4 text-primary" />Dati protetti con RLS</span><span className="flex items-center gap-2"><CalendarCheck className="size-4 text-primary" />Mobile first</span></div>
        </div>
        <div className="relative mx-auto w-full max-w-md">
          <div aria-hidden className="absolute inset-10 rounded-full bg-primary/15 blur-3xl" />
          <div className="relative rotate-1 rounded-[2rem] border border-primary/20 bg-card p-5 shadow-2xl">
            <div className="flex items-center justify-between"><div><p className="text-xs text-muted-foreground">PROSSIMA PARTITA</p><p className="mt-1 font-bold">Giovedì sotto le luci</p></div><span className="rounded-lg bg-primary px-2 py-1 text-xs font-black text-primary-foreground">5 vs 5</span></div>
            <div className="mt-5 rounded-2xl bg-background/70 p-4"><p className="flex items-center gap-2 text-sm"><CalendarCheck className="size-4 text-primary" />Giovedì · 21:00</p><p className="mt-2 flex items-center gap-2 text-sm text-muted-foreground"><MapPin className="size-4" />Centro Sportivo Aurora</p><div className="mt-4 h-2 overflow-hidden rounded-full bg-muted"><div className="h-full w-4/5 rounded-full bg-primary" /></div><p className="mt-2 text-xs text-muted-foreground">8 / 10 giocatori</p></div>
            <div className="mt-4 grid grid-cols-3 gap-3">{[["24", "Partite"], ["11", "Goal"], ["76", "Overall"]].map(([value, label]) => <div className="rounded-xl border p-3 text-center" key={label}><p className="text-xl font-black">{value}</p><p className="mt-1 text-[10px] text-muted-foreground">{label}</p></div>)}</div>
            <div className="mt-4 flex items-center gap-3 rounded-xl border border-primary/20 bg-primary/5 p-3"><BarChart3 className="size-5 text-primary" /><p className="text-xs"><span className="font-semibold">Overall in crescita</span><br /><span className="text-muted-foreground">+0.6 nelle ultime 4 partite</span></p></div>
          </div>
        </div>
      </section>
    </main>
  );
}
