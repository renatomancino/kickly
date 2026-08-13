import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class MatchDetailPage extends StatefulWidget {
  const MatchDetailPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  Future<MatchDetail?>? _future;
  bool _responding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getMatch(widget.matchId);
  }

  Future<void> _reload() async {
    final next = AppScope.of(context).repository.getMatch(widget.matchId);
    setState(() => _future = next);
    await next;
  }

  Future<void> _respond(String response) async {
    setState(() => _responding = true);
    try {
      await AppScope.of(context).repository
          .setMatchResponse(widget.matchId, response);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Risposta aggiornata.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partita')),
      body: SafeArea(
        child: FutureBuilder<MatchDetail?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return PageFrame(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Partita non disponibile',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _reload,
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
                  body: 'Potresti non avere accesso a questo evento.',
                ),
              );
            }
            return _MatchContent(
              match: match,
              responding: _responding,
              onRespond: _respond,
              onReload: _reload,
            );
          },
        ),
      ),
    );
  }
}

class _MatchContent extends StatelessWidget {
  const _MatchContent({
    required this.match,
    required this.responding,
    required this.onRespond,
    required this.onReload,
  });

  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final summary = match.summary;
    final date = DateFormat('EEEE d MMMM y', 'it_IT').format(summary.startsAt);
    final time = DateFormat('HH:mm').format(summary.startsAt);
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 7, 20, 18),
              child: Card(
                child: Container(
                  padding: const EdgeInsets.all(21),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: .12),
                        Colors.transparent,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              summary.footballFormat.replaceAll('v', ' vs '),
                            ),
                          ),
                          Chip(label: Text(_statusLabel(summary.status))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        summary.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.leagueName,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.event, color: AppTheme.primary),
                          const SizedBox(width: 9),
                          Expanded(child: Text(date)),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(child: Text(summary.locationName)),
                        ],
                      ),
                      const SizedBox(height: 19),
                      LinearProgressIndicator(
                        value: (summary.goingCount / summary.maxPlayers).clamp(
                          0,
                          1,
                        ),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${summary.goingCount}/${summary.maxPlayers} confermati',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverPersistentHeader(
            pinned: true,
            delegate: _MatchTabDelegate(
              TabBar(
                tabs: [
                  Tab(text: 'Dettagli'),
                  Tab(text: 'Giocatori'),
                  Tab(text: 'Formazione'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _DetailsTab(
              match: match,
              responding: responding,
              onRespond: onRespond,
              onReload: onReload,
            ),
            _PlayersTab(participants: match.participants),
            _InteractiveLineupTab(match: match),
          ],
        ),
      ),
    );
  }
}

