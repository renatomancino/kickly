import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'profile_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<ProfileDetails>? _future;

  // 0 = Panoramica (statistiche del momento), 1 = Andamento (come sono
  // arrivate quelle statistiche nel tempo). Un selettore a due segmenti al
  // posto di impilare tutto in un'unica scrollata lunghissima: separa lo
  // "scatto" dal "percorso", come fanno le app Apple (Fitness, Salute) quando
  // un profilo ha sia un riepilogo sia uno storico.
  int _tab = 0;

  // Distanza di scroll su cui far comparire il titolo minimo della barra:
  // FlexibleSpaceBar.title di suo lo mostra gia (quasi) a piena opacita
  // anche a testata completamente espansa, quindi il nome duplicava quello
  // grande sotto invece di comparire solo dopo lo scroll. Calcolando
  // l'opacita a mano dallo scroll offset, invece, la comparsa e sotto il
  // nostro controllo esplicito.
  static const _titleFadeDistance = 120.0;
  final _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getProfileDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          final elite = stats.overall >= eliteOverallThreshold;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Testata a scomparsa: da sopra piena (avatar, nome, ruoli,
              // anello dell'overall) a una barra minima con solo il nome
              // quando si scrolla, come le pagine profilo/impostazioni di
              // iOS. Prima l'intestazione era una coppia di Card fisse in
              // cima alla lista: qui e contenuto libero sopra allo sfondo
              // (l'alone verde di KicklyBackdrop resta visibile dietro),
              // non piu incorniciato.
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppTheme.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                // Il titolo vive qui (non in FlexibleSpaceBar.title): quello
                // resterebbe visibile anche a testata espansa, sovrapposto
                // al nome grande sotto. Qui la sua opacita segue lo scroll
                // offset in modo esplicito, vedi AnimatedBuilder sotto.
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final opacity = (offset / _titleFadeDistance).clamp(
                      0.0,
                      1.0,
                    );
                    return Opacity(opacity: opacity, child: child);
                  },
                  child: _CollapsedTitle(profile: profile),
                ),
                // 252 sembrava sufficiente misurando solo una riga di badge,
                // ma con tre pill (ruolo, piede, livello) il Wrap va quasi
                // sempre a due righe: senza margine la colonna sforava lo
                // spazio della testata ("BOTTOM OVERFLOWED"). 288 lascia
                // anche un margine per il testo di sistema ingrandito.
                expandedHeight: 288,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroHeader(
                    profile: profile,
                    stats: stats,
                    elite: elite,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TabSwitch(
                      value: _tab,
                      onChanged: (value) => setState(() => _tab = value),
                    ),
                    const SizedBox(height: 20),
                    // AnimatedSwitcher invece di uno swap secco: il cambio tab
                    // e uno dei punti in cui una micro-transizione si nota di
                    // piu, essendo innescata direttamente dal tocco dell'utente.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _tab == 0
                          ? _OverviewSection(
                              key: const ValueKey('overview'),
                              stats: stats,
                            )
                          : _TrendSection(
                              key: const ValueKey('trend'),
                              history: data.history,
                              form: data.form,
                            ),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel('Account'),
                    const SizedBox(height: 10),
                    _AccountCard(
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
                        _SettingRow(
                          icon: Icons.notifications_outlined,
                          title: 'Preferenze notifiche',
                          subtitle: 'Scegli cosa farti ricordare',
                          onTap: _showPreferences,
                        ),
                        _SettingRow(
                          icon: Icons.logout,
                          title: 'Esci',
                          danger: true,
                          // Solo signOut(): AppState.signOut() già chiama
                          // notifyListeners(), e il redirect del router (che
                          // ascolta AppState tramite refreshListenable) manda
                          // già da solo a /login quando isSignedIn diventa
                          // false. Un context.go('/login') qui in più correva
                          // in parallelo con quel redirect automatico ed era
                          // la causa di un crash intermittente ("Duplicate
                          // GlobalKey detected in widget tree", visto in log
                          // reali) per doppia navigazione nello stesso frame.
                          onTap: () => AppScope.of(context).appState.signOut(),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Contenuto della testata quando e completamente espansa: avatar, nome,
/// badge e l'anello dell'overall.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.profile,
    required this.stats,
    required this.elite,
  });

  final UserProfile profile;
  final PlayerStats stats;
  final bool elite;

  @override
  Widget build(BuildContext context) {
    final accent = elite ? AppTheme.gold : AppTheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Velatura di colore dietro tutta la testata: piu marcata per gli
        // elite, cosi la card "brilla" di oro appena si apre la pagina
        // invece di scoprirlo solo guardando l'anello.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: elite ? .16 : .08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: .6),
                          width: elite ? 2.8 : 2.2,
                        ),
                      ),
                      child: PlayerAvatar(
                        name: profile.displayName,
                        url: profile.avatarUrl,
                        radius: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '@${profile.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (profile.city != null &&
                            profile.city!.trim().isNotEmpty) ...[
                          const Text(
                            '  ·  ',
                            style: TextStyle(color: AppTheme.mutedSoft),
                          ),
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppTheme.mutedSoft,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              profile.city!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.mutedSoft,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ProfileInfoPill(label: roleLabel(profile.primaryPosition)),
                        if (footLabel(profile.preferredFoot) case final label?)
                          ProfileInfoPill(
                            label: label,
                            icon: Icons.sports_soccer,
                          ),
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
              const SizedBox(width: 8),
              OverallRing(
                value: stats.overall,
                elite: elite,
                diameter: 96,
                strokeWidth: 8.5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Riga minima mostrata nella barra quando la testata e collassata dallo
/// scroll: avatar piccolo + nome, cosi non si perde il riferimento a "di chi
/// e questo profilo" mentre si scorre l'elenco sotto.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    // FlexibleSpaceBar posiziona `title` in una fascia bassa e stretta (la
    // stessa altezza della toolbar collassata): un Row con un secondo
    // PlayerAvatar dentro sforava quello spazio ("BOTTOM OVERFLOWED"),
    // percio qui resta solo un'etichetta di testo su una riga, vincolata in
    // altezza cosi non puo mai eccedere la fascia disponibile.
    return SizedBox(
      height: kToolbarHeight - 20,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppTheme.foreground,
          ),
        ),
      ),
    );
  }
}

