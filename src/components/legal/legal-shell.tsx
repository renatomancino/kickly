import type { ReactNode } from "react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

import { BrandMark } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { siteConfig } from "@/config/site";

/**
 * Guscio condiviso per le pagine legali pubbliche (Privacy Policy, Termini
 * di servizio). Estratto in un componente invece di duplicare header e
 * tipografia in ogni page.tsx perché sono le uniche due pagine del sito con
 * testo lungo strutturato in sezioni (h2 + paragrafi + liste): senza un
 * punto comune, la "coerenza di stile" tra le due pagine dipenderebbe dal
 * copia-incolla, e sarebbe la prima cosa a divergere al primo aggiornamento
 * di una sola delle due.
 *
 * Vive fuori dai route group (auth)/(protected) di proposito: sia i
 * reviewer store sia un utente prima di registrarsi devono poterle
 * raggiungere senza login. Non serve nemmeno un `robots: { index: false }`
 * esplicito qui: src/app/robots.ts blocca solo un elenco esplicito di
 * prefissi (join/, api/, auth/, l'area autenticata...) e /privacy e /terms
 * non ci compaiono — restano coperte dall'`allow: "/"` di default, scelta
 * corretta per due pagine che un utente può legittimamente cercare su un
 * motore di ricerca prima ancora di installare l'app.
 */
export function LegalShell({
  title,
  lastUpdated,
  children,
}: {
  title: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <main className="min-h-dvh bg-background">
      <nav className="mx-auto flex max-w-3xl items-center justify-between px-5 py-6 sm:px-8">
        <Link className="flex items-center gap-3 font-bold" href="/">
          <BrandMark />
          {siteConfig.name}
        </Link>
        <Button asChild variant="outline" size="sm">
          <Link href="/">
            <ArrowLeft />
            Home
          </Link>
        </Button>
      </nav>
      <article className="mx-auto max-w-3xl px-5 pb-24 sm:px-8">
        <h1 className="text-3xl font-black tracking-tight sm:text-4xl">{title}</h1>
        <p className="mt-2 text-sm text-muted-foreground">Ultimo aggiornamento: {lastUpdated}</p>
        <Separator className="mt-6" />
        {/*
          Nessun plugin @tailwindcss/typography nel progetto (non è tra le
          devDependencies di package.json): la tipografia per il testo lungo
          è quindi dichiarata qui a mano con selettori figlio arbitrari di
          Tailwind v4, in un unico punto condiviso da entrambe le pagine
          invece che ripetuta su ogni h2/p/ul delle due page.tsx.
        */}
        <div className="mt-8 space-y-10 text-sm leading-7 text-foreground/90 [&_h2]:text-xl [&_h2]:font-bold [&_h2]:tracking-tight [&_h2]:text-foreground [&_p]:mt-3 [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:space-y-1.5 [&_ul]:pl-5 [&_li]:leading-6 [&_strong]:font-semibold [&_strong]:text-foreground [&_a]:text-primary [&_a]:underline [&_a]:underline-offset-4">
          {children}
        </div>
      </article>
    </main>
  );
}

/**
 * Una sezione numerata (h2 + contenuto). Wrapper minimo: dà struttura
 * semantica (<section>/<h2>) coerente a entrambe le pagine, nessuna logica.
 */
export function LegalSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h2>{title}</h2>
      {children}
    </section>
  );
}
