import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/kickly_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<KicklyNotification>>? _future;
  AppState? _appState;
  int _seenRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getNotifications();
    final state = AppScope.of(context).appState;
    if (!identical(_appState, state)) {
      _appState?.removeListener(_onNotification);
      _appState = state;
      _seenRevision = state.notificationRevision;
      state.addListener(_onNotification);
    }
  }

  void _onNotification() {
    final state = _appState!;
    if (state.notificationRevision == _seenRevision) return;
    _seenRevision = state.notificationRevision;
    _reload();
  }

  @override
  void dispose() {
    _appState?.removeListener(_onNotification);
    super.dispose();
  }

  Future<void> _reload() async {
    // Chiamata anche da _markAll() dopo un await di rete: senza questo
    // controllo, se l'utente lascia la pagina mentre "Leggi tutte" è in
    // corso, AppScope.of(context) qui sotto leggerebbe un context non più
    // valido.
    if (!mounted) return;
    final next = AppScope.of(context).repository.getNotifications();
    // Blocco, non arrow-expression: `() => _future = next` come closure
    // farebbe ritornare a setState() il valore dell'assegnamento, cioè la
    // Future stessa. setState() se ne accorge in debug e lancia *dopo* aver
    // già assegnato il campo ma *prima* di schedulare il rebuild, quindi il
    // resto della funzione (l'`await next` sotto) non gira più: la pagina
    // restava agganciata alla vecchia Future finché qualcos'altro non la
    // ricostruiva per altri motivi.
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _open(KicklyNotification notification) async {
    if (notification.readAt == null) {
      await AppScope.of(context).repository
          .markNotificationRead(notification.id);
    }
    if (!mounted) return;
    final link = notification.link;
    if (link != null && link.startsWith('/')) {
      context.push(link);
    } else {
      await _reload();
    }
  }

  Future<void> _markAll() async {
    await AppScope.of(context).repository.markAllNotificationsRead();
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Leggi tutte')),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<KicklyNotification>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ListSkeleton(items: 3);
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Notifiche non disponibili',
                      body: friendlyError(snapshot.error!),
                      action: FilledButton(
                        onPressed: _reload,
                        child: const Text('Riprova'),
                      ),
                    ),
                  ],
                );
              }
              final notifications = snapshot.data ?? const [];
              if (notifications.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    EmptyState(
                      icon: Icons.notifications_none,
                      title: 'Tutto tranquillo',
                      body: 'Le novità su partite e leghe appariranno qui.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  final unread = item.readAt == null;
                  return Card(
                    child: InkWell(
                      onTap: () => _open(item),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: unread
                                  ? AppTheme.primary.withValues(alpha: .15)
                                  : AppTheme.surfaceHigh,
                              child: Icon(
                                _iconFor(item.type),
                                color: unread
                                    ? AppTheme.primary
                                    : AppTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.w900
                                                : FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (unread)
                                        const CircleAvatar(
                                          radius: 4,
                                          backgroundColor: AppTheme.primary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat(
                                      'd MMM · HH:mm',
                                      'it_IT',
                                    ).format(item.createdAt),
                                    style: const TextStyle(
                                      color: AppTheme.mutedSoft,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String type) {
  if (type.contains('match') || type == 'reminder') return Icons.sports_soccer;
  if (type.contains('mvp')) return Icons.emoji_events_outlined;
  if (type.contains('rating')) return Icons.trending_up;
  if (type.contains('league')) return Icons.shield_outlined;
  return Icons.notifications_outlined;
}
