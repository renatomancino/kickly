import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
                      if (match.coverImageUrl?.isNotEmpty == true) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CachedNetworkImage(
                            imageUrl: match.coverImageUrl!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              summary.footballFormat.replaceAll('v', ' vs '),
                            ),
                          ),
                          Chip(label: Text(_statusLabel(summary.status))),
                          if (match.fieldBookedAt != null)
                            const Chip(
                              backgroundColor: AppTheme.primary,
                              side: BorderSide.none,
                              avatar: Icon(
                                Icons.verified,
                                size: 16,
                                color: AppTheme.background,
                              ),
                              labelStyle: TextStyle(
                                color: AppTheme.background,
                                fontWeight: FontWeight.w900,
                              ),
                              label: Text('Campo prenotato'),
                            ),
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
    final perPlayer = match.costTotal == null || summary.maxPlayers == 0
        ? null
        : match.costTotal! / summary.maxPlayers;
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
        if (match.venuePhone?.isNotEmpty == true) ...[
          _FieldBookingCard(
            match: match,
            canBook: match.canManage || summary.currentResponse == 'going',
            onBooked: onReload,
          ),
          const SizedBox(height: 14),
        ],
        if (match.venueImageUrl?.isNotEmpty == true) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: match.venueImageUrl!,
              width: double.infinity,
              height: 210,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
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
                    label: 'Quota per giocatore',
                    value:
                        '${perPlayer == null ? '' : '€ ${perPlayer.toStringAsFixed(2)} a persona · '}totale € ${match.costTotal!.toStringAsFixed(2)}',
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

class _FieldBookingCard extends StatefulWidget {
  const _FieldBookingCard({
    required this.match,
    required this.canBook,
    required this.onBooked,
  });

  final MatchDetail match;
  final bool canBook;
  final Future<void> Function() onBooked;

  @override
  State<_FieldBookingCard> createState() => _FieldBookingCardState();
}

