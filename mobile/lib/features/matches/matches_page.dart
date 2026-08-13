import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  Future<List<MatchSummary>>? _future;
  int _filter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getMatches();
  }

  Future<void> _refresh() async {
    final next = AppScope.of(context).repository.getMatches();
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
                      'Partite',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Il tuo calendario Kickly.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => context.push('/matches/new'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Tutte')),
              ButtonSegment(value: 1, label: Text('Prossime')),
              ButtonSegment(value: 2, label: Text('Passate')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<MatchSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Partite non disponibili',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _refresh,
                    child: const Text('Riprova'),
                  ),
                );
              }
              final matches = (snapshot.data ?? const [])
                  .where(
                    (match) =>
                        _filter == 0 ||
                        (_filter == 1 ? !match.isPast : match.isPast),
                  )
                  .toList();
              if (matches.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_busy,
                  title: 'Nessuna partita',
                  body: 'Non ci sono partite in questa sezione.',
                );
              }
              if (_filter == 2) {
                matches.sort((a, b) => b.startsAt.compareTo(a.startsAt));
              }
              return Column(
                children: matches
                    .map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: MatchCard(
                          match: match,
                          onTap: () => context.push('/matches/${match.id}'),
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
