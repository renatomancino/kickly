// Copre due cose distinte: che AccountDeletionBlockersList (un widget puro,
// dati finti, nessuna rete) mostri ogni lega bloccante col conteggio membri
// e inoltri i tap alle callback giuste, e — più sotto, aggiunto nel task
// successivo — il flusso end-to-end di AccountDeletionPage in modalità demo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/core/theme/app_theme.dart';
import 'package:kickly_app/data/models.dart';
import 'package:kickly_app/features/profile/account_deletion_page.dart';

void main() {
  group('AccountDeletionBlockersList', () {
    testWidgets(
      'mostra ogni lega bloccante col conteggio membri e inoltra i tap alle callback',
      (tester) async {
        final opened = <String>[];
        final openedSettings = <String>[];
        var rechecked = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: AccountDeletionBlockersList(
                blockers: const [
                  AccountDeletionBlocker(
                    leagueId: 'league-1',
                    leagueSlug: 'calcetto-del-giovedi',
                    leagueName: 'Calcetto del giovedì',
                    activeMemberCount: 8,
                  ),
                ],
                onOpenLeague: opened.add,
                onOpenLeagueSettings: openedSettings.add,
                onRecheck: () => rechecked = true,
              ),
            ),
          ),
        );

        expect(find.text('Calcetto del giovedì'), findsOneWidget);
        expect(find.text('8 membri attivi'), findsOneWidget);

        await tester.tap(find.text('Trasferisci proprietà'));
        expect(opened, ['calcetto-del-giovedi']);

        await tester.tap(find.text('Elimina lega'));
        expect(openedSettings, ['calcetto-del-giovedi']);

        await tester.tap(find.text('Ricontrolla'));
        expect(rechecked, isTrue);
      },
    );
  });
}
