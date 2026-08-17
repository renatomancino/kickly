import type { MetadataRoute } from "next";

import { siteConfig } from "@/config/site";

/**
 * sitemap.xml generata via convenzione App Router (`app/sitemap.ts`).
 *
 * PERCHE' UNA SOLA URL: la sitemap dichiara "queste pagine esistono e voglio
 * che le guardiate". Di Kickly l'unica pagina davvero pubblica e con contenuto
 * e' la landing. Tutto il resto e' dietro login, e' un endpoint tecnico o e' una
 * pagina di autenticazione senza contenuto da posizionare. Una sitemap con una
 * riga sola sembra povera, ma e' quella onesta: gonfiarla con /login o /sign-up
 * significherebbe dichiarare come indicizzabili pagine che nello stesso deploy
 * blocchiamo in robots.ts e marchiamo noindex — segnali contraddittori che i
 * motori risolvono a modo loro, quindi meglio non darli.
 *
 * REGOLA NON NEGOZIABILE: qui dentro non entra MAI `/join/[code]`, ne' oggi ne'
 * quando qualcuno dovesse "arricchire la sitemap". Quegli URL contengono il
 * codice invito a una lega privata: inserirli in sitemap significherebbe
 * consegnare a Google l'elenco degli inviti attivi. Per lo stesso motivo qui
 * non va generata nessuna voce da query al database (leghe, partite, profili
 * giocatore): sono tutti dati di gruppi privati.
 */

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: siteConfig.url,
      // `sitemap.ts` e' un route handler cacheato: senza API dinamiche viene
      // valutato a build time, quindi questa data coincide con il deploy. E'
      // esattamente la semantica giusta per una landing statica — il contenuto
      // cambia quando ridistribuiamo, non quando cambiano i dati degli utenti.
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 1,
    },
  ];
}
