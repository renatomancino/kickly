import type { Metadata } from "next";

import { LegalSection, LegalShell } from "@/components/legal/legal-shell";
import { siteConfig } from "@/config/site";

/**
 * Informativa privacy pubblica, raggiungibile senza login (vedi il
 * commento in src/components/legal/legal-shell.tsx per il perché sta fuori
 * dai route group protetti e perché non serve noindex).
 *
 * QUESTA PAGINA NON È UN TESTO LEGALE DEFINITIVO. È una bozza
 * strutturalmente accurata rispetto ai dati realmente trattati dal codice
 * (vedi docs/superpowers/specs/2026-08-21-security-store-publishing-design.md,
 * sezione 3), da far rivedere a un legale prima della pubblicazione. I punti
 * che non sono decisioni tecniche ma legali/di business (titolare del
 * trattamento, email di contatto, età minima, regione del progetto
 * Supabase) sono marcati esplicitamente nel testo con un commento
 * `TODO LEGALE` e un placeholder tra parentesi quadre — NON vanno confusi
 * con placeholder di implementazione dimenticati, né completati inventando
 * un valore plausibile.
 */
export const metadata: Metadata = {
  title: "Privacy Policy",
  description: `Come ${siteConfig.name} raccoglie, utilizza e protegge i tuoi dati personali.`,
};

const LAST_UPDATED = "21 agosto 2026";

