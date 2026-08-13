import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  });

  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;

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
            ),
            _PlayersTab(participants: match.participants),
            _LineupTab(match: match),
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
  });
  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;

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
