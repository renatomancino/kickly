// Copre due cose distinte: che AccountDeletionBlockersList (un widget puro,
// dati finti, nessuna rete) mostri ogni lega bloccante col conteggio membri
// e inoltri i tap alle callback giuste, e — più sotto, aggiunto nel task
// successivo — il flusso end-to-end di AccountDeletionPage in modalità demo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kickly_app/app.dart';
import 'package:kickly_app/core/config/app_config.dart';
import 'package:kickly_app/core/theme/app_theme.dart';
import 'package:kickly_app/data/kickly_repository.dart';
import 'package:kickly_app/data/models.dart';
import 'package:kickly_app/features/profile/account_deletion_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('AccountDeletionPage (modalità demo, nessuna lega bloccante)', () {
    late KicklyRepository repository;
    late AppState appState;
    const config = AppConfig(supabaseUrl: '', supabasePublishableKey: '');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = KicklyRepository(client: null);
      appState = AppState(repository: repository);
      await appState.startDemo();
    });

    Widget host() {
      final router = GoRouter(
        initialLocation: '/profile/delete-account',
        // Come in app.dart: senza refreshListenable il redirect sotto viene
        // valutato solo alla navigazione esplicita, non quando
        // AppState.signOut() chiama notifyListeners(). Il vero flusso da
        // testare è proprio quel redirect automatico (nessun context.go
        // manuale in AccountDeletionPage), quindi va agganciato anche qui.
        refreshListenable: appState,
        // Solo la regola di redirect che serve a questo test: se l'utente
        // non è più autenticato, vai al login. Il router vero (app.dart) ne
        // ha molte altre (onboarding, vetrina, ecc.) irrilevanti qui.
        redirect: (context, state) => appState.isSignedIn ? null : '/login',
        routes: [
          GoRoute(
            path: '/profile/delete-account',
            builder: (_, _) => const AccountDeletionPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('pagina di login')),
          ),
        ],
      );
      return AppScope(
        repository: repository,
        appState: appState,
        config: config,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
    }

    testWidgets(
      'il pulsante "Elimina" resta disattivato finché non si digita ESATTAMENTE "ELIMINA"',
      (tester) async {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Elimina il mio account'));
        await tester.pumpAndSettle();

        final confirmButton = find.widgetWithText(FilledButton, 'Elimina');
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'elimina');
        await tester.pump();
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'ELIMINA');
        await tester.pump();
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
      },
    );

    testWidgets(
      'confermare chiude la sessione demo e il router porta al login',
      (tester) async {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Elimina il mio account'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ELIMINA');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
        await tester.pumpAndSettle();

        expect(find.text('pagina di login'), findsOneWidget);
        expect(appState.isSignedIn, isFalse);
      },
    );
  });
}
