import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class LeagueDetailPage extends StatefulWidget {
  const LeagueDetailPage({super.key, required this.slug});

  final String slug;

  @override
  State<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends State<LeagueDetailPage> {
  Future<
    (
      LeagueDetail?,
      List<MatchSummary>,
      List<LeagueCommunication>,
      List<LeaderboardPlayer>,
    )
  >?
  _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<
    (
      LeagueDetail?,
      List<MatchSummary>,
      List<LeagueCommunication>,
      List<LeaderboardPlayer>,
    )
  >
  _load() async {
    final repository = AppScope.of(context).repository;
    final detail = await repository.getLeague(widget.slug);
    if (detail == null) {
      return (
        null,
        const <MatchSummary>[],
        const <LeagueCommunication>[],
        const <LeaderboardPlayer>[],
      );
    }
    final values = await Future.wait<dynamic>([
      repository.getLeagueMatches(detail.summary),
      repository.getLeagueCommunications(detail.summary.id),
      repository.getLeagueLeaderboard(detail.summary.id),
    ]);
    return (
      detail,
      values[0] as List<MatchSummary>,
      values[1] as List<LeagueCommunication>,
      values[2] as List<LeaderboardPlayer>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lega')),
      body: SafeArea(
        child:
            FutureBuilder<
              (
                LeagueDetail?,
                List<MatchSummary>,
                List<LeagueCommunication>,
                List<LeaderboardPlayer>,
              )
            >(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListSkeleton(items: 2);
                }
                if (snapshot.hasError) {
                  return PageFrame(
                    child: EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Lega non disponibile',
                      body: friendlyError(snapshot.error!),
                      action: FilledButton(
                        onPressed: _refresh,
                        child: const Text('Riprova'),
                      ),
                    ),
                  );
                }
                final detail = snapshot.data?.$1;
                if (detail == null) {
                  return const PageFrame(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'Lega non trovata',
                      body: 'Potresti non avere più accesso a questa lega.',
                    ),
                  );
                }
                return _LeagueContent(
                  detail: detail,
                  matches: snapshot.data!.$2,
                  communications: snapshot.data!.$3,
                  leaders: snapshot.data!.$4,
                  onRefresh: _refresh,
                );
              },
            ),
      ),
    );
  }
}

class _LeagueContent extends StatelessWidget {
  const _LeagueContent({
    required this.detail,
    required this.matches,
    required this.communications,
    required this.leaders,
    required this.onRefresh,
  });

  final LeagueDetail detail;
  final List<MatchSummary> matches;
  final List<LeagueCommunication> communications;
  final List<LeaderboardPlayer> leaders;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final league = detail.summary;
    return DefaultTabController(
      length: 7,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Container(
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.outline),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: .10),
                      AppTheme.surface,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LeagueLogo(league: league, size: 76),
                        const SizedBox(width: 17),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 7,
                                children: [
                                  Chip(label: Text(league.footballFormat)),
                                  Chip(
                                    label: Text(
                                      league.visibility == 'private'
                                          ? 'Privata'
                                          : 'Pubblica',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                league.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text('${league.city}, ${league.country}'),
                        const Spacer(),
                        const Icon(
                          Icons.people_outline,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text('${league.memberCount}/${league.maxMembers}'),
                      ],
                    ),
                    if (league.canManage) ...[
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: detail.inviteCode),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Codice invito copiato.'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy),
                              label: Text('Invita · ${detail.inviteCode}'),
                            ),
                          ),
                          if (league.currentUserRole == 'owner') ...[
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Genera un nuovo codice',
                              onPressed: () async {
                                await AppScope.of(context).repository
                                    .rotateLeagueInvite(league.id);
                                await onRefresh();
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Home'),
                  Tab(text: 'Comunicazioni'),
                  Tab(text: 'Partite'),
                  Tab(text: 'Classifiche'),
                  Tab(text: 'Giocatori'),
                  Tab(text: 'Statistiche'),
                  Tab(text: 'Info'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _LeagueHome(
              detail: detail,
              matches: matches,
              communications: communications,
            ),
            _Communications(
              detail: detail,
              items: communications,
              onRefresh: onRefresh,
            ),
            _LeagueMatches(league: league, matches: matches),
            _Leaderboard(players: leaders),
            _MembersList(detail: detail, onRefresh: onRefresh),
            _LeagueStats(players: leaders),
            _LeagueInfo(detail: detail),
          ],
        ),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabHeaderDelegate(this.tabBar);
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
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}

class _LeagueHome extends StatelessWidget {
  const _LeagueHome({
    required this.detail,
    required this.matches,
    required this.communications,
  });
  final LeagueDetail detail;
  final List<MatchSummary> matches;
  final List<LeagueCommunication> communications;

