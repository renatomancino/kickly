import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  Future<(List<MatchSummary>, UserProfile?)>? _future;
  String _filter = 'nearby';
  double _radiusKm = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<(List<MatchSummary>, UserProfile?)> _load() async {
    final repository = AppScope.of(context).repository;
    final values = await Future.wait<dynamic>([
      repository.getMatches(),
      repository.getCurrentProfile(),
    ]);
    return (values[0] as List<MatchSummary>, values[1] as UserProfile?);
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
                      'Trova un campo, unisciti e gioca.',
                      style: TextStyle(color: AppTheme.muted),
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
          LayoutBuilder(
            builder: (context, constraints) {
              const filters = {
                'nearby': ('Vicino a me', Icons.near_me_outlined),
                'going': ('Partecipo', Icons.check_circle_outline),
                'league': ('Partite lega', Icons.shield_outlined),
                'past': ('Passate', Icons.history),
              };
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filters.entries.map((entry) {
                  final selected = _filter == entry.key;
                  return SizedBox(
                    width: width,
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(entry.value.$2, size: 17),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          entry.value.$1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_filter == 'nearby') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Raggio',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const Spacer(),
                ...[25.0, 50.0, 100.0].map(
                  (radius) => Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: FilterChip(
                      selected: _radiusKm == radius,
                      showCheckmark: false,
                      label: Text('${radius.toInt()} km'),
                      onSelected: (_) => setState(() => _radiusKm = radius),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FutureBuilder<(List<MatchSummary>, UserProfile?)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // Column e non ListSkeleton: qui siamo già dentro una
                // ListView, annidare uno scroll romperebbe il gesto.
                return const Column(
                  children: [
                    CardSkeleton(),
                    SizedBox(height: 12),
                    CardSkeleton(),
                  ],
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
              final data = snapshot.data;
              final allMatches = data?.$1 ?? const <MatchSummary>[];
              final profile = data?.$2;
              if (_filter == 'nearby' &&
                  (profile?.latitude == null || profile?.longitude == null)) {
                return EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Imposta la tua zona',
                  body: 'Seleziona comune e provincia nel profilo per vedere le partite vicine.',
                  action: FilledButton(
                    onPressed: () => context.push('/profile/edit'),
                    child: const Text('Completa località'),
                  ),
                );
              }
              final matches = allMatches.where((match) {
                return switch (_filter) {
                  'nearby' =>
                    !match.isPast &&
                        match.visibility == 'public' &&
                        match.distanceKm != null &&
                        match.distanceKm! <= _radiusKm,
                  'going' => !match.isPast && match.currentResponse == 'going',
                  'league' => !match.isPast && match.isLeagueMember,
                  'past' => match.isPast && match.currentResponse == 'going',
                  _ => false,
                };
              }).toList();
              if (matches.isEmpty) {
                return EmptyState(
                  icon: Icons.event_busy,
                  title: _filter == 'nearby'
                      ? 'Nessuna partita nel raggio'
                      : 'Nessuna partita',
                  body: _filter == 'nearby'
                      ? 'Prova ad aumentare il raggio oppure torna più tardi.'
                      : 'Non ci sono partite in questa sezione.',
                );
              }
              if (_filter == 'past') {
                matches.sort((a, b) => b.startsAt.compareTo(a.startsAt));
              } else if (_filter == 'nearby') {
                matches.sort(
                  (a, b) => (a.distanceKm ?? double.infinity).compareTo(
                    b.distanceKm ?? double.infinity,
                  ),
                );
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
