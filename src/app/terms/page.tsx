import type { Metadata } from "next";

import { LegalSection, LegalShell } from "@/components/legal/legal-shell";
import { siteConfig } from "@/config/site";

/**
 * Termini di servizio pubblici, raggiungibile senza login — stesse note
 * della privacy policy in src/app/privacy/page.tsx: NON è un testo legale
 * definitivo, i punti marcati `TODO LEGALE` richiedono una decisione del
 * titolare e/o revisione legale prima della pubblicazione.
 */
export const metadata: Metadata = {
  title: "Termini di servizio",
  description: `Le regole d'uso di ${siteConfig.name}.`,
};

const LAST_UPDATED = "21 agosto 2026";

export default function TermsPage() {
  return (
    <LegalShell title="Termini di servizio" lastUpdated={LAST_UPDATED}>
      <LegalSection title="1. Accettazione dei termini">
        <p>
          Creando un account o utilizzando in qualsiasi modo {siteConfig.name} (l&apos;app mobile
          o il sito {siteConfig.url}, di seguito il &quot;Servizio&quot;) accetti integralmente
          questi Termini di servizio. Se non li accetti, non puoi utilizzare il Servizio.
        </p>
      </LegalSection>

      <LegalSection title="2. Descrizione del servizio">
        <p>
          {siteConfig.name} è una piattaforma che permette di organizzare leghe e partite di
          calcio amatoriale tra utenti: creazione di leghe, convocazioni, gestione delle presenze,
          statistiche di gioco e classifiche. {siteConfig.name} è uno strumento organizzativo:{" "}
          <strong>
            non gestisce, non prenota e non è responsabile
          </strong>{" "}
          per gli impianti sportivi, i campi o le strutture presso cui le partite si svolgono, che
          restano rapporti diretti tra gli utenti e le strutture stesse.
        </p>
      </LegalSection>

      <LegalSection title="3. Registrazione e account">
        <p>
          Per usare il Servizio devi creare un account con email e password oppure tramite Google
          o Apple. Sei responsabile della riservatezza delle tue credenziali e di tutte le
          attività svolte con il tuo account.
        </p>
        <p>
          {/* TODO LEGALE: stesso valore della sezione 8 dell'informativa privacy (src/app/privacy/page.tsx) — da confermare insieme, non separatamente, per evitare che le due pagine indichino età minime diverse. */}
          L&apos;uso del Servizio è consentito a partire da{" "}
          <strong>[età minima — da confermare, indicativamente 14 anni]</strong> anni.
        </p>
      </LegalSection>

      <LegalSection title="4. Comportamento dell'utente e contenuti generati">
        <p>
          Quando entri in una lega — anche una lega pubblica a cui accedi in autonomia perché ti
          trovi entro un raggio di prossimità — il tuo profilo (nome, cognome, foto, comune, data
          di nascita) diventa visibile agli altri membri di quella lega, anche se non li conosci
          personalmente. Ti impegni a comportarti in modo rispettoso verso gli altri utenti e a
          non utilizzare il Servizio per molestie, contenuti offensivi o comportamenti illeciti.
        </p>
        <p>
          Se un altro utente ha un comportamento scorretto, puoi segnalarlo o bloccarlo
          direttamente dal suo profilo nell&apos;app: una volta bloccato, quell&apos;utente non
          vedrà più il tuo profilo né tu il suo, all&apos;interno delle leghe che condividete. Ci
          riserviamo il diritto di sospendere o cancellare account che violano questi Termini,
          anche sulla base delle segnalazioni ricevute.
        </p>
      </LegalSection>

      <LegalSection title="5. Contenuti caricati (foto, loghi)">
        <p>
          Rimani proprietario delle foto e dei loghi che carichi (foto profilo, foto delle
          partite, loghi delle leghe). Caricandoli, concedi a {siteConfig.name} una licenza non
          esclusiva, gratuita e limitata a mostrarli all&apos;interno del Servizio, per le
          finalità per cui li hai caricati. Come indicato nell&apos;informativa privacy, questi
          contenuti sono conservati in spazi di archiviazione pubblici: non caricare immagini che
          non vuoi rendere potenzialmente accessibili a chiunque ne conosca l&apos;indirizzo. Non
          caricare contenuti di cui non detieni i diritti o che violano diritti di terzi.
        </p>
      </LegalSection>

      <LegalSection title="6. Eventi sportivi organizzati tramite il Servizio">
        <p>
          Le partite e gli eventi organizzati tramite {siteConfig.name} sono attività sportive
          reali, organizzate direttamente dagli utenti tra loro. {siteConfig.name} mette a
          disposizione lo strumento di organizzazione (convocazioni, conferme di presenza,
          promemoria) ma{" "}
          <strong>
            non partecipa all&apos;organizzazione fisica dell&apos;evento, non fornisce
            assicurazione, assistenza medica o sorveglianza, e non è responsabile per infortuni,
            lesioni, danni fisici o materiali subiti da te o da terzi durante la partecipazione a
            una partita o a un evento organizzato tramite il Servizio
          </strong>
          . La partecipazione ad attività sportive comporta un rischio intrinseco che ciascun
          utente accetta partecipando; ogni utente è responsabile di valutare la propria idoneità
          fisica e di attrezzarsi/assicurarsi secondo le regole dell&apos;impianto sportivo presso
          cui si gioca.
        </p>
      </LegalSection>

      <LegalSection title="7. Disponibilità del servizio e limitazione di responsabilità">
        <p>
          Ci impegniamo a mantenere il Servizio disponibile e funzionante, ma non garantiamo che
          sarà sempre privo di interruzioni o errori. Nei limiti consentiti dalla legge
          applicabile, {siteConfig.name} non è responsabile per danni indiretti derivanti
          dall&apos;uso o dall&apos;impossibilità di utilizzare il Servizio, incluse — a titolo
          esemplificativo — la mancata ricezione di una notifica o di un promemoria.
        </p>
      </LegalSection>

      <LegalSection title="8. Sospensione e cancellazione dell'account">
        <p>
          Puoi cancellare il tuo account in qualsiasi momento dalle impostazioni del profilo
          nell&apos;app (vedi anche la sezione 7 dell&apos;informativa privacy per i dettagli su
          cosa viene rimosso e cosa resta in forma anonima). Ci riserviamo il diritto di
          sospendere o disabilitare un account in caso di violazione di questi Termini, anche
          senza preavviso nei casi più gravi.
        </p>
      </LegalSection>

      <LegalSection title="9. Modifiche al servizio e ai termini">
        <p>
          Possiamo modificare o interrompere funzionalità del Servizio, e aggiornare questi
          Termini nel tempo. La data di &quot;ultimo aggiornamento&quot; in cima a questa pagina
          riflette sempre la versione più recente; se una modifica è sostanziale, cercheremo di
          darne comunicazione in modo evidente all&apos;interno dell&apos;app.
        </p>
      </LegalSection>

      <LegalSection title="10. Legge applicabile e foro competente">
        <p>
          {/* TODO LEGALE: da compilare prima della pubblicazione, non una decisione tecnica — dipende dalla sede/nazionalità del titolare indicato nella sezione 1 dell'informativa privacy. Se il titolare ha sede in Italia, la formulazione standard è "legge italiana" e "foro del luogo di residenza del titolare" o "foro del consumatore" per gli utenti che agiscono come consumatori (art. 66-bis Codice del Consumo) — da far confermare comunque a un legale insieme al resto della pagina. */}
          Questi Termini sono regolati dalla legge{" "}
          <strong>[legge applicabile — da confermare]</strong>. Per ogni controversia è competente
          il foro <strong>[foro competente — da confermare]</strong>, fatte salve le norme
          inderogabili a tutela del consumatore eventualmente applicabili.
        </p>
      </LegalSection>

      <LegalSection title="11. Contatti">
        <p>
          Per qualsiasi domanda su questi Termini, scrivi a{" "}
          <strong>[email di contatto — da confermare, vedi sezione 1 dell&apos;informativa privacy]</strong>.
        </p>
      </LegalSection>
    </LegalShell>
  );
}