  @override
  Widget build(BuildContext context) {
    final upcoming = matches.where((match) => !match.isPast).toList();
    final pinned = communications.where((item) => item.pinned).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pinned != null) ...[
          InkWell(
            onTap: () => DefaultTabController.of(context).animateTo(1),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: .45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.background,
                    child: Icon(Icons.push_pin, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MESSAGGIO FISSATO',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pinned.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pinned.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.foreground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.primary),
                ],
              ),
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
                  'Dentro la lega',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  detail.summary.description ??
                      'Una lega Kickly pronta per nuove partite e rivalità.',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Membri',
                        value: '${detail.members.length}',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Metric(
                        label: 'Admin',
                        value:
                            '${detail.members.where((item) => item.leagueRole == 'admin').length}',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Metric(
                        label: 'Formato',
                        value: detail.summary.footballFormat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle(title: 'Prossima partita', eyebrow: 'Calendario'),
        const SizedBox(height: 11),
        if (upcoming.isEmpty)
          const EmptyState(
            icon: Icons.event_busy,
            title: 'Nessuna partita',
            body: 'Non ci sono eventi futuri in programma.',
          )
        else
          MatchCard(
            match: upcoming.first,
            onTap: () => context.push('/matches/${upcoming.first.id}'),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _LeagueMatches extends StatelessWidget {
  const _LeagueMatches({required this.league, required this.matches});
  final LeagueSummary league;
  final List<MatchSummary> matches;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (league.canManage) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/matches/new?league=${league.id}'),
              icon: const Icon(Icons.add),
              label: const Text('Crea partita'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (matches.isEmpty)
          const EmptyState(
            icon: Icons.sports_soccer,
            title: 'Nessuna partita',
            body: 'Il calendario della lega è ancora vuoto.',
          )
        else
          ...matches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: MatchCard(
                match: match,
                onTap: () => context.push('/matches/${match.id}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.detail, required this.onRefresh});
  final LeagueDetail detail;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: detail.members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final member = detail.members[index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/player/${member.username}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            leading: PlayerAvatar(
              name: member.displayName,
              url: member.avatarUrl,
            ),
            title: Text(
              member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '@${member.username} · ${_roleLabel(member.footballRole)}',
            ),
            trailing: detail.summary.canManage && member.leagueRole != 'owner'
                ? PopupMenuButton<String>(
                    onSelected: (action) =>
                        _memberAction(context, member, action),
                    itemBuilder: (_) => [
                      if (detail.summary.currentUserRole == 'owner')
                        PopupMenuItem(
                          value: 'role',
                          child: Text(
                            member.leagueRole == 'admin'
                                ? 'Rendi membro'
                                : 'Rendi admin',
                          ),
                        ),
                      if (detail.summary.currentUserRole == 'owner')
                        const PopupMenuItem(
                          value: 'owner',
                          child: Text('Trasferisci proprietà'),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Rimuovi dalla lega'),
                      ),
                    ],
                  )
                : Chip(label: Text(member.leagueRole)),
          ),
        );
      },
    );
  }

  Future<void> _memberAction(
    BuildContext context,
    LeagueMember member,
    String action,
  ) async {
    final repository = AppScope.of(context).repository;
    try {
      if (action == 'role') {
        await repository.setLeagueMemberRole(
          detail.summary.id,
          member.userId,
          member.leagueRole == 'admin' ? 'member' : 'admin',
        );
      }
      if (action == 'owner') {
        await repository.transferLeagueOwnership(
          detail.summary.id,
          member.userId,
        );
      }
      if (action == 'remove') {
        await repository.removeLeagueMember(detail.summary.id, member.userId);
      }
      await onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _Communications extends StatelessWidget {
  const _Communications({
    required this.detail,
    required this.items,
    required this.onRefresh,
  });
  final LeagueDetail detail;
  final List<LeagueCommunication> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (detail.summary.canManage) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _compose(context),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Nuova comunicazione'),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (items.isEmpty)
        const EmptyState(
          icon: Icons.forum_outlined,
          title: 'Nessuna comunicazione',
          body: 'Gli avvisi degli admin compariranno qui.',
        )
      else
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlayerAvatar(
                          name: item.authorName,
                          url: item.authorAvatarUrl,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '@${item.authorUsername}',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.pinned)
                          const Icon(
                            Icons.push_pin,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        if (detail.summary.canManage)
                          IconButton(
                            onPressed: () async {
                              await AppScope.of(context).repository
                                  .deleteLeagueCommunication(item.id);
                              await onRefresh();
                            },
                            icon: const Icon(Icons.delete_outline, size: 19),
                          ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                      style: const TextStyle(
                        color: AppTheme.mutedSoft,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _compose(BuildContext context) async {
    final draft = await showDialog<_CommunicationDraft>(
      context: context,
      builder: (dialogContext) => const _ComposeCommunicationDialog(),
    );
    if (draft != null && context.mounted) {
      try {
        await AppScope.of(context).repository.publishLeagueCommunication(
          detail.summary.id,
          title: draft.title,
          body: draft.body,
          pinned: draft.pinned,
        );
        await onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }
}

class _CommunicationDraft {
  const _CommunicationDraft(this.title, this.body, this.pinned);
  final String title;
  final String body;
  final bool pinned;
}

// Widget (non funzione locale) cosi i TextEditingController sono creati in
// initState e distrutti in dispose(): il ciclo di vita segue quello reale
// dell'Element del dialog invece di essere chiuso subito dopo l'await di
// showDialog, quando l'animazione di uscita puo' ancora usarli e crashare
// con "TextEditingController was used after being disposed".
class _ComposeCommunicationDialog extends StatefulWidget {
  const _ComposeCommunicationDialog();
  @override
  State<_ComposeCommunicationDialog> createState() =>
      _ComposeCommunicationDialogState();
}

class _ComposeCommunicationDialogState
    extends State<_ComposeCommunicationDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pinned = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuova comunicazione'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Titolo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Messaggio'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pinned,
          onChanged: (v) => setState(() => _pinned = v),
          title: const Text('Fissa in alto'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _CommunicationDraft(_title.text, _body.text, _pinned),
        ),
        child: const Text('Pubblica'),
      ),
    ],
  );
}

class _Leaderboard extends StatefulWidget {
  const _Leaderboard({required this.players});
  final List<LeaderboardPlayer> players;
  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  String metric = 'overall';
  @override
  Widget build(BuildContext context) {
    final players = [...widget.players]
      ..sort((a, b) => _value(b).compareTo(_value(a)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const metrics = {
              'overall': ('Overall', Icons.bolt),
              'goals': ('Gol', Icons.sports_soccer),
              'assists': ('Assist', Icons.assistant_direction),
              'mvp': ('MVP', Icons.emoji_events_outlined),
              'matches': ('Presenze', Icons.calendar_month_outlined),
            };
            final columns = constraints.maxWidth >= 650 ? 5 : 2;
            final width =
                (constraints.maxWidth - ((columns - 1) * 8)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics.entries.map((entry) {
                final selected = metric == entry.key;
                return SizedBox(
                  width: width,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: selected
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: .09),
                      foregroundColor: selected
                          ? AppTheme.background
                          : AppTheme.primary,
                      side: BorderSide(
                        color: AppTheme.primary.withValues(
                          alpha: selected ? 1 : .35,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 13,
                      ),
                    ),
                    onPressed: () => setState(() => metric = entry.key),
                    icon: Icon(entry.value.$2, size: 17),
                    label: FittedBox(child: Text(entry.value.$1)),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        ...players.indexed.map(
          (e) => Card(
            child: ListTile(
              onTap: () => context.push('/player/${e.$2.username}'),
              leading: CircleAvatar(
                backgroundColor: e.$1 < 3
                    ? AppTheme.primary
                    : AppTheme.surfaceHigh,
                // Token del tema invece di Colors.white: stesso bianco quasi
                // identico, ma coerente con il resto della palette.
                foregroundColor: e.$1 < 3
                    ? AppTheme.background
                    : AppTheme.foreground,
                child: Text(
                  '${e.$1 + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(
                e.$2.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('@${e.$2.username} · ${e.$2.matches} partite'),
              trailing: Text(
                '${_value(e.$2)}',
                style: const TextStyle(
                  fontSize: 20,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _value(LeaderboardPlayer p) => switch (metric) {
    'goals' => p.goals,
    'assists' => p.assists,
    'mvp' => p.mvp,
    'matches' => p.matches,
    _ => p.overall,
  };
}

class _LeagueStats extends StatelessWidget {
  const _LeagueStats({required this.players});
  final List<LeaderboardPlayer> players;
  @override
  Widget build(BuildContext context) {
    final matches = players.fold<int>(0, (v, p) => v + p.matches);
    final goals = players.fold<int>(0, (v, p) => v + p.goals);
    final assists = players.fold<int>(0, (v, p) => v + p.assists);
    final average = players.isEmpty
        ? 0
        : (players.fold<int>(0, (v, p) => v + p.overall) / players.length)
              .round();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle(title: 'Numeri della lega', eyebrow: 'Statistiche'),
        const SizedBox(height: 12),
        // StatGrid invece di un GridView.count con childAspectRatio fisso:
        // quel rapporto legava l'altezza alla larghezza della colonna e con
        // il font di sistema ingrandito il numero usciva dalla tessera
        // (lo stesso problema già risolto per dashboard e profilo giocatore).
        StatGrid(
          tiles: [
            StatTile(
              label: 'Presenze',
              value: matches,
              icon: Icons.calendar_month,
            ),
            StatTile(label: 'Gol', value: goals, icon: Icons.sports_soccer),
            StatTile(
              label: 'Assist',
              value: assists,
              icon: Icons.assistant_direction,
            ),
            StatTile(
              label: 'OVR medio',
              value: average,
              icon: Icons.auto_graph,
            ),
          ],
        ),
      ],
    );
  }
}

class _LeagueInfo extends StatelessWidget {
  const _LeagueInfo({required this.detail});
  final LeagueDetail detail;
  @override
  Widget build(BuildContext context) {
    final league = detail.summary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Città',
                  value: '${league.city}, ${league.country}',
                ),
                const Divider(height: 27),
                _InfoRow(
                  label: 'Formato',
                  value: league.footballFormat.replaceAll('v', ' vs '),
                ),
                const Divider(height: 27),
                _InfoRow(
                  label: 'Visibilità',
                  value: league.visibility == 'private'
                      ? 'Privata · accesso con invito'
                      : 'Pubblica',
                ),
                const Divider(height: 27),
                _InfoRow(
                  label: 'Capienza',
                  value: '${league.memberCount} di ${league.maxMembers} membri',
                ),
                const Divider(height: 27),
                _InfoRow(label: 'Il tuo ruolo', value: league.currentUserRole),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (league.canManage)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/leagues/${league.slug}/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Impostazioni lega'),
            ),
          ),
        if (league.currentUserRole != 'owner') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _leave(context),
              icon: const Icon(Icons.logout),
              label: const Text('Lascia lega'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _leave(BuildContext context) async {
    // Feedback aptico prima del dialog, non dopo il tap su "Lascia": è
    // un'azione distruttiva e qui, non nel bottone del dialog, sta il primo
    // momento in cui l'utente segnala l'intenzione di uscire dalla lega.
    HapticFeedback.mediumImpact();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lasciare la lega?'),
        content: const Text('Per rientrare servirà un nuovo invito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lascia'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    await AppScope.of(context).repository.leaveLeague(detail.summary.id);
    if (context.mounted) context.go('/leagues');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.muted)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

String _roleLabel(String? role) => switch (role) {
  'goalkeeper' => 'Portiere',
  'defender' => 'Difensore',
  'midfielder' => 'Centrocampista',
  'forward' => 'Attaccante',
  _ => 'Giocatore',
};
