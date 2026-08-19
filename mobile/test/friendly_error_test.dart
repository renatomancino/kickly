import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/core/widgets/common.dart';

/// Messaggio di ripiego di `friendlyError`. Se un codice sollevato da una RPC
/// finisce qui, l'utente legge "riprova tra poco" davanti a un errore che
/// invece ha una causa precisa e un'azione precisa da compiere: e' il fallimento
/// silenzioso che questi test devono intercettare.
const _generico = 'Qualcosa non ha funzionato. Riprova tra poco.';

/// Formato reale della stringa che arriva a `friendlyError`: nel codice non
/// viene mai passato il codice nudo, ma la `PostgrestException` cosi' come la
/// serializza `toString()`. Testare solo il codice nudo lascerebbe scoperto il
/// caso in cui un controllo venga scritto con `==` invece che con `contains`.
String _erroreSupabase(String codice) =>
    'PostgrestException(message: $codice, code: P0001, '
    'details: Bad Request, hint: null)';

/// Codici SQL -> messaggio italiano atteso, per i soli codici che oggi
/// `friendlyError` traduce davvero. La lista e' stata ricavata incrociando
/// `raise exception '<codice>'` nelle migrazioni con le RPC che
/// `KicklyRepository` invoca: serve come contratto scritto, cosi' se qualcuno
/// riordina i controlli dentro `friendlyError` il test dice subito quale
/// messaggio e' cambiato invece di lasciarlo scoprire a un utente.
const _traduzioniAttese = <String, String>{
  'league_full': 'La lega ha raggiunto il numero massimo di membri.',
  'invalid_invite_code': 'Il codice invito non è valido.',
  'lineup_slot_taken':
      'Questa posizione è appena stata presa da un altro giocatore.',
  'lineup_captain_taken': 'La squadra ha già un capitano.',
  'lineup_captain_required':
      'Solo il capitano della squadra o un admin può cambiare modulo.',
  'invalid_lineup_formation':
      'Questo modulo non è valido per il formato della partita.',
  'invalid_lineup_slot':
      'Questa posizione non esiste nel formato della partita.',
  'confirmed_participant_required': 'Conferma prima la presenza alla partita.',
  'match_locked': 'La partita è chiusa: non si può più modificare.',
  'match_not_found': 'Partita non trovata o non più accessibile.',
  'venue_phone_required': 'Manca il telefono della struttura: aggiungilo dalle impostazioni della partita.',
  'authentication_required': 'Sessione scaduta: accedi di nuovo.',
  'invalid_player_totals':
      'I gol o gli assist inseriti per un giocatore non sono validi.',
  'player_totals_required':
      'Inserisci gol e assist per tutti i giocatori confermati.',
  'duplicate_team_player':
      'Un giocatore risulta in entrambe le squadre: controlla la formazione.',
  'teams_required': 'Assegna tutti i giocatori confermati a una squadra prima di chiudere la partita.',
  'all_confirmed_players_required':
      'Mancano dei giocatori confermati nelle squadre.',
  'team_match_mismatch': 'Questa squadra non appartiene a questa partita.',
  'invalid_score': 'Il punteggio inserito non è valido.',
  'registrations_closed': 'Le iscrizioni a questa partita sono chiuse.',
  'max_below_confirmed': 'Non puoi impostare un numero massimo di giocatori inferiore alle presenze già confermate.',
  'mvp_voting_closed': 'La votazione per l’MVP è chiusa.',
  'mvp_voting_open': 'La votazione per l’MVP è ancora aperta.',
  'cannot_vote_self': 'Non puoi votare te stesso come MVP.',
  'invalid_mvp_candidate': 'Questo giocatore non può essere votato come MVP.',
  'no_mvp_candidates':
      'Nessun voto ricevuto: non è stato possibile eleggere un MVP.',
  'admin_required': 'Solo un admin della lega può eseguire questa azione.',
  'membership_required':
      'Devi essere membro della lega per eseguire questa azione.',

  // I 32 codici che questo stesso file aveva scoperto essere privi di
  // traduzione: le RPC li sollevano davvero, ma l'utente leggeva il messaggio
  // generico. Stanno qui e non in un elenco a parte proprio perché il test
  // sulle sottostringhe qui sotto scorre questa mappa: aggiungerli qui
  // significa che anche il loro ordine dentro friendlyError è verificato.
  'owner_required':
      'Solo il proprietario della lega può eseguire questa azione.',
  'participant_required':
      'Solo chi partecipa alla partita può eseguire questa azione.',
  'already_member': 'Fai già parte di questa lega.',
  'membership_banned':
      'Non puoi rientrare in questa lega: un admin ti ha rimosso.',
  'public_league_not_found': 'Questa lega non esiste più o non è più pubblica.',
  'owner_cannot_leave': 'Sei il proprietario: trasferisci prima la lega a un altro membro, poi potrai uscire.',
  'member_not_found': 'Questo giocatore non fa parte della lega.',
  'cannot_remove_owner': 'Il proprietario della lega non può essere rimosso.',
  'cannot_change_owner_role': 'Il ruolo del proprietario non si può cambiare: serve trasferire la lega.',
  'already_owner': 'Questo giocatore è già il proprietario della lega.',
  'communication_rate_limited': 'Hai pubblicato un avviso da poco: aspetta qualche minuto prima del prossimo.',
  'reminder_rate_limited': 'Hai già inviato un promemoria da poco: aspetta prima di inviarne un altro.',
  'no_reminder_recipients':
      'Nessuno da avvisare: non ci sono giocatori a cui mandare il promemoria.',
  'communication_not_found': 'Questo avviso è già stato eliminato.',
  'invalid_max_members': 'Il numero massimo di membri non è valido.',
  'invalid_max_players': 'Il numero massimo di giocatori non è valido.',
  'invalid_coordinates': 'Non siamo riusciti a individuare il luogo scelto: riprova a selezionarlo.',
  'invalid_venue_phone': 'Il telefono della struttura non è valido.',
  'invalid_communication': 'L’avviso deve avere un titolo e un testo.',
  'invalid_reminder': 'Il promemoria non è valido.',
  'invalid_location': 'Indica dove si gioca.',
  'invalid_province': 'La provincia non è valida.',
  'invalid_country': 'Il paese non è valido.',
  'invalid_title': 'Il titolo non è valido.',
  'invalid_name': 'Il nome non è valido.',
  'invalid_slug':
      'Esiste già una lega con un nome molto simile: scegline un altro.',
  'invalid_city': 'La città non è valida.',
  'invalid_cost': 'Il costo inserito non è valido.',
  'invalid_role': 'Questo ruolo non esiste.',
  'invalid_team': 'Questa squadra non esiste.',
  'invalid_action': 'Azione non riconosciuta.',
  'invalid_response': 'Risposta non riconosciuta.',
};

