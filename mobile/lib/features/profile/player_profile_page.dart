import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Soglia di overall oltre la quale il profilo pubblico riceve il
/// trattamento dorato invece del verde standard. Stesso valore di
/// `profile_page.dart`: le due card (privata e pubblica) devono considerare
/// "elite" lo stesso giocatore, non due soglie diverse.
const _eliteOverallThreshold = 85;

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
        // Stessa soglia "elite" della player card privata (profile_page.dart):
        // sopra gli 85 di overall il profilo pubblico riceve lo stesso
        // trattamento dorato, cosi un profilo forte si riconosce a colpo
        // d'occhio anche quando lo si guarda da fuori, non solo dal proprio.
        final elite = stats.overall >= _eliteOverallThreshold;
        final accent = elite ? AppTheme.gold : AppTheme.primary;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              shape: elite
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: AppTheme.gold, width: 1.3),
                    )
                  : null,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: elite ? .22 : .14),
                      Colors.transparent,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  children: [
                    // Anello colorato attorno all'avatar, stesso trattamento
                    // della card privata: qui l'avatar e piu grande (radius
                    // 48 contro 27) quindi il bordo e leggermente piu spesso
                    // per restare in proporzione.
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: .55),
                          width: elite ? 3 : 2.5,
                        ),
                      ),
                      child: PlayerAvatar(
                        name: profile.displayName,
                        url: profile.avatarUrl,
                        radius: 48,
                      ),
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
                    // Citta, terzo livello della gerarchia (nome > username >
                    // citta): dato gia raccolto in fase di onboarding ma
                    // prima mai mostrato sul profilo pubblico.
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(label: Text(_role(profile.primaryPosition))),
                        // Piede preferito: prima assente dal profilo
                        // pubblico pur essendo un dato gia disponibile.
                        if (_foot(profile.preferredFoot) case final label?)
                          Chip(label: Text(label)),
                        Chip(label: Text(_level(profile.skillLevel))),
                        // Il chip dell'overall e l'unico che riceve il
                        // trattamento dorato: e il numero che la soglia
                        // "elite" descrive, gli altri badge restano neutri.
                        Chip(
                          label: Text('OVR ${stats.overall}'),
                          backgroundColor: elite
                              ? AppTheme.gold.withValues(alpha: .16)
                              : null,
                          side: elite
                              ? const BorderSide(color: AppTheme.gold)
                              : null,
                          labelStyle: elite
                              ? const TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                )
                              : null,
                        ),
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

  // A differenza di _role/_level non ha un valore di default: se il piede
  // preferito non e stato impostato il chip semplicemente non compare,
  // invece di mostrare un'informazione inventata su un profilo altrui.
  String? _foot(String? value) => const {
    'right': 'Destro',
    'left': 'Sinistro',
    'both': 'Entrambi',
  }[value];
}
