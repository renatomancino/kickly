import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'profile_widgets.dart';

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
    future ??= AppScope.of(context).repository.getPublicProfile(widget.username);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // AppBar trasparente sopra allo sfondo dell'app (l'alone verde di
    // KicklyBackdrop), gia il default del tema: coerente col resto
    // dell'app. Niente extendBodyBehindAppBar: con quello attivo la card
    // dell'hero scorreva SOTTO la barra e, essendo trasparente, si vedeva
    // l'avatar sovrapposto al titolo mentre si scrollava.
    appBar: AppBar(title: Text('@${widget.username}')),
    body: FutureBuilder<ProfileDetails?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        // Ramo errore separato da "profilo assente": senza, un fallimento
        // di rete cadeva nello stesso `data == null` di un profilo privato
        // o inesistente, dicendo all'utente qualcosa di sbagliato invece
        // che "riprova".
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Profilo non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: () => setState(
                  () => future = AppScope.of(context).repository
                      .getPublicProfile(widget.username),
                ),
                child: const Text('Riprova'),
              ),
            ),
          );
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
        final elite = stats.overall >= eliteOverallThreshold;
        final accent = elite ? AppTheme.gold : AppTheme.primary;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Stessa impostazione "identita a sinistra, anello dell'overall a
            // destra" della testata del profilo privato: chi guarda un
            // profilo altrui deve riconoscere subito lo stesso linguaggio
            // visivo del proprio, non un layout diverso.
            Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: elite ? .18 : .09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: .6),
                            width: elite ? 3 : 2.4,
                          ),
                        ),
                        child: PlayerAvatar(
                          name: profile.displayName,
                          url: profile.avatarUrl,
                          radius: 46,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '@${profile.username}',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      if (profile.city != null &&
                          profile.city!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppTheme.mutedSoft,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              profile.city!,
                              style: const TextStyle(
                                color: AppTheme.mutedSoft,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      OverallRing(value: stats.overall, elite: elite),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ProfileInfoPill(label: roleLabel(profile.primaryPosition)),
                          if (footLabel(profile.preferredFoot) case final label?)
                            ProfileInfoPill(label: label, icon: Icons.sports_soccer),
                          if (skillLabel(profile.skillLevel) case final label?)
                            ProfileInfoPill(
                              label: label,
                              icon: Icons.military_tech_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'RISULTATI',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${stats.winRate}% win rate',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ResultsBar(
                      wins: stats.wins,
                      draws: stats.draws,
                      losses: stats.losses,
                    ),
                    if (data.form.isNotEmpty) ...[
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
                  ],
                ),
              ),
            ),
            if (data.history.length >= 2) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: RatingTrendChart(history: data.history),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
