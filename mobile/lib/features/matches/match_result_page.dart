import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class MatchResultPage extends StatefulWidget {
  const MatchResultPage({super.key, required this.matchId});
  final String matchId;
  @override
  State<MatchResultPage> createState() => _MatchResultPageState();
}

class _MatchResultPageState extends State<MatchResultPage> {
  Future<MatchDetail?>? _future;
  final Set<String> _teamA = {};
  final Map<String, Map<String, int>> _totals = {};
  int _scoreA = 0;
  int _scoreB = 0;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getMatch(widget.matchId);
  }

  void _initialize(MatchDetail match) {
    if (_initialized) return;
    final confirmed = match.participants
        .where((p) => p.response == 'going')
        .toList();
    final savedA =
        match.postGame?.teams
            .where((team) => asInt(team['team_number']) == 1)
            .expand(
              (team) => (team['player_ids'] as List<dynamic>? ?? const []).map(
                (id) => id.toString(),
              ),
            )
            .toList() ??
        const <String>[];
    _teamA.addAll(
      savedA.isEmpty
          ? confirmed.indexed
                .where((entry) => entry.$1.isEven)
                .map((entry) => entry.$2.userId)
          : savedA,
    );
    for (final player in confirmed) {
      final stats = match.postGame?.playerStats
          .where((row) => row['user_id']?.toString() == player.userId)
          .firstOrNull;
      _totals[player.userId] = {
        'goals': asInt(stats?['goals']),
        'assists': asInt(stats?['assists']),
      };
    }
    _scoreA = match.postGame?.teamAScore ?? 0;
    _scoreB = match.postGame?.teamBScore ?? 0;
    _initialized = true;
  }

  Future<void> _submit(MatchDetail match) async {
    final confirmed = match.participants
        .where((p) => p.response == 'going')
        .toList();
    final teamB = confirmed
        .where((p) => !_teamA.contains(p.userId))
        .map((p) => p.userId)
        .toList();
    if (_teamA.isEmpty || teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assegna almeno un giocatore a ogni squadra.'),
        ),
      );
      return;
    }
    // Riscontro tattile alla conferma: chiudere la partita pubblica il
    // risultato finale a tutti i partecipanti, un momento che merita un
    // piccolo feedback fisico come la pubblicazione di una nuova partita.
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      await AppScope.of(context).repository.finalizeMatch(
        widget.matchId,
        teamA: _teamA.toList(),
        teamB: teamB,
        scoreA: _scoreA,
        scoreB: _scoreB,
        playerTotals: confirmed
            .map(
              (p) => <String, dynamic>{
                'user_id': p.userId,
                ..._totals[p.userId]!,
              },
            )
            .toList(),
      );
      if (mounted) context.go('/matches/${widget.matchId}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post partita')),
    body: FutureBuilder<MatchDetail?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        // Ramo errore separato da "partita non trovata": un fallimento di
        // rete non è la stessa cosa di una partita cancellata/inesistente,
        // e qui merita un "riprova" invece di un vicolo cieco.
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Risultato non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: () => setState(
                  () => _future = AppScope.of(
                    context,
                  ).repository.getMatch(widget.matchId),
                ),
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final match = snapshot.data;
        if (match == null) {
          return const PageFrame(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Partita non trovata',
              body: 'Impossibile gestire il risultato.',
            ),
          );
        }
        _initialize(match);
        final players = match.participants
            .where((p) => p.response == 'going')
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'POST PARTITA',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              match.postGame == null
                  ? 'Chiudi la partita'
                  : 'Modifica risultato',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Assegna squadre, punteggio, goal e assist.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _teamCard(
                    'Team A',
                    players.where((p) => _teamA.contains(p.userId)).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _teamCard(
                    'Team B',
                    players.where((p) => !_teamA.contains(p.userId)).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      'Risultato finale',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _score(
                          'Team A',
                          _scoreA,
                          (v) => setState(() => _scoreA = v),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '–',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _score(
                          'Team B',
                          _scoreB,
                          (v) => setState(() => _scoreB = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Goal e assist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...players.map(
              (player) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _counter(
                        'Gol',
                        _totals[player.userId]!['goals']!,
                        (v) => setState(
                          () => _totals[player.userId]!['goals'] = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _counter(
                        'Assist',
                        _totals[player.userId]!['assists']!,
                        (v) => setState(
                          () => _totals[player.userId]!['assists'] = v,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _submit(match),
                // Stesso pattern di match_form_page.dart: l'icona diventa
                // uno spinner compatto durante il salvataggio, invece di
                // restare ferma mentre il bottone appare bloccato.
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.emoji_events),
                label: Text(
                  match.postGame == null
                      ? 'Chiudi partita'
                      : 'Salva correzione',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _teamCard(String title, List<MatchParticipant> players) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · ${players.length}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...players.map(
            (player) => InkWell(
              onTap: () => setState(
                () => _teamA.contains(player.userId)
                    ? _teamA.remove(player.userId)
                    : _teamA.add(player.userId),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.swap_horiz,
                      size: 17,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _score(String label, int value, ValueChanged<int> change) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
      Row(
        children: [
          IconButton(
            tooltip: 'Diminuisci punteggio $label',
            onPressed: value > 0 ? () => change(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: 'Aumenta punteggio $label',
            onPressed: () => change(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ],
  );

  Widget _counter(String label, int value, ValueChanged<int> change) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Diminuisci $label',
            onPressed: value > 0 ? () => change(value - 1) : null,
            icon: const Icon(Icons.remove, size: 16),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Aumenta $label',
            onPressed: () => change(value + 1),
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    ],
  );
}
