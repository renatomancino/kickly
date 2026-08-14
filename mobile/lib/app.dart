import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/kickly_repository.dart';
import 'features/auth/auth_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/leagues/league_detail_page.dart';
import 'features/leagues/league_form_page.dart';
import 'features/leagues/league_settings_page.dart';
import 'features/leagues/leagues_page.dart';
import 'features/leagues/join_league_page.dart';
import 'features/matches/match_detail_page.dart';
import 'features/matches/match_form_page.dart';
import 'features/matches/match_result_page.dart';
import 'features/matches/matches_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_editor_page.dart';
import 'features/profile/player_profile_page.dart';
import 'features/shell/app_shell.dart';

class KicklyApp extends StatefulWidget {
  const KicklyApp({
    super.key,
    required this.appState,
    required this.repository,
    required this.config,
  });

  final AppState appState;
  final KicklyRepository repository;
  final AppConfig config;

  @override
  State<KicklyApp> createState() => _KicklyAppState();
}

class _KicklyAppState extends State<KicklyApp> {
  @override
  void initState() {
    super.initState();
    // Il tap su una notifica di sistema porta al link della notifica (es.
    // /matches/<id>). Il router esiste solo da qui in poi, quindi il servizio
    // tiene da parte il link di lancio e ce lo consegna adesso.
    NotificationService.instance.bindNavigation(_openNotificationLink);
  }

  /// Apre il link di una notifica, ma solo a sessione pronta: se l'utente non
  /// ha ancora fatto login il redirect del router lo rimanderebbe comunque
  /// alla schermata di accesso.
  void _openNotificationLink(String link) {
    if (!link.startsWith('/')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.appState.isSignedIn) return;
      _router.push(link);
    });
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: widget.appState,
    redirect: (context, state) {
      final path = state.uri.path;
      final authPath =
          path == '/login' ||
          path == '/signup' ||
          path == '/forgot-password' ||
          path == '/update-password';
      if (widget.appState.initializing) {
        return path == '/splash' ? null : '/splash';
      }
      if (!widget.appState.isSignedIn) return authPath ? null : '/login';
      if (!widget.appState.onboardingComplete) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if ((authPath && path != '/update-password') ||
          path == '/splash' ||
          path == '/onboarding' ||
          path == '/') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthPage(variant: AuthVariant.login),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const AuthPage(variant: AuthVariant.signup),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const AuthPage(variant: AuthVariant.forgot),
      ),
      GoRoute(
        path: '/update-password',
        builder: (_, _) => const AuthPage(variant: AuthVariant.updatePassword),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const ProfileEditorPage(onboarding: true),
      ),
      // StatefulShellRoute (non ShellRoute) tiene un Navigator/stack separato
      // per ognuna delle 4 tab e le mantiene tutte vive in un IndexedStack:
      // cambiare tab è uno swap istantaneo, senza transizione di pagina né
      // ricostruzione dello State. Con il vecchio ShellRoute ogni tap sulla
      // bottom bar era una normale navigazione (route diversa -> pagina
      // ricreata da zero, FutureBuilder che rifetcha, scroll perso, e
      // un'animazione di push/pop che sulle tab non ha senso) — quella era la
      // causa della sensazione di "pagina vecchia che resta lì" segnalata
      // dall'utente durante il cambio tab.
      // Rami dichiarati nello stesso ordine visivo della bottom bar (Home,
      // Partite, Leghe, Profilo): l'indice del branch coincide direttamente
      // con l'indice mostrato in _KicklyBottomBar, niente più remap a mano.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/matches', builder: (_, _) => const MatchesPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/leagues', builder: (_, _) => const LeaguesPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditorPage(),
      ),
      GoRoute(
        path: '/player/:username',
        builder: (_, state) =>
            PlayerProfilePage(username: state.pathParameters['username']!),
      ),
      GoRoute(path: '/leagues/new', builder: (_, _) => const LeagueFormPage()),
      GoRoute(
        path: '/leagues/:slug/settings',
        builder: (_, state) =>
            LeagueSettingsPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/leagues/join', builder: (_, _) => const JoinLeaguePage()),
      GoRoute(
        path: '/join/:code',
        builder: (_, state) =>
            JoinLeaguePage(initialCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/leagues/:slug',
        builder: (_, state) =>
            LeagueDetailPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/matches/new',
        builder: (_, state) =>
            MatchFormPage(initialLeagueId: state.uri.queryParameters['league']),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (_, state) =>
            MatchDetailPage(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/edit',
        builder: (_, state) =>
            MatchFormPage(matchId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/matches/:id/manage-result',
        builder: (_, state) =>
            MatchResultPage(matchId: state.pathParameters['id']!),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: widget.repository,
      appState: widget.appState,
      config: widget.config,
      child: MaterialApp.router(
        title: 'Kickly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            // Il font di sistema può essere ingrandito fino al 200%: oltre
            // 1.3x le card con altezze fisse (tessere statistiche, token del
            // campo, barra di navigazione) vanno in overflow. Limitiamo la
            // scala invece di lasciare che la UI si rompa, mantenendo comunque
            // un ingrandimento utile per chi ne ha bisogno.
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: .85,
                maxScaleFactor: 1.3,
              ),
            ),
            // L'alone verde sta dietro a ogni schermata, comprese quelle
            // spinte sopra la shell.
            child: KicklyBackdrop(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.appState,
    required this.config,
    required super.child,
  });

  final KicklyRepository repository;
  final AppState appState;
  final AppConfig config;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope non trovato.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KicklyMark(size: 72),
            SizedBox(height: 22),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class KicklyMark extends StatelessWidget {
  const KicklyMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      alignment: Alignment.center,
      child: Text(
        'K',
        style: TextStyle(
          color: AppTheme.background,
          fontWeight: FontWeight.w900,
          fontSize: size * .52,
          height: 1,
        ),
      ),
    );
  }
}
