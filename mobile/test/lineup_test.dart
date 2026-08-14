import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/data/models.dart';
import 'package:kickly_app/features/matches/lineup_config.dart';

void main() {
  group('Formati e moduli', () {
    test('la dimensione della squadra segue il formato', () {
      expect(lineupSideSize('5v5'), 5);
      expect(lineupSideSize('7v7'), 7);
      expect(lineupSideSize('11v11'), 11);
      // Formato sconosciuto: non deve lanciare, ripiega su 5.
      expect(lineupSideSize('boh'), 5);
    });

    test('ogni modulo dichiarato copre esattamente i giocatori di movimento', () {
      // Se questa asserzione salta, il campo mostrerebbe slot che il database
      // rifiuta: private.is_valid_lineup_slot ammette solo indici inferiori
      // alla dimensione della squadra.
      for (final entry in lineupFormations.entries) {
        final side = lineupSideSize(entry.key);
        for (final formation in entry.value) {
          final outfield = formation
              .split('-')
              .map(int.parse)
              .reduce((a, b) => a + b);
          expect(
            outfield,
            side - 1,
            reason: 'Il modulo $formation non copre ${side - 1} '
                'giocatori di movimento per il formato ${entry.key}',
          );
        }
      }
    });

    test('un modulo non valido per il formato ricade sul default', () {
      // '4-3-3' esiste, ma non per il 5v5.
      expect(normalizeFormation('5v5', '4-3-3'), '1-2-1');
      expect(normalizeFormation('5v5', null), '1-2-1');
      expect(normalizeFormation('11v11', '3-5-2'), '3-5-2');
    });
  });

  group('Slot sul campo', () {
    test('gli slot sono uno per giocatore, portiere incluso', () {
      for (final format in lineupFormations.keys) {
        for (final formation in lineupFormations[format]!) {
          final slots = buildLineupSlots(format, formation);
          expect(
            slots.length,
            lineupSideSize(format),
            reason: '$format $formation',
          );
        }
      }
    });

    test('le chiavi sono quelle accettate dal database', () {
      // Vincolo su match_lineup_players.slot_key: ^(gk|p([1-9]|10))$
      final pattern = RegExp(r'^(gk|p([1-9]|10))$');
      for (final format in lineupFormations.keys) {
        for (final formation in lineupFormations[format]!) {
          final keys = buildLineupSlots(
            format,
            formation,
          ).map((slot) => slot.key).toList();
          expect(keys.first, 'gk');
          expect(keys.toSet().length, keys.length, reason: 'chiavi duplicate');
          for (final key in keys) {
            expect(pattern.hasMatch(key), isTrue, reason: key);
          }
        }
      }
    });

    test('le coordinate restano dentro il rettangolo di gioco', () {
      for (final slot in buildLineupSlots('11v11', '3-5-2')) {
        expect(slot.x, inInclusiveRange(0, 1));
        expect(slot.y, inInclusiveRange(0, 1));
      }
    });

    test('i giocatori di una linea non condividono la stessa x', () {
      // È la condizione che evita i token sovrapposti sul campo.
      final slots = buildLineupSlots('11v11', '3-5-2');
      final midfield = slots.where((slot) => slot.shortRole == 'C').toList();
      expect(midfield.length, 5);
      expect(midfield.map((slot) => slot.x).toSet().length, 5);
    });

    test('i ruoli della difesa a quattro distinguono terzini e centrali', () {
      final roles = buildLineupSlots('11v11', '4-3-3')
          .where((slot) => slot.shortRole == 'D')
          .map((slot) => slot.role)
          .toList();
      expect(roles, [
        'Terzino SX',
        'Dif. centrale',
        'Dif. centrale',
        'Terzino DX',
      ]);
    });
  });

  group('LineupSnapshot', () {
    test('legge il jsonb restituito dalle RPC', () {
      final snapshot = LineupSnapshot.fromRpc({
        'teams': [
          {'team_number': 1, 'formation': '4-3-3', 'captain_user_id': 'abc'},
        ],
        'players': [
          {'user_id': 'abc', 'team_number': 1, 'slot_key': 'p5'},
        ],
      });
      expect(snapshot, isNotNull);
      expect(snapshot!.teams.single['formation'], '4-3-3');
      expect(snapshot.players.single['slot_key'], 'p5');
    });

    test('un payload inatteso non fa saltare la schermata', () {
      expect(LineupSnapshot.fromRpc(null), isNull);
      expect(LineupSnapshot.fromRpc('errore'), isNull);
      final empty = LineupSnapshot.fromRpc(<String, dynamic>{});
      expect(empty!.teams, isEmpty);
      expect(empty.players, isEmpty);
    });
  });

  group('Etichette di lega', () {
    test('il conteggio membri è declinato al singolare', () {
      LeagueSummary league(int members) => LeagueSummary(
        id: 'l',
        name: 'Lega',
        slug: 'lega',
        description: null,
        logoUrl: null,
        city: 'Milano',
        country: 'IT',
        visibility: 'private',
        footballFormat: '5v5',
        maxMembers: 20,
        memberCount: members,
        currentUserRole: 'owner',
      );
      expect(league(1).memberCountLabel, '1 membro');
      expect(league(4).memberCountLabel, '4 membri');
    });

    test('i ruoli di lega sono tradotti', () {
      expect(leagueRoleLabel('owner'), 'Proprietario');
      expect(leagueRoleLabel('admin'), 'Admin');
      expect(leagueRoleLabel('member'), 'Membro');
    });
  });
}
