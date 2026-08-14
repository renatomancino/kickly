import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<ProfileDetails>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getProfileDetails();
  }

  Future<void> _reload() async {
    final next = AppScope.of(context).repository.getProfileDetails();
    setState(() => _future = next);
    await next;
  }

  Future<void> _showPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NotificationPreferencesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<ProfileDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton(items: 2);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Profilo non disponibile',
                  body: friendlyError(snapshot.error ?? 'Errore'),
                  action: FilledButton(
                    onPressed: _reload,
                    child: const Text('Riprova'),
                  ),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          final profile = data.profile;
          final stats = data.stats;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              Card(
                child: Container(
                  padding: const EdgeInsets.all(22),
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
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PlayerAvatar(
                            name: profile.displayName,
                            url: profile.avatarUrl,
                            radius: 40,
                          ),
                          Positioned(
                            right: -5,
                            bottom: -5,
                            child: CircleAvatar(
                              radius: 19,
                              backgroundColor: AppTheme.primary,
                              child: Text(
                                '${stats.overall}',
                                style: const TextStyle(
                                  color: AppTheme.background,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 19),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${profile.username}',
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                            const SizedBox(height: 9),
                            Chip(
                              label: Text(_roleLabel(profile.primaryPosition)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.push('/profile/edit');
                    if (context.mounted) await _reload();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica profilo'),
                ),
              ),
              const SizedBox(height: 22),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.35,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatTile(
                    label: 'Partite',
                    value: stats.matches,
                    icon: Icons.sports_soccer,
                  ),
                  StatTile(
                    label: 'Gol',
                    value: stats.goals,
                    icon: Icons.sports_score,
                  ),
                  StatTile(
                    label: 'Assist',
                    value: stats.assists,
                    icon: Icons.assistant_direction,
                  ),
                  StatTile(
                    label: 'MVP',
                    value: stats.mvp,
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(19),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prestazioni',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SmallStat(
                              label: 'Vittorie',
                              value: '${stats.wins}',
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _SmallStat(
                              label: 'Pareggi',
                              value: '${stats.draws}',
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _SmallStat(
                              label: 'Win rate',
                              value: '${stats.winRate}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'FORMA RECENTE',
                        style: TextStyle(
                          color: AppTheme.mutedSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (data.form.isEmpty)
                        const Text(
                          'Nessuna partita completata.',
                          style: TextStyle(color: AppTheme.muted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          children: data.form
                              .map(
                                (result) => CircleAvatar(
                                  radius: 17,
                                  backgroundColor: result == 'win'
                                      ? AppTheme.primary.withValues(alpha: .16)
                                      : result == 'loss'
                                      ? Colors.red.withValues(alpha: .15)
                                      : AppTheme.surfaceHigh,
                                  child: Text(
                                    result == 'win'
                                        ? 'W'
                                        : result == 'loss'
                                        ? 'L'
                                        : 'D',
                                    style: TextStyle(
                                      color: result == 'win'
                                          ? AppTheme.primary
                                          : result == 'loss'
                                          ? Colors.redAccent
                                          : Colors.white70,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      onTap: _showPreferences,
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Preferenze notifiche'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      onTap: () async {
                        await AppScope.of(context).appState.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Esci',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
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
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _NotificationPreferencesSheet extends StatefulWidget {
  const _NotificationPreferencesSheet();
  @override
  State<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends State<_NotificationPreferencesSheet> {
  JsonMap? _values;
  bool _saving = false;

  static const labels = {
    'match_created': 'Nuove partite',
    'match_updates': 'Aggiornamenti partita',
    'match_reminders': 'Promemoria',
    'waitlist': 'Lista d’attesa',
    'mvp': 'Votazioni MVP',
    'rating': 'Variazioni overall',
    'league_updates': 'Novità della lega',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_values == null) {
      AppScope.of(context).repository
          .getNotificationPreferences()
          .then((value) {
            if (mounted) setState(() => _values = value);
          });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppScope.of(context).repository
          .updateNotificationPreferences(_values!);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _values == null
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferenze notifiche',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Scegli quali aggiornamenti ricevere.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  ...labels.entries.map(
                    (item) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.value),
                      value: _values![item.key] != false,
                      onChanged: (value) =>
                          setState(() => _values![item.key] = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Salva preferenze'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _roleLabel(String? role) => switch (role) {
  'goalkeeper' => 'Portiere',
  'defender' => 'Difensore',
  'midfielder' => 'Centrocampista',
  'forward' => 'Attaccante',
  _ => 'Giocatore',
};
