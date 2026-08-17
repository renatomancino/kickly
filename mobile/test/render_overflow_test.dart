// Rete di sicurezza contro gli overflow di layout.
//
// Nato come verifica usa-e-getta durante la passata estetica, tenuto perché ha
// subito trovato un bug vero: nella tabella gol/assist del post-partita i due
// contatori sforavano di 4px la loro colonna, perché `IconButton` riserva il
// bersaglio da toccare di Material (48pt) anche quando gli si impone una
// `fixedSize` più piccola. Su un iPhone SE l'utente avrebbe visto le barre
// gialle e nere; qui si vede in tre secondi senza aprire un simulatore.
//
// Le combinazioni non sono casuali: 320 è l'iPhone SE e gli Android piccoli,
// 360 la larghezza Android più diffusa, 430 un iPhone Pro Max, 800 un tablet.
// Il fattore di scala 1.3 simula chi ingrandisce il testo di sistema — è la
// condizione in cui i layout stretti si rompono per primi, ed è anche quella
// che nessuno prova a mano.
//
// Il repository è in modalità demo (`client: null`), quindi i test girano
// senza rete e senza credenziali: è ciò che li rende eseguibili in CI, dove
// le PR da fork non hanno accesso ai secret.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kickly_app/app.dart';
import 'package:kickly_app/core/config/app_config.dart';
import 'package:kickly_app/core/theme/app_theme.dart';
import 'package:kickly_app/data/kickly_repository.dart';
import 'package:kickly_app/features/dashboard/dashboard_page.dart';
import 'package:kickly_app/features/leagues/join_league_page.dart';
import 'package:kickly_app/features/leagues/league_form_page.dart';
import 'package:kickly_app/features/leagues/leagues_page.dart';
import 'package:kickly_app/features/matches/lineup_board.dart';
import 'package:kickly_app/features/matches/matches_page.dart';
import 'package:kickly_app/features/notifications/notifications_page.dart';
import 'package:kickly_app/features/profile/profile_page.dart';
import 'package:kickly_app/features/matches/match_result_page.dart';

void main() {
  // Le schermate formattano date in italiano (`DateFormat(..., 'it_IT')`).
  // In produzione ci pensa main.dart all'avvio; in un test widget nessuno lo
  // fa, e senza questa riga ogni pagina che mostra una data esplode con
  // LocaleDataException prima ancora di essere disegnata.
  setUpAll(() => initializeDateFormatting('it_IT'));

  final repository = KicklyRepository(client: null);
  final appState = AppState(repository: repository);
  const config = AppConfig(supabaseUrl: '', supabasePublishableKey: '');

  Widget host(Widget child, {double textScale = 1}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: AppTheme.dark,
      home: AppScope(
        repository: repository,
        appState: appState,
        config: config,
        child: child,
      ),
    ),
  );

  Future<void> sized(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final size in const [
    Size(320, 900),
    Size(360, 800),
    Size(430, 932),
    Size(800, 1200),
  ]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('result page ${size.width} x$scale', (tester) async {
        await sized(tester, size);
        await tester.pumpWidget(
          host(
            const MatchResultPage(matchId: 'demo-match-1'),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Risultato finale'.toUpperCase()), findsOneWidget);

        // Un gol in più al Team A senza assegnarlo a nessuno: deve comparire
        // l'avviso di discrepanza.
        await tester.tap(find.byTooltip('Un gol in più per il Team A'));
        await tester.pumpAndSettle();
        expect(find.textContaining('non tornano'), findsOneWidget);

        // Scorre fino in fondo: è il modo per far costruire davvero le
        // tabelle gol/assist, che in una ListView pigra restano fuori.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
      });

      // Schermate che si costruiscono senza parametri di rotta: qui basta
      // che vengano disegnate senza sforare. Non c'è nessuna asserzione sul
      // contenuto di proposito — questo file sorveglia il layout, non la
      // logica, e un'asserzione sul testo lo farebbe fallire a ogni ritocco
      // di una stringa.
      for (final page in <(String, Widget)>[
        ('dashboard', const DashboardPage()),
        ('matches', const MatchesPage()),
        ('leagues', const LeaguesPage()),
        ('profile', const ProfilePage()),
        ('notifications', const NotificationsPage()),
        ('join league', const JoinLeaguePage()),
        ('league form', const LeagueFormPage()),
      ]) {
        testWidgets('${page.$1} ${size.width} x$scale', (tester) async {
          await sized(tester, size);
          // Dentro a uno Scaffold: nell'app queste pagine sono figlie di
          // AppShell, che gliene fornisce uno. Montate nude, i loro InkWell
          // non trovano un Material sopra di sé e falliscono per un motivo
          // che non ha niente a che vedere con il layout.
          await tester.pumpWidget(
            host(Scaffold(body: page.$2), textScale: scale),
          );
          await tester.pumpAndSettle();
        });
      }

      testWidgets('lineup board ${size.width} x$scale', (tester) async {
        await sized(tester, size);
        final match = await repository.getMatch('demo-match-1');
        await tester.pumpWidget(
          host(
            Scaffold(body: LineupBoard(match: match!)),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('MODULO'), findsWidgets);
      });
    }
  }
}