void main() {
  group('friendlyError: traduzione dei codici delle RPC', () {
    test('ogni codice tradotto arriva all\'utente con il proprio messaggio, anche dentro una PostgrestException', () {
      final regressioni = <String>[];
      _traduzioniAttese.forEach((codice, atteso) {
        final reso = friendlyError(_erroreSupabase(codice));
        if (reso != atteso) regressioni.add('$codice -> "$reso"');
      });
      // Un solo expect con l'elenco completo: se qualcuno riordina i
      // controlli, il report dice tutti i codici rotti in una volta invece di
      // fermarsi al primo.
      expect(regressioni, isEmpty, reason: 'traduzioni cambiate o perse');
    });

    test('nessun codice tradotto viene intercettato dal controllo di un altro codice che lo contiene', () {
      // La trappola concreta: `friendlyError` usa `contains`, quindi se il
      // controllo del codice piu' corto stesse prima di quello del codice piu'
      // lungo l'utente leggerebbe il messaggio sbagliato. Qui verifichiamo
      // ogni coppia realmente in relazione di sottostringa.
      final conflitti = <String>[];
      for (final lungo in _traduzioniAttese.keys) {
        for (final corto in _traduzioniAttese.keys) {
          if (lungo == corto || !lungo.contains(corto)) continue;
          final reso = friendlyError(lungo);
          if (reso != _traduzioniAttese[lungo]) {
            conflitti.add('"$corto" oscura "$lungo" (reso: "$reso")');
          }
        }
      }
      expect(conflitti, isEmpty);
    });

    test('il codice invito non valido viene riconosciuto anche se il controllo cerca un prefisso piu\' corto', () {
      // `join_league_by_code` solleva `invalid_invite_code`, mentre
      // `friendlyError` cerca `invalid_invite`: il match regge solo perche' e'
      // un prefisso. Se il codice SQL venisse rinominato in qualcosa che non
      // inizia per `invalid_invite`, questo test cade prima dell'utente.
      expect(
        friendlyError(_erroreSupabase('invalid_invite_code')),
        'Il codice invito non è valido.',
      );
    });

    test('lo scarto fra gol dei giocatori e punteggio squadra spiega il problema invece di cadere nel messaggio generico', () {
      // `finalize_match` solleva `team_a_goals_mismatch:%:%`, cioe' il codice
      // arriva con due numeri appesi: un confronto per uguaglianza non
      // matcherebbe mai e l'admin che chiude la partita a mano resterebbe
      // senza spiegazione.
      const atteso =
          'I gol assegnati ai giocatori non corrispondono al punteggio della squadra. Controlla i gol inseriti.';
      expect(
        friendlyError(_erroreSupabase('team_a_goals_mismatch:3:2')),
        atteso,
      );
      expect(
        friendlyError(_erroreSupabase('team_b_goals_mismatch:0:1')),
        atteso,
      );
    });

    test('gli errori di login di Supabase Auth restano in italiano', () {
      expect(
        friendlyError('AuthApiException(message: Invalid login credentials)'),
        'Email o password non corrette.',
      );
      expect(
        friendlyError('AuthApiException(message: User already registered)'),
        'Esiste già un account con questa email.',
      );
    });

    test('il controllo su "username" resta l\'ultimo e non ruba gli errori delle RPC', () {
      // "username" e' una parola comune: compare nei messaggi di vincolo
      // Postgres che citano la colonna. Se il suo controllo risalisse in cima
      // alla funzione, un errore di permessi su una lega verrebbe mostrato
      // come "username non disponibile".
      expect(
        friendlyError(
          'PostgrestException(message: admin_required, code: P0001, '
          'details: null, hint: check profiles.username)',
        ),
        'Solo un admin della lega può eseguire questa azione.',
      );
      expect(
        friendlyError(
          'duplicate key value violates unique constraint "profiles_username_key"',
        ),
        'Questo username non è disponibile.',
      );
    });

    test(
      'un errore senza codice riconoscibile non lascia la schermata vuota',
      () {
        expect(friendlyError('SocketException: Connection refused'), _generico);
        expect(friendlyError(Exception()), _generico);
      },
    );
  });
}
