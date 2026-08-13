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
                  const KicklyMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bentornato,',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
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
              if (data.lastMatch != null) ...[
                const SizedBox(height: 16),
                _LastMatchCard(match: data.lastMatch!),
              ],
              const SizedBox(height: 27),
              const SectionTitle(
                eyebrow: 'La tua stagione',
                title: 'Numeri in campo',
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 5 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
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
                  Card(
                    color: AppTheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppTheme.background,
                            size: 18,
                          ),
                          const Spacer(),
                          Text(
                            '${data.stats.overall}',
                            style: const TextStyle(
                              color: AppTheme.background,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Overall',
                            style: TextStyle(
                              color: AppTheme.background,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
              const SizedBox(height: 25),
              SectionTitle(
                eyebrow: 'Le tue prossime partite',
                title: 'In programma',
                trailing: TextButton(
                  onPressed: () => context.go('/matches'),
                  child: const Text('Vedi tutte'),
                ),
              ),
              const SizedBox(height: 12),
              if (data.nearby.isEmpty)
                const EmptyState(
                  icon: Icons.event_available,
                  title: 'Nessun altro appuntamento',
                  body: 'Le nuove partite delle tue leghe compariranno qui.',
                )
              else
                ...data.nearby.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MatchCard(
                      match: match,
                      onTap: () => context.push('/matches/${match.id}'),
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

class _LastMatchCard extends StatelessWidget {
  const _LastMatchCard({required this.match});
  final LastMatchSummary match;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => context.push('/matches/${match.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ULTIMA PARTITA',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    match.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    match.leagueName,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '${match.teamAScore} – ${match.teamBScore}',
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: .14),
              child: Text(
                match.result == 'win'
                    ? 'W'
                    : match.result == 'loss'
                    ? 'L'
                    : 'D',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeroMatch extends StatelessWidget {
  const _HeroMatch({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          label: Text(
                            match.footballFormat.replaceAll('v', ' vs '),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          match.leagueName,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          match.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (match.currentResponse == 'going')
                    const Chip(label: Text('• Confermato')),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.schedule, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'EEE dd MMM · HH:mm',
                        'it_IT',
                      ).format(match.startsAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(match.locationName)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.background.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${match.goingCount}/${match.maxPlayers} giocatori',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${match.maxPlayers - match.goingCount} posti',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (match.goingCount / match.maxPlayers).clamp(0, 1),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/matches/${match.id}'),
                  child: const Text('Visualizza partita'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
