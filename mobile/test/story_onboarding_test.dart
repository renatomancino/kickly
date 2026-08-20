// Copre due cose distinte: che AppState.completeIntro() scriva davvero il
// flag su disco (non solo in memoria — è quello che decide se il prossimo
// avvio dell'app rimostra la vetrina), e che la vetrina stessa navighi nel
// modo giusto (avanti/indietro col tap, "Comincia"/X in fondo al percorso
// portano al login, il timer avanza da solo ma non oltre l'ultimo passo).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kickly_app/app.dart';
import 'package:kickly_app/core/config/app_config.dart';
import 'package:kickly_app/core/theme/app_theme.dart';
import 'package:kickly_app/data/kickly_repository.dart';
import 'package:kickly_app/features/onboarding/story_onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppState.introSeen', () {
    test(
      'parte false e completeIntro() lo scrive su disco, non solo in memoria',
      () async {
        final appState = AppState(repository: KicklyRepository(client: null));
        expect(appState.introSeen, isFalse);

        await appState.completeIntro();

        expect(appState.introSeen, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('kickly.onboarding.introSeen'), isTrue);
      },
    );
  });

  group('StoryOnboardingPage', () {
    late KicklyRepository repository;
    late AppState appState;
    const config = AppConfig(supabaseUrl: '', supabasePublishableKey: '');

    setUp(() {
      repository = KicklyRepository(client: null);
      appState = AppState(repository: repository);
    });

    Widget host() {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (_, _) => const StoryOnboardingPage(),
          ),
          // Placeholder minimo: qui interessa solo verificare che la vetrina
          // ci abbia portati su /login, non cosa /login mostri davvero.
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

    Future<void> sized(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('mostra il primo passo, senza il pulsante finale', (
      tester,
    ) async {
      await sized(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('PASSO 1'), findsOneWidget);
      expect(find.text('Trova la lega'), findsOneWidget);
      expect(find.text('Comincia'), findsNothing);
    });

    testWidgets('il tap sulla metà destra avanza al passo successivo', (
      tester,
    ) async {
      await sized(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tapAt(const Offset(300, 400));
      await tester.pump();

      expect(find.text('PASSO 2'), findsOneWidget);
      expect(find.text('Rispondi presente'), findsOneWidget);
    });

    testWidgets('il tap sulla metà sinistra del primo passo non fa nulla', (
      tester,
    ) async {
      await sized(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tapAt(const Offset(90, 400));
      await tester.pump();

      expect(find.text('PASSO 1'), findsOneWidget);
    });

    testWidgets('il tap destro torna indietro col tap sinistro', (
      tester,
    ) async {
      await sized(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tapAt(const Offset(300, 400)); // -> passo 2
      await tester.pump();
      await tester.tapAt(const Offset(90, 400)); // <- passo 1
      await tester.pump();

      expect(find.text('PASSO 1'), findsOneWidget);
    });

    testWidgets(
      'sull\'ultimo passo compare "Comincia" e chiude la vetrina segnando introSeen',
      (tester) async {
        await sized(tester);
        await tester.pumpWidget(host());
        await tester.pump();

        await tester.tapAt(const Offset(300, 400)); // -> passo 2
        await tester.pump();
        await tester.tapAt(const Offset(300, 400)); // -> passo 3
        await tester.pump();

        expect(find.text('PASSO 3'), findsOneWidget);
        expect(find.text('Comincia'), findsOneWidget);

        await tester.tap(find.text('Comincia'));
        await tester.pumpAndSettle();

        expect(find.text('pagina di login'), findsOneWidget);
        expect(appState.introSeen, isTrue);
      },
    );

    testWidgets('la X salta la vetrina da qualunque passo e segna introSeen', (
      tester,
    ) async {
      await sized(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('pagina di login'), findsOneWidget);
      expect(appState.introSeen, isTrue);
    });

    testWidgets(
      'il timer avanza da solo dopo la durata del passo, ma non oltre l\'ultimo',
      (tester) async {
        await sized(tester);
        await tester.pumpWidget(host());
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 4300));
        expect(find.text('PASSO 2'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 4300));
        expect(find.text('PASSO 3'), findsOneWidget);

        // Sul terzo passo il segmento si riempie ma non c'è un passo dopo:
        // deve restare fermo lì, con "Comincia" ancora visibile.
        await tester.pump(const Duration(milliseconds: 4300));
        expect(find.text('PASSO 3'), findsOneWidget);
        expect(find.text('Comincia'), findsOneWidget);
      },
    );
  });
}
