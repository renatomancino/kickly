import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class LeaguesPage extends StatefulWidget {
  const LeaguesPage({super.key});

  @override
  State<LeaguesPage> createState() => _LeaguesPageState();
}

class _LeaguesPageState extends State<LeaguesPage> {
  Future<List<LeagueSummary>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getLeagues();
  }

  Future<void> _refresh() async {
    final next = AppScope.of(context).repository.getLeagues();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le tue leghe',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Squadre, calendario e rivalità.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                onSelected: (value) => context.push(value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: '/leagues/new',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Crea lega'),
                    ),
                  ),
                  PopupMenuItem(
                    value: '/leagues/join',
                    child: ListTile(
                      leading: Icon(Icons.login),
                      title: Text('Usa invito'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<LeagueSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // Column e non ListSkeleton: siamo già dentro una ListView.
                return const Column(
                  children: [
                    CardSkeleton(height: 70, lines: 2),
                    SizedBox(height: 12),
                    CardSkeleton(height: 70, lines: 2),
                  ],
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Leghe non disponibili',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _refresh,
                    child: const Text('Riprova'),
                  ),
                );
              }
              final leagues = snapshot.data ?? const [];
              if (leagues.isEmpty) {
                return EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Crea il tuo spogliatoio',
                  body: 'Avvia una lega o inserisci il codice ricevuto da un admin.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/leagues/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crea una lega'),
                  ),
                );
              }
              return Column(
                children: leagues
                    .map(
                      (league) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            onTap: () =>
                                context.push('/leagues/${league.slug}'),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(17),
                              child: Row(
                                children: [
                                  LeagueLogo(league: league, size: 62),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          league.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${league.city}, ${league.country}',
                                          style: const TextStyle(
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 7,
                                          children: [
                                            Chip(
                                              label: Text(
                                                league.footballFormat,
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                league.memberCountLabel,
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                league.roleLabel,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
