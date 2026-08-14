import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, required this.username});
  final String username;
  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  Future<ProfileDetails?>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).repository
        .getPublicProfile(widget.username);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('@${widget.username}')),
    body: FutureBuilder<ProfileDetails?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        final data = snapshot.data;
        if (data == null) {
          return const PageFrame(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Profilo non disponibile',
              body: 'Il profilo non esiste oppure è privato.',
            ),
          );
        }
        final profile = data.profile, stats = data.stats;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: .14),
                      Colors.transparent,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  children: [
                    PlayerAvatar(
                      name: profile.displayName,
                      url: profile.avatarUrl,
                      radius: 48,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      '@${profile.username}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(_role(profile.primaryPosition))),
                        Chip(label: Text(_level(profile.skillLevel))),
                        Chip(label: Text('OVR ${stats.overall}')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // StatGrid invece di un GridView.count con childAspectRatio
            // fisso: quel rapporto legava l'altezza alla larghezza della
            // colonna e con il font di sistema ingrandito il numero usciva
            // dalla tessera (lo stesso problema già risolto per la dashboard).
            StatGrid(
              tiles: [
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
                  icon: Icons.emoji_events,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prestazioni',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metric('Vittorie', stats.wins),
                        _metric('Pareggi', stats.draws),
                        _metric('Win rate', '${stats.winRate}%'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'FORMA RECENTE',
                      style: TextStyle(
                        color: AppTheme.mutedSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      children: data.form.map((r) {
                        // Stessa palette per-esito della card "Forma recente"
                        // del profilo privato (vittoria verde, sconfitta rossa,
                        // pareggio grigio): prima ogni pallino era verde o
                        // grigio a prescindere dall'esito, quindi una
                        // sconfitta ("L") appariva con lo stesso colore del
                        // marchio invece di leggere come un risultato negativo.
                        final (label, color) = switch (r) {
                          'win' => ('W', AppTheme.primary),
                          'loss' => ('L', AppTheme.danger),
                          _ => ('D', AppTheme.muted),
                        };
                        return CircleAvatar(
                          radius: 17,
                          backgroundColor: color.withValues(alpha: .16),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(String label, Object value) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
    ],
  );
  String _role(String? value) =>
      const {
        'goalkeeper': 'Portiere',
        'defender': 'Difensore',
        'midfielder': 'Centrocampista',
        'forward': 'Attaccante',
      }[value] ??
      'Giocatore';
  String _level(String? value) =>
      const {
        'beginner': 'Principiante',
        'amateur': 'Amatore',
        'competitive': 'Competitivo',
      }[value] ??
      'Amatore';
}
