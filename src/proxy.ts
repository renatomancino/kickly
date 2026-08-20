import { NextResponse, type NextRequest } from "next/server";

import { updateSession } from "@/lib/supabase/proxy";

const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/**
 * Verifica esplicita dell'Origin sulle rotte /api che modificano stato.
 *
 * L'autenticazione qui gira su cookie (@supabase/ssr), non su un header con
 * token: senza SameSite dichiarato esplicitamente da nessuna parte nel
 * codice — verificato nel pacchetto installato, non assunto — la sola
 * protezione da CSRF sarebbe il default del browser (SameSite=Lax da un
 * po' d'anni), mai scritto e quindi facile da perdere in silenzio se in
 * futuro qualcosa imposta `sameSite: 'none'` per un altro motivo (embed in
 * iframe, un flusso di redirect cross-dominio) senza che nessuno se ne
 * accorga. Questo controllo lo rende esplicito e verificabile, invece che
 * implicito nel comportamento di un browser.
 *
 * Solo sui metodi che cambiano qualcosa: GET/HEAD non hanno bisogno di
 * protezione da CSRF per definizione, e bloccarli romperebbe richieste
 * legittime senza aggiungere nulla.
 *
 * Se l'header Origin manca del tutto si lascia passare: un fetch da
 * browser lo manda sempre su richieste cross-site e ormai anche su gran
 * parte delle same-site, ma alcuni client legittimi non-browser potrebbero
 * ometterlo — bloccarli qui sarebbe un falso positivo, e resta comunque
 * protetto dal SameSite del cookie.
 */
function isForgedCrossOrigin(request: NextRequest): boolean {
  if (!request.nextUrl.pathname.startsWith("/api/")) return false;
  if (!MUTATING_METHODS.has(request.method)) return false;
  const origin = request.headers.get("origin");
  if (!origin) return false;
  return origin !== request.nextUrl.origin;
}

export async function proxy(request: NextRequest) {
  if (isForgedCrossOrigin(request)) {
    return NextResponse.json({ message: "Richiesta non autorizzata." }, { status: 403 });
  }
  return updateSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
