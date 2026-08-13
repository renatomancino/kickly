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
  Future<(LeagueDetail?, List<MatchSummary>)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(LeagueDetail?, List<MatchSummary>)> _load() async {
    final repository = AppScope.of(context).repository;
    final detail = await repository.getLeague(widget.slug);
    if (detail == null) return (null, const <MatchSummary>[]);
    final matches = await repository.getLeagueMatches(detail.summary);
    return (detail, matches);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lega')),
      body: SafeArea(
        child: FutureBuilder<(LeagueDetail?, List<MatchSummary>)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
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
    required this.onRefresh,
  });

  final LeagueDetail detail;
  final List<MatchSummary> matches;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final league = detail.summary;
    return DefaultTabController(
      length: 4,
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
                      SizedBox(
                        width: double.infinity,
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
                  Tab(text: 'Partite'),
                  Tab(text: 'Giocatori'),
                  Tab(text: 'Info'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _LeagueHome(detail: detail, matches: matches),
            _LeagueMatches(league: league, matches: matches),
            _MembersList(members: detail.members),
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
  const _LeagueHome({required this.detail, required this.matches});
  final LeagueDetail detail;
  final List<MatchSummary> matches;

  @override
  Widget build(BuildContext context) {
    final upcoming = matches.where((match) => !match.isPast).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                  style: const TextStyle(color: Colors.white60),
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
          style: const TextStyle(color: Colors.white54, fontSize: 10),
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
  const _MembersList({required this.members});
  final List<LeagueMember> members;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          child: ListTile(
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
            trailing: Chip(label: Text(member.leagueRole)),
          ),
        );
      },
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
      ],
    );
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
      Text(label, style: const TextStyle(color: Colors.white54)),
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
