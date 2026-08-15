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

const nextConfig: NextConfig = {
  async headers() {
    return [
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