export default function PrivacyPage() {
  return (
    <LegalShell title="Informativa sulla privacy" lastUpdated={LAST_UPDATED}>
      <LegalSection title="1. Titolare del trattamento">
        <p>
          {/* TODO LEGALE: da compilare prima della pubblicazione, non una decisione tecnica — inserire la persona fisica o la ragione sociale titolare del trattamento, con indirizzo/sede legale secondo la forma scelta (ditta individuale, SRL, associazione...). */}
          Il titolare del trattamento dei dati personali raccolti tramite l&apos;app{" "}
          {siteConfig.name} e il sito {siteConfig.url} è{" "}
          <strong>[Nome e cognome o ragione sociale del titolare — da confermare]</strong>, con
          sede in <strong>[indirizzo del titolare — da confermare]</strong>.
        </p>
        <p>
          {/* TODO LEGALE: da compilare prima della pubblicazione, non una decisione tecnica — email dedicata alle richieste privacy/GDPR. Valutare se l'indirizzo di supporto generico (support@kickly.app, vedi src/config/site.ts) sia adeguato o se serva un indirizzo separato. */}
          Per qualsiasi richiesta relativa al trattamento dei tuoi dati personali puoi scrivere a{" "}
          <strong>[email di contatto privacy — da confermare]</strong>.
        </p>
      </LegalSection>

      <LegalSection title="2. Ambito di applicazione">
        <p>
          Questa informativa descrive quali dati personali {siteConfig.name} raccoglie
          attraverso l&apos;app mobile (iOS e Android) e il sito {siteConfig.url}, per quali
          finalità li utilizza, con chi vengono condivisi e quali diritti hai a riguardo, in
          conformità al Regolamento (UE) 2016/679 (&quot;GDPR&quot;).
        </p>
      </LegalSection>

      <LegalSection title="3. Quali dati raccogliamo e perché">
        <p>
          <strong>Identità e autenticazione.</strong> Per creare un account raccogliamo il tuo
          indirizzo email e una password, oppure, se scegli di registrarti con Google o Apple,
          riceviamo dal provider un token di autenticazione (non vediamo né conserviamo mai la tua
          password Google o Apple). L&apos;autenticazione è gestita dal nostro fornitore di
          infrastruttura, Supabase: le password sono sempre conservate in forma cifrata, mai in
          chiaro.
        </p>
        <p>
          <strong>Profilo.</strong> Username, nome, cognome, data di nascita, ruolo/posizione in
          campo, piede preferito, livello di abilità e foto profilo (avatar). La foto avatar è
          conservata in uno spazio di archiviazione <strong>pubblico</strong>: chiunque sia in
          possesso del suo indirizzo (URL) può visualizzarla, anche senza avere un account{" "}
          {siteConfig.name}. Non caricare come avatar un&apos;immagine che non vuoi rendere
          potenzialmente accessibile fuori dall&apos;app.
        </p>
        <p>
          <strong>Località.</strong> Il comune e la provincia che scegli manualmente dal tuo
          profilo. {siteConfig.name} <strong>non richiede né utilizza mai</strong> la posizione
          GPS del tuo dispositivo: non ti viene mai chiesto il permesso di localizzazione. Il nome
          del comune che inserisci viene inviato a OpenStreetMap Nominatim, un servizio di
          geocodifica di terze parti, per ottenere le coordinate del centroide del comune
          (necessarie per mostrarti leghe e partite nella tua zona); Nominatim riceve il testo
          cercato e l&apos;indirizzo IP del dispositivo da cui parte la richiesta. Vedi la sezione
          5 per il dettaglio su questa terza parte.
        </p>
        <p>
          <strong>Calendario del dispositivo.</strong> Se confermi la presenza a una partita,{" "}
          {siteConfig.name} può aggiungerla al calendario del tuo telefono, con il tuo consenso
          tramite il permesso del sistema operativo. Questa lettura/scrittura avviene interamente
          sul dispositivo: gli eventi di calendario non vengono mai trasmessi ai nostri server né
          a terze parti.
        </p>
        <p>
          <strong>Notifiche.</strong> Oggi {siteConfig.name} ti avvisa di nuove partite,
          aggiornamenti e promemoria tramite notifiche in tempo reale mentre l&apos;app è aperta e
          banner locali generati sul dispositivo; non utilizziamo ancora un servizio di notifiche
          push di terze parti (Firebase Cloud Messaging o Apple Push Notification service).
          L&apos;app prevede già la struttura per attivarli in futuro: quando succederà,
          aggiorneremo questa informativa prima dell&apos;attivazione, indicando il nuovo
          fornitore coinvolto.
        </p>
        <p>
          <strong>Foto delle partite e loghi delle leghe.</strong> Le foto caricate per una
          partita e i loghi caricati per una lega sono conservati in spazi di archiviazione{" "}
          <strong>pubblici</strong>, con lo stesso avviso di accessibilità descritto per
          l&apos;avatar: chiunque conosca l&apos;indirizzo del file può visualizzarlo.
        </p>
      </LegalSection>

      <LegalSection title="4. Base giuridica del trattamento">
        <p>
          Trattiamo i tuoi dati sulla base dell&apos;esecuzione del contratto (fornirti il
          Servizio che hai richiesto creando un account, es. gestione di leghe e partite), del tuo
          consenso (es. permesso di accesso al calendario del dispositivo, richiesto
          esplicitamente dal sistema operativo) e del nostro legittimo interesse a mantenere il
          Servizio sicuro e funzionante (es. prevenzione di abusi).
        </p>
      </LegalSection>

      <LegalSection title="5. Con chi condividiamo i tuoi dati">
        <p>
          Non vendiamo i tuoi dati personali. Li condividiamo solo con i fornitori strettamente
          necessari a far funzionare il Servizio:
        </p>
        <ul>
          <li>
            <strong>Supabase</strong> (Supabase Inc.) — fornitore dell&apos;infrastruttura
            primaria: database, autenticazione e archiviazione file. È il custode tecnico di tutti
            i dati elencati nella sezione 3.
          </li>
          <li>
            <strong>Google</strong> — se scegli di accedere con il tuo account Google (Sign-In),
            riceve la richiesta di autenticazione secondo la propria informativa privacy.
          </li>
          <li>
            <strong>Apple</strong> — se scegli di accedere con Sign in with Apple, riceve la
            richiesta di autenticazione secondo la propria informativa privacy.
          </li>
          <li>
            <strong>OpenStreetMap Nominatim</strong> — riceve il nome del comune che inserisci e
            l&apos;indirizzo IP della richiesta per calcolarne le coordinate (vedi sezione 3,
            &quot;Località&quot;).
          </li>
        </ul>
        <p>
          Non utilizziamo servizi di analisi statistica (analytics), pubblicità (advertising) o
          monitoraggio errori (crash reporting) di terze parti: nessuno di questi è presente nel
          codice del Servizio alla data di questa informativa.
        </p>
        <p>
          {/* TODO LEGALE: da compilare prima della pubblicazione, non una decisione tecnica — inserire la regione del progetto Supabase (Supabase Dashboard → Project Settings → General, es. "Unione Europea (Francoforte, eu-central-1)") e, se la regione è fuori da UE/SEE, la base giuridica del trasferimento extra-UE (es. Clausole Contrattuali Standard della Commissione Europea). */}
          I tuoi dati sono conservati su server nella regione{" "}
          <strong>[regione del progetto Supabase — da confermare]</strong>.{" "}
          <strong>
            [se la regione è extra-UE: base giuridica del trasferimento extra-UE — da confermare]
          </strong>
        </p>
      </LegalSection>

      <LegalSection title="6. Per quanto tempo conserviamo i dati">
        <p>
          Conserviamo i tuoi dati per tutta la durata in cui il tuo account è attivo. Se richiedi
          la cancellazione dell&apos;account (vedi sezione 7), i dati identificativi e di profilo
          vengono rimossi o resi anonimi in tempi brevi; alcuni dati aggregati e non
          identificativi restano collegati alla tua riga anonimizzata per preservare le
          classifiche e lo storico condiviso con gli altri membri delle tue leghe.
        </p>
      </LegalSection>

      <LegalSection title="7. I tuoi diritti e la cancellazione dell'account">
        <p>
          In quanto interessato al trattamento, hai diritto di: accedere ai tuoi dati personali;
          ottenerne la rettifica se inesatti; richiederne la cancellazione; limitarne o opporti al
          trattamento; richiederne la portabilità in un formato strutturato; proporre reclamo
          all&apos;autorità di controllo competente.
        </p>
        <p>
          Puoi cancellare il tuo account in autonomia, in qualsiasi momento, dalla sezione Account
          delle impostazioni del profilo nell&apos;app. Alla conferma: la tua foto profilo viene
          rimossa dallo spazio di archiviazione, e i tuoi dati identificativi (nome, cognome, data
          di nascita, comune, foto) vengono cancellati o resi anonimi; l&apos;account viene
          disabilitato in modo permanente e non potrai più accedervi. Le statistiche di gioco, i
          risultati delle partite e gli eventi a cui hai partecipato{" "}
          <strong>restano visibili</strong> agli altri membri delle tue leghe, ma non più
          associati alla tua identità: comparirai come un utente anonimizzato. Questo è necessario
          per non alterare classifiche e storico condiviso con altri utenti reali.
        </p>
        <p>Per esercitare gli altri diritti elencati sopra, scrivi all&apos;indirizzo indicato nella sezione 1.</p>
      </LegalSection>

      <LegalSection title="8. Età minima">
        <p>
          {/* TODO LEGALE: da compilare prima della pubblicazione, non una decisione tecnica — 14 anni è l'età minima per il consenso autonomo al trattamento dei dati personali prevista dalla normativa italiana di attuazione del GDPR; da confermare che sia il valore corretto per il pubblico a cui il Servizio è realmente rivolto, o da alzare (es. 16 o 18 anni) secondo la decisione del titolare. */}
          L&apos;uso del Servizio è consentito a partire da{" "}
          <strong>[età minima — da confermare, indicativamente 14 anni]</strong> anni. Se hai
          un&apos;età inferiore, non sei autorizzato a creare un account.
        </p>
      </LegalSection>

      <LegalSection title="9. Sicurezza dei dati">
        <p>
          Adottiamo misure tecniche adeguate a proteggere i tuoi dati: comunicazione con i nostri
          server sempre cifrata (TLS), password e sessioni di accesso mai conservate in chiaro sul
          tuo dispositivo, e regole di accesso ai dati (Row Level Security) che limitano ogni
          richiesta esclusivamente ai dati che ti riguardano o che ti sono resi visibili in modo
          esplicito (es. profili di membri della stessa lega). Nessuna misura di sicurezza è
          infallibile: se vieni a conoscenza di una vulnerabilità, scrivici all&apos;indirizzo
          indicato nella sezione 1.
        </p>
      </LegalSection>

      <LegalSection title="10. Modifiche a questa informativa">
        <p>
          Possiamo aggiornare questa informativa nel tempo, ad esempio quando attiviamo un nuovo
          fornitore o una nuova funzionalità che tratta dati personali (vedi la nota sulle
          notifiche push nella sezione 3). La data di &quot;ultimo aggiornamento&quot; in cima a
          questa pagina riflette sempre la versione più recente.
        </p>
      </LegalSection>

      <LegalSection title="11. Contatti">
        <p>
          Per qualsiasi domanda su questa informativa o sul trattamento dei tuoi dati, scrivi a{" "}
          <strong>[email di contatto privacy — da confermare, vedi sezione 1]</strong>.
        </p>
      </LegalSection>
    </LegalShell>
  );
}
