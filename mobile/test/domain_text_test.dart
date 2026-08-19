import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/data/models.dart';
import 'package:kickly_app/features/profile/profile_widgets.dart';

/// Costruttore di comodo: i modelli hanno molti campi obbligatori e senza un
/// helper ogni test annegherebbe in parametri irrilevanti per cio' che verifica.
LeagueMember _membro({
  String? nome,
  String? cognome,
  String username = 'mario',
}) => LeagueMember(
  id: 'm1',
  userId: 'u1',
  username: username,
  firstName: nome,
  lastName: cognome,
  avatarUrl: null,
  footballRole: null,
  leagueRole: 'member',
  joinedAt: DateTime(2026, 1, 1),
);

MatchParticipant _partecipante({String? nome, String? cognome}) =>
    MatchParticipant(
      id: 'p1',
      userId: 'u1',
      username: 'mario',
      firstName: nome,
      lastName: cognome,
      avatarUrl: null,
      footballRole: null,
      overall: 70,
      response: 'going',
      joinedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Nome mostrato quando il profilo e\' incompleto', () {
    test('un profilo senza nome ne\' cognome viene mostrato come @username, mai vuoto', () {
      // Nome e cognome sono opzionali in `profiles`: senza ripiego la card del
      // giocatore mostrerebbe una riga vuota al posto dell'identita'.
      final profilo = UserProfile.fromMap({'id': 'u1', 'username': 'mario'});
      expect(profilo.displayName, '@mario');
      expect(_membro().displayName, '@mario');
      expect(_partecipante().displayName, '@mario');
    });

    test('con il solo nome compilato non resta uno spazio finale appeso', () {
      // `join(' ')` su [nome, null] produrrebbe "Mario " e lo spazio finirebbe
      // dentro un `Text`, disallineando l'ellissi nelle liste strette.
      expect(
        UserProfile.fromMap({
          'id': 'u1',
          'username': 'mario',
          'first_name': 'Mario',
        }).displayName,
        'Mario',
      );
      expect(_membro(nome: 'Mario').displayName, 'Mario');
      expect(_partecipante(cognome: 'Rossi').displayName, 'Rossi');
    });

    test('un nome fatto di soli spazi conta come assente e non produce un nome invisibile', () {
      // Caso reale di un form salvato con la barra spaziatrice: la stringa non
      // e' null, quindi senza il filtro sul trim l'utente comparirebbe in
      // classifica con un nome apparentemente vuoto.
      final profilo = UserProfile.fromMap({
        'id': 'u1',
        'username': 'mario',
        'first_name': '   ',
        'last_name': '',
      });
      expect(profilo.displayName, '@mario');
      expect(_membro(nome: '  ', cognome: null).displayName, '@mario');
    });
  });

  group('Numeri derivati che finiscono a schermo', () {
    test('la percentuale di vittorie a zero partite non divide per zero', () {
      expect(const PlayerStats().winRate, 0);
    });

    test('la percentuale di vittorie e\' arrotondata, non troncata', () {
      // 2 su 3 e' 66,66%: troncando si mostrerebbe 66% mentre la PWA, che
      // arrotonda, mostrerebbe 67% per lo stesso giocatore.
      expect(const PlayerStats(matches: 3, wins: 2).winRate, 67);
      expect(const PlayerStats(matches: 3, wins: 1).winRate, 33);
      expect(const PlayerStats(matches: 7, wins: 7).winRate, 100);
    });

    test('le statistiche assenti ripiegano su zero ma tengono l\'overall del profilo', () {
      // `player_stats` non ha una riga finche' il giocatore non ha giocato:
      // l'overall deve restare quello del profilo, altrimenti la card
      // mostrerebbe 0 al posto del valore iniziale.
      final vuote = PlayerStats.fromMap(null, fallbackOverall: 74);
      expect(vuote.matches, 0);
      expect(vuote.goals, 0);
      expect(vuote.overall, 74);
    });

    test(
      'il conteggio membri e\' declinato al singolare con un solo membro',
      () {
        expect(_lega(memberCount: 1).memberCountLabel, '1 membro');
        expect(_lega(memberCount: 0).memberCountLabel, '0 membri');
        expect(_lega(memberCount: 24).memberCountLabel, '24 membri');
      },
    );
  });

  group('Etichette tradotte', () {
    test('i ruoli di lega non arrivano a schermo in inglese', () {
      expect(leagueRoleLabel('owner'), 'Proprietario');
      expect(leagueRoleLabel('admin'), 'Admin');
      expect(leagueRoleLabel('member'), 'Membro');
    });

    test(
      'una lega senza ruolo esplicito viene trattata come semplice membro',
      () {
        // `get_user_league_summaries` puo' non restituire `current_user_role`:
        // il ripiego deve essere il ruolo meno privilegiato, altrimenti si
        // mostrerebbero comandi di gestione a chi non puo' usarli.
        final lega = LeagueSummary.fromRpc({'id': 'l1'});
        expect(lega.currentUserRole, 'member');
        expect(lega.roleLabel, 'Membro');
        expect(lega.canManage, isFalse);
      },
    );

    test(
      'un ruolo calcistico mancante diventa "Giocatore" invece di sparire',
      () {
        expect(roleLabel('goalkeeper'), 'Portiere');
        expect(roleLabel(null), 'Giocatore');
        expect(roleLabel('sweeper'), 'Giocatore');
      },
    );

    test('piede e livello non impostati restano nulli, cosi\' chi li mostra li omette', () {
      // Qui il ripiego con un valore inventato sarebbe peggio del vuoto:
      // scrivere "Destro" a un utente che non l'ha mai dichiarato e' un dato
      // falso, quindi il contratto e' restituire null.
      expect(footLabel('right'), 'Destro');
      expect(footLabel(null), isNull);
      expect(footLabel('center'), isNull);
      expect(skillLabel('competitive'), 'Competitivo');
      expect(skillLabel(null), isNull);
      expect(skillLabel('pro'), isNull);
    });
  });

  group('Parsing difensivo dei payload', () {
    test(
      'i numeri arrivati come stringa dal jsonb vengono letti lo stesso',
      () {
        // Un `jsonb` costruito con `to_jsonb(text)` consegna "12", non 12.
        expect(asInt('12'), 12);
        expect(asDouble('1.5'), 1.5);
      },
    );

    test(
      'un numero illeggibile ripiega sul valore indicato, non su zero muto',
      () {
        expect(asInt(null, 10), 10);
        expect(asInt('boh', 10), 10);
        expect(asInt(true, 10), 10);
        expect(asDouble('boh', 2.5), 2.5);
        // Un decimale con la virgola (formattazione italiana) non e' un numero
        // valido per `double.tryParse`: se un giorno le coordinate arrivassero
        // cosi', finirebbero sul fallback invece di piazzare la partita a (0,0)
        // senza avvisare.
        expect(asDouble('1,5', -1), -1);
      },
    );

    test('un decimale viene troncato quando lo si legge come intero', () {
      expect(asInt(3.9), 3);
      expect(asInt(-3.9), -3);
    });

    test('una data malformata non fa saltare la schermata', () {
      // `asDate` e' usata su `starts_at` e `created_at`: lanciare qui vorrebbe
      // dire pagina bianca, quindi il contratto e' ripiegare su "adesso".
      final prima = DateTime.now();
      final reso = asDate('non-una-data');
      final dopo = DateTime.now();
      expect(
        reso.isBefore(prima.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(reso.isAfter(dopo.add(const Duration(seconds: 1))), isFalse);
      expect(asDate(null), isA<DateTime>());
    });

    test('una data UTC viene convertita nel fuso locale prima di mostrarla', () {
      // Senza `toLocal()` l'orario di inizio partita verrebbe mostrato in UTC:
      // d'estate in Italia sono due ore di differenza, cioe' gente che arriva
      // al campo all'ora sbagliata.
      final reso = asDate('2026-08-19T18:30:00Z');
      expect(reso.isUtc, isFalse);
      expect(reso.toUtc(), DateTime.utc(2026, 8, 19, 18, 30));
    });

    test('un testo salvato con la codifica sbagliata viene raddrizzato', () {
      // Le notifiche storiche sono state scritte con un doppio passaggio
      // UTF-8/latin-1: senza riparazione l'utente legge "PerchÃ©".
      expect(repairText('PerchÃ©'), 'Perché');
      // Un testo gia' corretto non deve essere toccato una seconda volta.
      expect(repairText('Perché'), 'Perché');
      expect(repairText('Partita di mercoledì'), 'Partita di mercoledì');
    });

    test('una notifica senza titolo o corpo non mostra campi vuoti', () {
      final notifica = KicklyNotification.fromMap({'id': 'n1'});
      expect(notifica.title, 'Kickly');
      expect(notifica.body, '');
      expect(notifica.readAt, isNull);
      expect(notifica.type, 'info');
    });
  });

  group('LineupSnapshot: snapshot della formazione restituito dalle RPC', () {
    test('un payload che non e\' una mappa viene rifiutato senza lanciare', () {
      // Le RPC di formazione possono restituire null (nessuno snapshot): la
      // pagina deve poter ripiegare sulla ricarica completa invece di crashare
      // mentre l'utente sta scegliendo la posizione.
      expect(LineupSnapshot.fromRpc(null), isNull);
      expect(LineupSnapshot.fromRpc('boh'), isNull);
      expect(LineupSnapshot.fromRpc(<Object>[]), isNull);
    });

    test('uno snapshot senza squadre ne\' giocatori vale liste vuote', () {
      final snapshot = LineupSnapshot.fromRpc(<String, dynamic>{})!;
      expect(snapshot.teams, isEmpty);
      expect(snapshot.players, isEmpty);
    });

    test('le righe non conformi vengono scartate invece di rompere la lista', () {
      // Difesa contro un jsonb misto: basterebbe un elemento non-mappa per far
      // fallire un cast su tutta la lista e cancellare il campo dallo schermo.
      final snapshot = LineupSnapshot.fromRpc({
        'teams': [
          null,
          'rumore',
          {'team_number': 1, 'formation': '2-2', 'captain_user_id': 'u1'},
        ],
        'players': 'non-una-lista',
      })!;
      expect(snapshot.teams, hasLength(1));
      expect(snapshot.teams.first['formation'], '2-2');
      expect(snapshot.players, isEmpty);
    });

    test('le righe conservate sono mappe modificabili con chiavi stringa', () {
      // `Map<String, dynamic>.from` non e' cosmetico: il jsonb arriva come
      // `Map<dynamic, dynamic>` e senza la copia ogni lettura tipizzata a valle
      // fallirebbe a runtime.
      final snapshot = LineupSnapshot.fromRpc({
        'players': <Object?>[
          <dynamic, dynamic>{
            'user_id': 'u1',
            'team_number': 1,
            'slot_key': 'gk',
          },
        ],
      })!;
      expect(snapshot.players.first, isA<Map<String, dynamic>>());
      expect(snapshot.players.first['slot_key'], 'gk');
    });
  });
}

/// Lega minima per i test sulle etichette derivate.
LeagueSummary _lega({required int memberCount}) => LeagueSummary.fromRpc({
  'id': 'l1',
  'name': 'Lega Test',
  'slug': 'lega-test',
  'member_count': memberCount,
});
