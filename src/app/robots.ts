import type { MetadataRoute } from "next";

import { siteConfig } from "@/config/site";

/**
 * robots.txt generato via convenzione App Router (`app/robots.ts`).
 *
 * PERCHE' ESISTE QUESTO FILE: non e' SEO, e' privacy. Kickly ha una sola pagina
 * pubblica che ha senso far indicizzare (la landing "/"). Tutto il resto o sta
 * dietro autenticazione, o e' un endpoint tecnico, oppure — caso peggiore — e'
 * un URL che contiene di per se' un segreto: `/join/<codice>` e' il link di
 * invito a una lega. Senza robots.txt, se anche un solo invito finisce in una
 * chat indicizzata, in una mail scansionata o in un sito qualsiasi, il crawler
 * lo segue, lo mette in indice e da quel momento chiunque puo' trovare un
 * invito valido a una lega privata con una ricerca. Il codice invito perde
 * qualunque valore come segreto condiviso.
 *
 * LIMITE DA TENERE A MENTE: robots.txt e' una richiesta, non un controllo di
 * accesso. Vale solo per i crawler che la rispettano e non impedisce a nessuno
 * di aprire l'URL a mano. Per questo il blocco qui e' solo il primo dei tre
 * strati che abbiamo messo:
 *   1. robots.txt (questo file)     -> il crawler educato non richiede mai la pagina
 *   2. <meta name="robots" noindex> -> per chi ignora robots.txt ma rispetta il meta
 *   3. header X-Robots-Tag          -> in next.config.ts, unico strato possibile su
 *                                      /api e sulle risposte di redirect (302/307),
 *                                      dove un tag <meta> non esiste proprio
 * A cui si somma la difesa vera: `/join/[code]` fa redirect a /login se non sei
 * autenticato, quindi un crawler (che e' sempre anonimo) non vede mai il
 * contenuto dell'invito, solo la pagina di login.
 *
 * ATTENZIONE al rapporto fra strato 1 e strato 2: se robots.txt vieta il
 * crawling di un URL, il crawler non scarica la pagina e quindi NON legge mai
 * il meta noindex. Un URL bloccato qui puo' comunque comparire in SERP come
 * solo-URL (senza titolo ne' snippet) se qualcuno lo linka da fuori. Non e' una
 * contraddizione ma una scelta: per un link d'invito preferiamo che il crawler
 * non scarichi mai la pagina — cosi' nome lega, foto e membri non entrano
 * nell'indice — accettando il rischio residuo del solo URL, che comunque
 * scade/si rigenera lato lega.
 */

/**
 * Prefissi che i crawler non devono richiedere.
 * Nota sui path: i route group dell'App Router — `(auth)`, `(protected)`,
 * `(app)` — NON compaiono nell'URL finale, quindi qui vanno elencati i percorsi
 * reali (`/dashboard`, non `/(protected)/(app)/dashboard`).
 * Il trailing slash sui prefissi con figli dinamici (`/join/`, `/player/`) e'
 * voluto: copre tutto il sottoalbero senza bloccare per sbaglio altro.
 */
const DISALLOWED_PATHS = [
  // Il caso critico: ogni URL qui sotto contiene un codice invito a una lega.
  "/join/",

  // Endpoint tecnici: non sono pagine, indicizzarli produce solo JSON in SERP
  // e superficie di scoperta gratuita per chi cerca endpoint da sondare.
  "/api/",
  "/auth/",

  // Fallback PWA servito dal service worker: e' un guscio senza contenuto,
  // in indice sarebbe solo un doppione scadente della landing.
  "/offline",

  // Pagine di autenticazione: pubbliche per forza, ma non hanno nulla da
  // posizionare e /update-password viene raggiunta con un token nel link.
  "/login",
  "/sign-up",
  "/forgot-password",
  "/update-password",

  // Area applicativa dietro login: un crawler qui riceverebbe comunque un
  // redirect, ma vale la pena non fargli nemmeno consumare crawl budget e non
  // esporre la mappa delle rotte interne.
  "/onboarding",
  "/dashboard",
  "/leagues",
  "/matches",
  "/notifications",
  "/profile",
  "/settings",
  "/player/",
];

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        // Allow esplicito sulla sola landing invece di "/" generico: rende
        // evidente, leggendo il robots.txt prodotto, che l'indicizzazione e'
        // una whitelist di una riga e non un "tutto aperto con eccezioni".
        allow: "/",
        disallow: DISALLOWED_PATHS,
      },
    ],
    // La sitemap va dichiarata in assoluto (lo standard non ammette path
    // relativi). siteConfig.url viene da NEXT_PUBLIC_APP_URL: se in produzione
    // manca, il fallback e' localhost e questa riga risulta inutile ma
    // innocua — stesso identico vincolo del metadataBase in app/layout.tsx.
    sitemap: `${siteConfig.url}/sitemap.xml`,
  };
}
