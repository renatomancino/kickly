import type { NextConfig } from "next";

/**
 * Terzo strato dell'anti-indicizzazione, dopo src/app/robots.ts (crawling) e i
 * meta `robots` di pagina (indicizzazione).
 *
 * Esiste perche' gli altri due strati hanno due buchi che solo un header HTTP
 * puo' coprire:
 *  - le rotte /api e /auth/callback sono Route Handler: restituiscono JSON o un
 *    redirect, non HTML, quindi un tag <meta> non c'e' nessun posto dove metterlo;
 *  - /join/[code] per un visitatore anonimo — cioe' per qualunque crawler —
 *    risponde con un redirect a /login, e anche il redirect e' una risposta senza
 *    corpo HTML e senza <meta>.
 * `X-Robots-Tag` e' l'equivalente del meta a livello di protocollo e viaggia su
 * qualsiasi risposta, redirect e JSON compresi.
 */
const NOINDEX_HEADER = { key: "X-Robots-Tag", value: "noindex, nofollow" };

/**
 * Host del progetto Supabase (es. "xxxx.supabase.co"), estratto dall'env var
 * pubblica già usata dal client: serve alla CSP per sapere a quale origine
 * concedere connect-src (REST + Realtime via websocket) e img-src (avatar,
 * loghi lega, copertine partita servite da Supabase Storage). Se manca in
 * fase di build (config.local.json non presente, tipico di CI che non fa
 * girare la PWA) la CSP degrada a 'self' soltanto: niente crash, solo un
 * caso limite non nostro da gestire — quella build non arriverà comunque a
 * produzione senza le env var reali.
 */
const supabaseHost = (() => {
  try {
    return new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? "").host || null;
  } catch {
    return null;
  }
})();
const supabaseHttp = supabaseHost ? `https://${supabaseHost}` : "";
const supabaseWs = supabaseHost ? `wss://${supabaseHost}` : "";

const isDev = process.env.NODE_ENV === "development";

/**
 * CSP senza nonce, di proposito: la variante con nonce (quella che Next
 * consiglia per i requisiti di sicurezza più stretti, vedi
 * node_modules/next/dist/docs/01-app/02-guides/content-security-policy.md)
 * costringerebbe OGNI pagina a essere renderizzata dinamicamente — qui
 * dashboard, leghe, partite, profilo e diverse altre sono oggi prerenderizzate
 * staticamente (build verificata: `○` in output). Perderle avrebbe un costo
 * reale (niente cache CDN, hosting più caro, primo caricamento più lento) per
 * chiudere un vettore — script inline iniettato — che oggi non esiste in
 * questo codebase: verificato che non c'è nessun `dangerouslySetInnerHTML` né
 * `eval`/`new Function` in src/. `'unsafe-inline'` resta quindi un compromesso
 * consapevole, non una svista; il resto della policy (frame-ancestors,
 * object-src, base-uri, form-action) non ha questo compromesso e blocca gli
 * attacchi più comuni (clickjacking, injection di plugin/oggetti, dirottamento
 * di form e di <base>) indipendentemente dagli script inline.
 */
const cspHeader = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ""}`,
  "style-src 'self' 'unsafe-inline'",
  `img-src 'self' blob: data:${supabaseHttp ? ` ${supabaseHttp}` : ""}`,
  "font-src 'self' data:",
  `connect-src 'self'${supabaseHttp ? ` ${supabaseHttp}` : ""}${supabaseWs ? ` ${supabaseWs}` : ""}`,
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "upgrade-insecure-requests",
].join("; ");

/**
 * Header di sicurezza applicati a ogni risposta. Mai su /api o /auth: quelle
 * rotte restituiscono JSON o un redirect, non pagine — un browser non
 * applicherebbe comunque CSP/X-Frame-Options a quel tipo di risposta, e
 * distinguerle qui evita solo un header inutile, non è un buco.
 */
const SECURITY_HEADERS = [
  { key: "Content-Security-Policy", value: cspHeader },
  // Ridondante con frame-ancestors della CSP per i browser che la rispettano
  // già, ma costa zero e copre chi guarda solo il vecchio header.
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  // Nessuna di queste API è usata in src/ (verificato): bloccarle è un
  // costo zero, non un compromesso da tenere d'occhio se in futuro
  // servisse la fotocamera o la posizione del browser.
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
  },
  // Ignorato in sviluppo (http): i browser applicano HSTS solo su https, non
  // serve nessuna condizione qui.
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
];

const nextConfig: NextConfig = {
  async headers() {
    return [
      { source: "/(.*)", headers: SECURITY_HEADERS },
      {
        source: "/sw.js",
        headers: [
          { key: "Cache-Control", value: "public, max-age=0, must-revalidate" },
          { key: "Service-Worker-Allowed", value: "/" },
          { key: "Content-Type", value: "application/javascript; charset=utf-8" },
        ],
      },
      // Endpoint tecnici: nessuna di queste risposte deve poter finire in indice.
      { source: "/api/:path*", headers: [NOINDEX_HEADER] },
      { source: "/auth/:path*", headers: [NOINDEX_HEADER] },
      // Link d'invito: l'URL stesso contiene il codice lega. Copre la risposta di
      // redirect verso /login, dove il meta della pagina non arriva mai.
      { source: "/join/:path*", headers: [NOINDEX_HEADER] },
    ];
  },
};

export default nextConfig;