/// Selettore Panoramica/Andamento, largo quanto il resto del contenuto
/// (testata, card) invece del CupertinoSlidingSegmentedControl di default:
/// quello restava piu stretto, centrato a se, e con un raggio d'angolo
/// tutto suo diverso da ogni altra pillola dell'app — il dettaglio che
/// faceva sembrare la barra "attaccata" senza combaciare con i bordi del
/// resto della pagina. Qui e a piena larghezza, raggio 999 come le altre
/// pillole (vedi ProfileInfoPill), e il cursore scorre con lo stesso
/// AnimatedAlign gia usato per la lampada della bottom bar.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['Panoramica', 'Andamento'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .28),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        _labels[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: value == i
                              ? AppTheme.foreground
                              : AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tab "Panoramica": la fotografia del momento, statistiche stagionali e
/// composizione dei risultati.
class _OverviewSection extends StatelessWidget {
  const _OverviewSection({super.key, required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            StatTile(label: 'MVP', value: stats.mvp, icon: Icons.emoji_events),
          ],
        ),
        const SizedBox(height: 12),
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
                if (stats.matches == 0) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Nessuna partita completata: i numeri arrivano dopo il primo fischio.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
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

/// Tab "Andamento": come si e arrivati a quei numeri, nel tempo.
class _TrendSection extends StatelessWidget {
  const _TrendSection({super.key, required this.history, required this.form});

  final List<Map<String, dynamic>> history;
  final List<String> form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: RatingTrendChart(history: history),
          ),
        ),
        if (form.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    children: [
                      for (final result in form) _FormDot(result: result),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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

/// Contenitore della lista Account: stessa Card di prima, ma con i divisori
/// rientrati sotto al testo (come le liste raggruppate di iOS) invece che a
/// tutta larghezza, cosi non tagliano anche l'icona.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 65),
                child: Divider(height: 1),
              ),
          ],
        ],
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