class _MatchTabDelegate extends SliverPersistentHeaderDelegate {
  const _MatchTabDelegate(this.tabBar);
  final TabBar tabBar;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: AppTheme.background, child: tabBar);
  @override
  bool shouldRebuild(_MatchTabDelegate oldDelegate) => false;
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.match,
    required this.responding,
    required this.onRespond,
    required this.onReload,
  });
  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final summary = match.summary;
    final perPlayer = match.costTotal == null || summary.goingCount == 0
        ? null
        : match.costTotal! / summary.goingCount;
    final isOpen = summary.status == 'open' || summary.status == 'full';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!summary.isLeagueMember && summary.visibility == 'public') ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partita pubblica',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Entra nella lega per confermare la presenza e scegliere la formazione.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _joinPublic(context),
                      child: const Text('Entra nella lega'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PostGameStats(match: match),
          const SizedBox(height: 18),
        ],
        if (match.postGame != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'RISULTATO FINALE',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${match.postGame!.teamAScore} – ${match.postGame!.teamBScore}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Team A   ·   Team B',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const Divider(height: 28),
                  if (match.postGame!.mvpFinalizedAt != null) ...[
                    const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFFFD166),
                      size: 30,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _mvpName(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'MVP della partita',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ] else ...[
                    const Text(
                      'VOTA L’MVP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      alignment: WrapAlignment.center,
                      children: match.participants
                          .where((p) => p.response == 'going')
                          .map(
                            (player) => ChoiceChip(
                              selected:
                                  match.postGame!.ownVotePlayerId ==
                                  player.userId,
                              onSelected: (_) => _vote(context, player.userId),
                              label: Text(player.displayName),
                            ),
                          )
                          .toList(),
                    ),
                    if (match.canManage) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _finalizeMvp(context),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Chiudi votazione MVP'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (match.canManage) ...[
          const SectionTitle(
            title: 'Gestione partita',
            eyebrow: 'Strumenti admin',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/matches/${summary.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica'),
              ),
              OutlinedButton.icon(
                onPressed: () => _reminder(context),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Promemoria'),
              ),
              OutlinedButton.icon(
                onPressed: () => _adminAction(
                  context,
                  summary.registrationClosedAt == null ? 'close' : 'reopen',
                ),
                icon: Icon(
                  summary.registrationClosedAt == null
                      ? Icons.lock_outline
                      : Icons.lock_open,
                ),
                label: Text(
                  summary.registrationClosedAt == null
                      ? 'Chiudi iscrizioni'
                      : 'Riapri',
                ),
              ),
              if (summary.status != 'completed')
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/matches/${summary.id}/manage-result'),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Chiudi partita'),
                ),
              if (summary.status == 'completed')
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/matches/${summary.id}/manage-result'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Correggi risultato'),
                ),
              if (summary.status != 'completed' &&
                  summary.status != 'cancelled')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _adminAction(context, 'cancel'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annulla partita'),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (isOpen && summary.isLeagueMember) ...[
          const SectionTitle(title: 'Ci sarai?', eyebrow: 'Conferma presenza'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ResponseButton(
                  label: 'Ci sono',
                  icon: Icons.check_circle_outline,
                  selected: summary.currentResponse == 'going',
                  onTap: responding ? null : () => onRespond('going'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResponseButton(
                  label: 'Forse',
                  icon: Icons.help_outline,
                  selected: summary.currentResponse == 'maybe',
                  onTap: responding ? null : () => onRespond('maybe'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResponseButton(
                  label: 'Non posso',
                  icon: Icons.cancel_outlined,
                  selected: summary.currentResponse == 'not_going',
                  onTap: responding ? null : () => onRespond('not_going'),
                ),
              ),
            ],
          ),
          if (responding)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 24),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informazioni',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (match.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    match.description!,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
                const Divider(height: 30),
                _Info(
                  icon: Icons.place_outlined,
                  label: 'Indirizzo',
                  value:
                      match.address ??
                      '${summary.locationName}, ${summary.city}',
                ),
                if (match.costTotal != null) ...[
                  const Divider(height: 30),
                  _Info(
                    icon: Icons.payments_outlined,
                    label: 'Costo campo',
                    value:
                        '€ ${match.costTotal!.toStringAsFixed(2)}${perPlayer == null ? '' : ' · circa € ${perPlayer.toStringAsFixed(2)} a testa'}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _adminAction(BuildContext context, String action) async {
    try {
      await AppScope.of(context).repository
          .setMatchAdminState(match.summary.id, action);
      await onReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _joinPublic(BuildContext context) async {
    try {
      await AppScope.of(context).repository
          .joinPublicLeague(match.summary.leagueId);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  String _mvpName() {
    final winnerId = match.postGame!.playerStats
        .where((row) => row['is_mvp'] == true)
        .map((row) => row['user_id']?.toString())
        .firstOrNull;
    return match.participants
            .where((player) => player.userId == winnerId)
            .map((player) => player.displayName)
            .firstOrNull ??
        'MVP';
  }

  Future<void> _vote(BuildContext context, String playerId) async {
    try {
      await AppScope.of(context).repository
          .castMvpVote(match.summary.id, playerId);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _finalizeMvp(BuildContext context) async {
    try {
      await AppScope.of(context).repository.finalizeMvp(match.summary.id);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _reminder(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Ricordati di confermare la presenza per ${match.summary.title}.',
    );
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invia promemoria'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Messaggio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().length < 3 || !context.mounted) return;
    try {
      final count = await AppScope.of(context).repository
          .sendMatchReminder(match.summary.id, body);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promemoria inviato a $count giocatori.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _PostGameStats extends StatelessWidget {
  const _PostGameStats({required this.match});
  final MatchDetail match;
  @override
  Widget build(BuildContext context) {
    final stats = match.postGame!.playerStats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prestazioni', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...stats.map((row) {
              final player = match.participants
                  .where((p) => p.userId == row['user_id']?.toString())
                  .firstOrNull;
              final delta = asDouble(row['rating_delta']);
              return ListTile(
                onTap: player == null
                    ? null
                    : () => context.push('/player/${player.username}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: PlayerAvatar(
                  name: player?.displayName ?? 'Giocatore',
                  url: player?.avatarUrl,
                  radius: 18,
                ),
                title: Text(
                  player?.displayName ?? 'Giocatore',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${asInt(row['goals'])} gol · ${asInt(row['assists'])} assist · voto ${row['match_rating'] ?? '—'}',
                ),
                trailing: Text(
                  delta == 0
                      ? '—'
                      : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: delta >= 0 ? AppTheme.primary : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: .14)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.outline,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? AppTheme.primary : Colors.white60),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? AppTheme.primary : Colors.white70,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppTheme.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.participants});
  final List<MatchParticipant> participants;
  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]
      ..sort((a, b) {
        const order = {'going': 0, 'waitlist': 1, 'maybe': 2, 'not_going': 3};
        return (order[a.response] ?? 9).compareTo(order[b.response] ?? 9);
      });
    if (sorted.isEmpty) {
      return const PageFrame(
        child: EmptyState(
          icon: Icons.group_outlined,
          title: 'Nessuna risposta',
          body: 'I giocatori appariranno qui dopo la prima conferma.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final player = sorted[index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/player/${player.username}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: PlayerAvatar(
              name: player.displayName,
              url: player.avatarUrl,
            ),
            title: Text(
              player.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('@${player.username} · ${player.overall} OVR'),
            trailing: Chip(label: Text(_responseLabel(player.response))),
          ),
        );
      },
    );
  }
}

// Kept as a compact read-only fallback for narrow embedded contexts.
// ignore: unused_element
class _LineupTab extends StatelessWidget {
  const _LineupTab({required this.match});
  final MatchDetail match;
  @override
  Widget build(BuildContext context) {
    if (match.lineupPlayers.isEmpty) {
      return const PageFrame(
        child: EmptyState(
          icon: Icons.schema_outlined,
          title: 'Formazione libera',
          body: 'La formazione non è stata ancora configurata.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [1, 2].map((teamNumber) {
        final team = match.lineupTeams
            .where((row) => asInt(row['team_number']) == teamNumber)
            .firstOrNull;
        final playerRows = match.lineupPlayers
            .where((row) => asInt(row['team_number']) == teamNumber)
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Squadra $teamNumber',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Chip(label: Text(team?['formation']?.toString() ?? '—')),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ...playerRows.map((row) {
                    final player = match.participants
                        .where(
                          (item) => item.userId == row['user_id'].toString(),
                        )
                        .firstOrNull;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: PlayerAvatar(
                        name: player?.displayName ?? 'Giocatore',
                        url: player?.avatarUrl,
                        radius: 18,
                      ),
                      title: Text(player?.displayName ?? 'Giocatore'),
                      subtitle: Text(row['slot_key']?.toString() ?? ''),
                      trailing:
                          team?['captain_user_id']?.toString() == player?.userId
                          ? const Icon(Icons.star, color: AppTheme.primary)
                          : null,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InteractiveLineupTab extends StatefulWidget {
  const _InteractiveLineupTab({required this.match});
  final MatchDetail match;
  @override
  State<_InteractiveLineupTab> createState() => _InteractiveLineupTabState();
}

class _InteractiveLineupTabState extends State<_InteractiveLineupTab> {
  late MatchDetail match = widget.match;
  bool busy = false;

  Future<void> _slot(int team, String slot) async {
    setState(() => busy = true);
    final repository = AppScope.of(context).repository;
    try {
      await repository.setLineupSlot(match.summary.id, team, slot);
      final next = await repository.getMatch(match.summary.id);
      if (next != null && mounted) setState(() => match = next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _leave() async {
    setState(() => busy = true);
    final repository = AppScope.of(context).repository;
    try {
      await repository.leaveLineup(match.summary.id);
      final next = await repository.getMatch(match.summary.id);
      if (next != null && mounted) setState(() => match = next);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _formation(int team, String formation) async {
    setState(() => busy = true);
    final repository = AppScope.of(context).repository;
    try {
      await repository.setLineupFormation(match.summary.id, team, formation);
      final next = await repository.getMatch(match.summary.id);
      if (next != null && mounted) setState(() => match = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Scegli una posizione libera. Puoi cambiare squadra o lasciare la formazione.',
        style: TextStyle(color: Colors.white54, height: 1.45),
      ),
      const SizedBox(height: 12),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 12),
      ...[1, 2].map(_team),
      if (match.lineupPlayers.any(
        (row) => row['user_id']?.toString() == match.currentUserId,
      ))
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : _leave,
            icon: const Icon(Icons.logout),
            label: const Text('Lascia formazione'),
          ),
        ),
    ],
  );

  Widget _team(int teamNumber) {
    final team = match.lineupTeams
        .where((row) => asInt(row['team_number']) == teamNumber)
        .firstOrNull;
    final rows = match.lineupPlayers
        .where((row) => asInt(row['team_number']) == teamNumber)
        .toList();
    final side = asInt(match.summary.footballFormat.split('v').first, 5);
    final canChangeFormation =
        match.canManage ||
        team?['captain_user_id']?.toString() == match.currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Squadra $teamNumber',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (canChangeFormation)
                    PopupMenuButton<String>(
                      onSelected: (value) => _formation(teamNumber, value),
                      itemBuilder: (_) =>
                          _formations(match.summary.footballFormat)
                              .map(
                                (value) => PopupMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      child: Chip(
                        label: Text(team?['formation']?.toString() ?? '—'),
                      ),
                    )
                  else
                    Chip(label: Text(team?['formation']?.toString() ?? '—')),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF173D23),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: side,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final slot = index == 0 ? 'gk' : 'p$index';
                    final row = rows
                        .where((r) => r['slot_key']?.toString() == slot)
                        .firstOrNull;
                    final player = row == null
                        ? null
                        : match.participants
                              .where(
                                (p) => p.userId == row['user_id']?.toString(),
                              )
                              .firstOrNull;
                    final mine = player?.userId == match.currentUserId;
                    return InkWell(
                      onTap: busy || player != null
                          ? null
                          : () => _slot(teamNumber, slot),
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppTheme.primary
                              : Colors.black.withValues(
                                  alpha: player == null ? .18 : .38,
                                ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: player == null
                                ? Colors.white24
                                : (mine ? AppTheme.primary : Colors.white38),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              player == null ? Icons.add : Icons.sports_soccer,
                              size: 18,
                              color: mine ? AppTheme.background : Colors.white,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              player?.displayName ??
                                  (index == 0 ? 'Portiere' : 'Libero'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: mine
                                    ? AppTheme.background
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _formations(String format) => switch (format) {
    '5v5' => const ['1-2-1', '2-1-1', '1-1-2'],
    '7v7' => const ['2-3-1', '3-2-1', '2-2-2'],
    '8v8' => const ['3-3-1', '2-3-2', '3-2-2'],
    '10v10' => const ['3-4-2', '4-3-2', '4-4-1'],
    _ => const ['4-3-3', '4-4-2', '3-5-2'],
  };
}

String _statusLabel(String status) => switch (status) {
  'open' => 'Iscrizioni aperte',
  'full' => 'Completa',
  'completed' => 'Conclusa',
  'cancelled' => 'Annullata',
  _ => status,
};
String _responseLabel(String response) => switch (response) {
  'going' => 'Ci sarà',
  'waitlist' => 'Attesa',
  'maybe' => 'Forse',
  'not_going' => 'Non viene',
  _ => response,
};
