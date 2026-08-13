import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/kickly_repository.dart';
import 'features/auth/auth_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/leagues/league_detail_page.dart';
import 'features/leagues/league_form_page.dart';
import 'features/leagues/leagues_page.dart';
import 'features/leagues/join_league_page.dart';
import 'features/matches/match_detail_page.dart';
import 'features/matches/match_form_page.dart';
import 'features/matches/matches_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/profile/profile_page.dart';
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
  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: widget.appState,
    redirect: (context, state) {
      final path = state.uri.path;
      final authPath =
          path == '/login' || path == '/signup' || path == '/forgot-password';
      if (widget.appState.initializing) {
        return path == '/splash' ? null : '/splash';
      }
      if (!widget.appState.isSignedIn) return authPath ? null : '/login';
      if (!widget.appState.onboardingComplete) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (authPath ||
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
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/leagues', builder: (_, _) => const LeaguesPage()),
          GoRoute(path: '/matches', builder: (_, _) => const MatchesPage()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(path: '/leagues/new', builder: (_, _) => const LeagueFormPage()),
      GoRoute(path: '/leagues/join', builder: (_, _) => const JoinLeaguePage()),
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
