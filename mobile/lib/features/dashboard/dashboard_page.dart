import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getDashboard();
  }

  Future<void> _refresh() async {
    final next = AppScope.of(context).repository.getDashboard();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Home non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: _refresh,
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Row(
                children: [
                  PlayerAvatar(
                    name: data.profile.displayName,
                    url: data.profile.avatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BENTORNATO IN CAMPO',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        Text(
                          data.profile.firstName ?? data.profile.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Badge(
                    isLabelVisible: data.unreadNotifications > 0,
                    label: Text('${data.unreadNotifications}'),
                    child: IconButton.filledTonal(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_none),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const SectionTitle(
                eyebrow: 'Next up',
                title: 'La prossima partita',
              ),
              const SizedBox(height: 12),
              if (data.nextMatch == null)
                EmptyState(
                  icon: Icons.event_available,
                  title: 'Il calendario è libero',
                  body: 'Quando un admin crea una partita, la troverai subito qui.',
                )
              else
                _HeroMatch(match: data.nextMatch!),
              const SizedBox(height: 27),
              const SectionTitle(
                eyebrow: 'La tua stagione',
                title: 'Numeri in campo',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 122,
                child: GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 9,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatTile(
                      label: 'Partite',
                      value: data.stats.matches,
                      icon: Icons.sports_soccer,
                    ),
                    StatTile(
                      label: 'Gol',
                      value: data.stats.goals,
                      icon: Icons.sports_score,
                    ),
                    StatTile(
                      label: 'Assist',
                      value: data.stats.assists,
                      icon: Icons.assistant_direction,
                    ),
                    StatTile(
                      label: 'MVP',
                      value: data.stats.mvp,
                      icon: Icons.emoji_events_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 27),
              SectionTitle(
                eyebrow: 'Community',
                title: 'Le tue leghe',
                trailing: TextButton(
                  onPressed: () => context.go('/leagues'),
                  child: const Text('Vedi tutte'),
                ),
              ),
              const SizedBox(height: 12),
              if (data.leagues.isEmpty)
                EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Nessuna lega',
                  body: 'Creane una o unisciti con un codice invito.',
                  action: FilledButton(
                    onPressed: () => context.push('/leagues/join'),
                    child: const Text('Unisciti a una lega'),
                  ),
                )
              else
                ...data.leagues.map(
                  (league) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        onTap: () => context.push('/leagues/${league.slug}'),
                        contentPadding: const EdgeInsets.all(13),
                        leading: LeagueLogo(league: league),
                        title: Text(
                          league.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${league.city} · ${league.memberCount} membri · ${league.footballFormat}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroMatch extends StatelessWidget {
  const _HeroMatch({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('dd').format(match.startsAt);
    final month = DateFormat(
      'MMM',
      'it_IT',
    ).format(match.startsAt).toUpperCase();
    return Card(
      child: InkWell(
        onTap: () => context.push('/matches/${match.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: .13),
                Colors.transparent,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          month,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                match.footballFormat.replaceAll('v', ' vs '),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('HH:mm').format(match.startsAt),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.leagueName,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(match.locationName)),
                  Text(
                    '${match.goingCount}/${match.maxPlayers}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (match.goingCount / match.maxPlayers).clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