class _FieldBookingCardState extends State<_FieldBookingCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final booked = widget.match.fieldBookedAt != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: booked
            ? AppTheme.primary.withValues(alpha: .12)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: booked
              ? AppTheme.primary.withValues(alpha: .55)
              : AppTheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
                child: Icon(booked ? Icons.verified : Icons.stadium_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booked ? 'Campo prenotato' : 'Prenota il campo',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      booked
                          ? 'Prenotazione confermata a tutti i partecipanti.'
                          : widget.canBook
                          ? 'Chiama la struttura e poi conferma la prenotazione.'
                          : 'Disponibile dopo aver confermato la presenza.',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.canBook) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Chiama campo'),
                  ),
                ),
                if (!booked) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _confirm,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all),
                      label: const Text('Conferma'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _call() async {
    final phone = widget.match.venuePhone!;
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il telefono.')),
      );
    }
  }

  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Campo prenotato?'),
        content: const Text(
          'Conferma solo dopo aver parlato con la struttura. Tutti i partecipanti riceveranno una notifica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sì, conferma'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await AppScope.of(context).repository
          .confirmFieldBooking(widget.match.summary.id);
      await widget.onBooked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campo prenotato: partecipanti avvisati.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
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
              _buildPitch(
                teamNumber: teamNumber,
                formation:
                    team?['formation']?.toString() ??
                    _formations(match.summary.footballFormat).first,
                side: side,
                rows: rows,
                captainId: team?['captain_user_id']?.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPitch({
    required int teamNumber,
    required String formation,
    required int side,
    required List<JsonMap> rows,
    required String? captainId,
  }) {
    final positions = _pitchPositions(formation, side);
    final widestLine = formation
        .split('-')
        .map((value) => int.tryParse(value) ?? 1)
        .fold<int>(1, (largest, value) => value > largest ? value : largest);

    return AspectRatio(
      aspectRatio: .68,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tokenWidth = switch (widestLine) {
            >= 5 => 58.0,
            4 => 66.0,
            3 => 78.0,
            _ => 88.0,
          };
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF216536), Color(0xFF174A2A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(painter: const _FootballPitchPainter()),
                  ),
                ),
                Positioned(
                  left: 13,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .34),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'TEAM $teamNumber · $formation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                ...positions.map((position) {
                  final row = rows
                      .where(
                        (item) => item['slot_key']?.toString() == position.slot,
                      )
                      .firstOrNull;
                  final player = row == null
                      ? null
                      : match.participants
                            .where(
                              (item) =>
                                  item.userId == row['user_id']?.toString(),
                            )
                            .firstOrNull;
                  final mine = player?.userId == match.currentUserId;
                  return Positioned(
                    left: constraints.maxWidth * position.x - tokenWidth / 2,
                    top: constraints.maxHeight * position.y - 35,
                    width: tokenWidth,
                    height: 76,
                    child: _PitchPlayer(
                      role: position.role,
                      player: player,
                      mine: mine,
                      captain: player != null && player.userId == captainId,
                      enabled: !busy && player == null,
                      onTap: () => _slot(teamNumber, position.slot),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_PitchPosition> _pitchPositions(String formation, int side) {
    final lines = formation
        .split('-')
        .map((value) => int.tryParse(value) ?? 0)
        .where((value) => value > 0)
        .toList();
    if (lines.fold<int>(0, (sum, value) => sum + value) != side - 1) {
      return [
        const _PitchPosition(slot: 'gk', role: 'Portiere', x: .5, y: .88),
        ...List.generate(
          side - 1,
          (index) => _PitchPosition(
            slot: 'p${index + 1}',
            role: 'Giocatore',
            x: (index % 3 + 1) / 4,
            y: .68 - (index ~/ 3) * .22,
          ),
        ),
      ];
    }

    final positions = <_PitchPosition>[
      const _PitchPosition(slot: 'gk', role: 'Portiere', x: .5, y: .89),
    ];
    var slotNumber = 1;
    final lineY = lines.length == 3
        ? const [.70, .48, .25]
        : lines.length == 1
        ? const [.48]
        : List.generate(
            lines.length,
            (index) => .72 - index * (.48 / (lines.length - 1)),
          );
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final count = lines[lineIndex];
      final roles = _rolesForLine(lineIndex, lines.length, count);
      for (var index = 0; index < count; index++) {
        positions.add(
          _PitchPosition(
            slot: 'p$slotNumber',
            role: roles[index],
            x: (index + 1) / (count + 1),
            y: lineY[lineIndex],
          ),
        );
        slotNumber += 1;
      }
    }
    return positions;
  }

  List<String> _rolesForLine(int line, int totalLines, int count) {
    if (line == 0) {
      return switch (count) {
        1 => const ['Difensore'],
        2 => const ['Terzino SX', 'Terzino DX'],
        3 => const ['Terzino SX', 'Difensore', 'Terzino DX'],
        4 => const [
          'Terzino SX',
          'Dif. centrale',
          'Dif. centrale',
          'Terzino DX',
        ],
        _ => List.generate(count, (index) => 'Difensore ${index + 1}'),
      };
    }
    if (line == totalLines - 1) {
      return switch (count) {
        1 => const ['Punta'],
        2 => const ['Attaccante SX', 'Attaccante DX'],
        3 => const ['Ala SX', 'Punta', 'Ala DX'],
        _ => List.generate(count, (index) => 'Attaccante ${index + 1}'),
      };
    }
    return switch (count) {
      1 => const ['Mediano'],
      2 => const ['Centrocampista SX', 'Centrocampista DX'],
      3 => const ['Esterno SX', 'Mediano', 'Esterno DX'],
      4 => const [
        'Esterno SX',
        'Centrocampista',
        'Centrocampista',
        'Esterno DX',
      ],
      5 => const [
        'Esterno SX',
        'Mezzala SX',
        'Mediano',
        'Mezzala DX',
        'Esterno DX',
      ],
      _ => List.generate(count, (index) => 'Centrocampista ${index + 1}'),
    };
  }

  List<String> _formations(String format) => switch (format) {
    '5v5' => const ['1-2-1', '2-1-1', '1-1-2'],
    '7v7' => const ['2-3-1', '3-2-1', '2-2-2'],
    '8v8' => const ['3-3-1', '2-3-2', '3-2-2'],
    '10v10' => const ['3-4-2', '4-3-2', '4-4-1'],
    _ => const ['4-3-3', '4-4-2', '3-5-2'],
  };
}

class _PitchPosition {
  const _PitchPosition({
    required this.slot,
    required this.role,
    required this.x,
    required this.y,
  });

  final String slot;
  final String role;
  final double x;
  final double y;
}

class _PitchPlayer extends StatelessWidget {
  const _PitchPlayer({
    required this.role,
    required this.player,
    required this.mine,
    required this.captain,
    required this.enabled,
    required this.onTap,
  });

  final String role;
  final MatchParticipant? player;
  final bool mine;
  final bool captain;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = mine ? AppTheme.background : Colors.white;
    return Semantics(
      button: player == null,
      label: player == null
          ? 'Scegli posizione $role'
          : '${player!.displayName}, $role',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: mine
                        ? AppTheme.primary
                        : player == null
                        ? const Color(0xFF173D23).withValues(alpha: .88)
                        : const Color(0xFF101411),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mine
                          ? AppTheme.primary
                          : player == null
                          ? Colors.white70
                          : Colors.white,
                      width: mine ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: player == null
                      ? const Icon(Icons.add, color: Colors.white, size: 22)
                      : player!.avatarUrl?.isNotEmpty == true
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: player!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Icon(
                              Icons.sports_soccer,
                              color: foreground,
                              size: 20,
                            ),
                          ),
                        )
                      : Icon(Icons.sports_soccer, color: foreground, size: 20),
                ),
                if (captain)
                  const Positioned(
                    right: -5,
                    top: -5,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Color(0xFFFFD84D),
                      foregroundColor: Colors.black,
                      child: Text(
                        'C',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: mine
                    ? AppTheme.primary
                    : Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                player?.displayName ?? 'Scegli',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              role.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 7,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootballPitchPainter extends CustomPainter {
  const _FootballPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..color = Colors.white.withValues(alpha: .035);
    for (var index = 0; index < 8; index += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * index / 8, size.width, size.height / 8),
        stripe,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final inset = size.width * .045;
    final field = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(4)),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height / 2),
      Offset(size.width - inset, size.height / 2),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * .13,
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.white.withValues(alpha: .65),
    );

    final penaltyWidth = size.width * .55;
    final penaltyHeight = size.height * .13;
    final smallWidth = size.width * .28;
    final smallHeight = size.height * .055;
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - penaltyWidth) / 2,
        inset,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - penaltyWidth) / 2,
        size.height - inset - penaltyHeight,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - smallWidth) / 2,
        inset,
        smallWidth,
        smallHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - smallWidth) / 2,
        size.height - inset - smallHeight,
        smallWidth,
        smallHeight,
      ),
      line,
    );

    final goalWidth = size.width * .18;
    canvas.drawRect(
      Rect.fromLTWH((size.width - goalWidth) / 2, 1, goalWidth, inset - 1),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - goalWidth) / 2,
        size.height - inset,
        goalWidth,
        inset - 1,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _FootballPitchPainter oldDelegate) => false;
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
