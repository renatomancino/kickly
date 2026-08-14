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
              // Intestazione a due blocchi: identita a sinistra, overall come
              // tessera a se sulla destra, cosi il numero che riassume il
              // giocatore si legge senza cercarlo dentro all'avatar.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // L'overall passa anche alla card identita: le due tessere
                    // devono cambiare "livello" insieme, altrimenti l'accento
                    // dorato sbucherebbe solo su una delle due meta della
                    // testata e sembrerebbe un errore piuttosto che una scelta.
                    Expanded(
                      child: _IdentityCard(
                        profile: profile,
                        overall: stats.overall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OverallCard(overall: stats.overall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Striscia dei numeri: una riga sola con separatori verticali al
              // posto della griglia di tessere. Occupa meno spazio e si legge
              // come un cruscotto invece che come quattro riquadri slegati.
              _StatStrip(stats: stats),
              const SizedBox(height: 12),
              _FormCard(stats: stats, form: data.form),
              const SizedBox(height: 22),
              const _SectionLabel('Account'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.edit_outlined,
                      title: 'Modifica profilo',
                      subtitle: 'Nome, ruolo, foto e localita',
                      onTap: () async {
                        await context.push('/profile/edit');
                        if (context.mounted) await _reload();
                      },
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.notifications_outlined,
                      title: 'Preferenze notifiche',
                      subtitle: 'Scegli cosa farti ricordare',
                      onTap: _showPreferences,
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.logout,
                      title: 'Esci',
                      danger: true,
                      // Solo signOut(): AppState.signOut() già chiama
                      // notifyListeners(), e il redirect del router (che
                      // ascolta AppState tramite refreshListenable) manda
                      // già da solo a /login quando isSignedIn diventa
                      // false. Un context.go('/login') qui in più correva in
                      // parallelo con quel redirect automatico ed era la
                      // causa di un crash intermittente ("Duplicate
                      // GlobalKey detected in widget tree", visto in log
                      // reali) per doppia navigazione nello stesso frame.
                      onTap: () => AppScope.of(context).appState.signOut(),
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

/// Eyebrow di sezione, stesso trattamento usato nella dashboard.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppTheme.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

/// Blocco identita: avatar, nome, username, citta e badge del giocatore.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.overall});

  final UserProfile profile;
  final int overall;

  @override
  Widget build(BuildContext context) {
    // Sopra la soglia "elite" la card passa dal verde del marchio all'oro
    // gia usato per fascia da capitano e trofei: e lo stesso principio delle
    // card FIFA/FUT (le carte piu forti hanno una rifinitura diversa), reso
    // pero con un solo scatto invece di una scala a piu colori, cosi resta
    // leggibile come "eccellenza" e non come un semaforo di livelli.
    final elite = overall >= _eliteOverallThreshold;
    final accent = elite ? AppTheme.gold : AppTheme.primary;
    return Card(
      // Il bordo dorato si applica solo alle card elite: per tutte le altre
      // lasciamo lo shape di default del tema (bordo verde tenue), cosi il
      // trattamento "normale" resta identico a prima e non cambia look a chi
      // non supera la soglia.
      shape: elite
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: const BorderSide(color: AppTheme.gold, width: 1.3),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          // Velatura di colore appena accennata (piu marcata per le card
          // elite): stacca l'intestazione dal resto della pagina senza
          // introdurre un colore nuovo rispetto al resto del tema.
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: elite ? .2 : .1),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Anello attorno all'avatar: sulla card velata di colore il
            // cerchio da solo aveva troppo poco contrasto e si confondeva col
            // fondo.
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: .55),
                  width: elite ? 2.5 : 2,
                ),
              ),
              child: PlayerAvatar(
                name: profile.displayName,
                url: profile.avatarUrl,
                radius: 27,
              ),
            ),
            const SizedBox(height: 14),
            // Gerarchia tipografica esplicita: il nome e il titolo della
            // card (titleLarge, gia in grassetto pesante dal tema), lo
            // username e un metadato secondario, la citta un terzo livello
            // ancora piu discreto. Prima citta non compariva affatto qui
            // pur essendo un dato gia raccolto in fase di onboarding.
            Text(
              profile.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '@${profile.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            if (profile.city != null && profile.city!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppTheme.mutedSoft,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      profile.city!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedSoft,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Badge del ruolo, piede preferito e livello: dati gia raccolti
            // nell'editor ma prima assenti dalla card principale, dove
            // l'utente li vede senza dover aprire "Modifica profilo". Un
            // Wrap invece di una Row fissa cosi non serve gestire l'overflow
            // quando compaiono tutti e tre insieme su schermi stretti.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoPill(label: _roleLabel(profile.primaryPosition)),
                if (_footLabel(profile.preferredFoot) case final label?)
                  _InfoPill(label: label, icon: Icons.sports_soccer),
                if (_skillLabel(profile.skillLevel) case final label?)
                  _InfoPill(label: label, icon: Icons.military_tech_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Soglia di overall oltre la quale la card riceve il trattamento "elite"
/// (bordo/gradiente dorato al posto del verde standard). 85 e volutamente
/// alto: deve restare un traguardo raro, non qualcosa che quasi tutti
/// raggiungono subito.
const _eliteOverallThreshold = 85;

/// Badge coerente col resto della card (stessa pillola usata per il ruolo,
/// non il `Chip` di Material) per non introdurre un secondo linguaggio
/// visivo nella stessa tessera.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppTheme.muted),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Tessera dell'overall, il numero che riassume il giocatore.
class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.overall});

  final int overall;

  @override
  Widget build(BuildContext context) {
    // Stessa soglia della card identita: le due tessere della testata devono
    // "scattare" di livello insieme, non una si e una no.
    final elite = overall >= _eliteOverallThreshold;
    return SizedBox(
      width: 108,
      child: Card(
        // Tinta unita per il caso normale (invariato), nessun colore quando
        // e la card elite: li il colore arriva dal gradiente sotto, messo su
        // un Container invece che sul Card perche CardThemeData non supporta
        // un gradiente come `color`.
        color: elite ? null : AppTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Container(
          decoration: elite
              ? const BoxDecoration(
                  // Oro verso verde: richiama la fascia da capitano ma
                  // resta ancorato al colore del marchio, cosi non sembra un
                  // badge scollegato dal resto dell'app.
                  gradient: LinearGradient(
                    colors: [AppTheme.gold, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'OVERALL',
                style: TextStyle(
                  color: AppTheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$overall',
                  style: const TextStyle(
                    color: AppTheme.onPrimary,
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga dei numeri principali, separati da divisori verticali.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Partite', 'matches'),
      ('Gol', 'goals'),
      ('Assist', 'assists'),
      ('MVP', 'mvp'),
    ];
    int valueOf(String key) => switch (key) {
      'matches' => stats.matches,
      'goals' => stats.goals,
      'assists' => stats.assists,
      _ => stats.mvp,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0)
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    indent: 4,
                    endIndent: 4,
                    color: AppTheme.outline,
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entries[index].$1.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${valueOf(entries[index].$2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rendimento: barra del win rate piu esiti delle ultime partite.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.stats, required this.form});

  final PlayerStats stats;
  final List<String> form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'WIN RATE',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '${stats.winRate}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _WinRateBar(winRate: stats.winRate, hasMatches: stats.matches > 0),
            const SizedBox(height: 10),
            Text(
              stats.matches == 0
                  ? 'Nessuna partita completata: i numeri arrivano dopo il primo fischio.'
                  : '${stats.wins} vinte · ${stats.draws} pareggiate · ${stats.losses} perse',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
            ),
            if (form.isNotEmpty) ...[
              const Divider(height: 30, color: AppTheme.outline),
              const Text(
                'FORMA RECENTE',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [for (final result in form) _FormDot(result: result)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra rosso-giallo-verde con l'indicatore sulla percentuale di vittorie.
class _WinRateBar extends StatelessWidget {
  const _WinRateBar({required this.winRate, required this.hasMatches});

  final int winRate;
  final bool hasMatches;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 8.0;
        const markerWidth = 4.0;
        final position =
            (constraints.maxWidth - markerWidth) *
            (winRate.clamp(0, 100) / 100);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    // Senza partite la scala resta spenta: una barra colorata
                    // con l'indicatore a zero suggerirebbe un dato che non c'e.
                    gradient: hasMatches
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF5A5A),
                              Color(0xFFFFC24D),
                              AppTheme.primary,
                            ],
                          )
                        : null,
                    color: hasMatches ? null : AppTheme.surfaceHigh,
                  ),
                ),
              ),
              if (hasMatches)
                Positioned(
                  left: position,
                  child: Container(
                    width: markerWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Pillola dell'esito di una partita: vittoria, pareggio o sconfitta.
class _FormDot extends StatelessWidget {
  const _FormDot({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      'win' => ('V', AppTheme.primary),
      'loss' => ('S', AppTheme.danger),
      _ => ('P', AppTheme.muted),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Riga di impostazione con icona, titolo, sottotitolo e freccia.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : AppTheme.foreground;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (danger ? AppTheme.danger : AppTheme.primary).withValues(
                  alpha: .12,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 19,
                color: danger ? AppTheme.danger : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!danger)
              const Icon(Icons.chevron_right, color: AppTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }
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

/// Stesse etichette di `profile_editor_page.dart`, cosi il piede indicato
/// qui e quello scelto in fase di modifica coincidono sempre alla lettera.
/// Torna `null` (invece di un valore di default) quando il dato manca:
/// a differenza del ruolo, non ha senso mostrare un piede "inventato".
String? _footLabel(String? foot) => switch (foot) {
  'right' => 'Destro',
  'left' => 'Sinistro',
  'both' => 'Entrambi',
  _ => null,
};

/// Idem per il livello: stesse tre voci dell'editor, nessun default quando
/// il valore non e ancora stato impostato.
String? _skillLabel(String? level) => switch (level) {
  'beginner' => 'Principiante',
  'amateur' => 'Amatore',
  'competitive' => 'Competitivo',
  _ => null,
};
