// Disattiva l'account del chiamante: banna il login e revoca tutte le
// sessioni/refresh token attivi. Non cancella la riga auth.users (vedi il
// commento in cima a request_account_deletion() sul perche' non si usa una
// DELETE) e non tocca public.profiles: quella parte (anonimizzazione,
// cancellazione avatar/notifiche/push) e' gia' fatta dalla RPC
// request_account_deletion(), chiamata dal client PRIMA di questa function.
// Le operazioni qui sotto (ban_duration, revoca sessioni) usano l'Admin API
// di Supabase Auth, che non e' raggiungibile da SQL: per questo serve una
// Edge Function con service_role, sullo stesso pattern di push-worker
// (client service_role, nessuna sessione persistita).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ message: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return json({ message: "Missing runtime configuration" }, 500);
  }

  // Il token del chiamante arriva nell'header Authorization standard (lo
  // stesso che supabase-flutter attacca automaticamente a ogni invoke()
  // quando c'e' una sessione attiva). Senza, non sappiamo CHI bannare.
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) return json({ message: "Missing authorization header" }, 401);
  const callerToken = authHeader.replace(/^Bearer\s+/i, "");

  // Client "come il chiamante": serve solo a risolvere CHI sta chiamando.
  // auth.getUser() verifica la firma del JWT lato Auth, non ci fidiamo di
  // decodificarlo a mano. Nessuna sessione persistita: e' un client
  // usa-e-getta per questa singola richiesta.
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ message: "Invalid session" }, 401);
  }
  const userId = userData.user.id;

  // Solo da qui in poi servono i privilegi di service_role: bannare un
  // account e revocare le sue sessioni sono operazioni di amministrazione,
  // non disponibili al ruolo authenticated.
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

  // ATTENZIONE ALL'ORDINE: signOut PRIMA del ban, non dopo.
  // admin.signOut(jwt, scope) autentica la chiamata a GoTrue con il JWT del
  // chiamante (callerToken), non con la service_role key: e' una wrapper
  // sottile sopra POST /auth/v1/logout con quell'Authorization header.
  // GoTrue rifiuta pero' QUALSIASI richiesta autenticata con il token di un
  // utente gia' bannato ("User is banned"), incluso questo stesso logout.
  // Verificato in locale: bannare prima e poi chiamare signOut fa fallire
  // il signOut con "User is banned" e i refresh token restano validi
  // (nessuna riga in auth.refresh_tokens viene toccata) — il ban da solo
  // NON revoca le sessioni gia' emesse. Invertendo l'ordine, invece,
  // funziona: il token e' ancora valido quando arriva la richiesta di
  // logout. scope "global": revoca TUTTI i refresh token dell'utente, non
  // solo quello di questa richiesta. Senza questo passaggio l'access token
  // gia' emesso resterebbe valido fino alla sua scadenza naturale
  // (jwt_expiry, fino a 1 ora in questo progetto).
  const { error: signOutError } = await admin.auth.admin.signOut(callerToken, "global");
  if (signOutError) return json({ message: signOutError.message }, 500);

  // ~100 anni: blocca il login "per sempre" in pratica senza cancellare la
  // riga auth.users (vedi commento in cima al file). Non e' una vera
  // cancellazione permanente, ma e' la scelta che evita di far ripartire la
  // cascata ON DELETE RESTRICT descritta in request_account_deletion().
  const { error: banError } = await admin.auth.admin.updateUserById(userId, {
    ban_duration: "876000h",
  });
  if (banError) return json({ message: banError.message }, 500);

  return json({ message: "Account disabled" }, 200);
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}
