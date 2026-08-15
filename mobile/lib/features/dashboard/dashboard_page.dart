import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Ritmo verticale della Home.
///
/// Prima ogni sezione aveva il suo numero a mano (30, 27, 27, 25...): la
/// differenza è minima ma si accumula, ed è proprio quel genere di scarto che
/// fa sembrare una pagina cucita insieme in momenti diversi invece che
/// disegnata come un unico sistema. Con una sola costante il respiro fra le
/// sezioni resta identico ovunque.
const double _kSectionGap = 30;
const double _kTitleGap = 12;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getDashboard();
  }

  Future<void> _refresh() async {
    final next = AppScope.of(context).repository.getDashboard();
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
    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Skeleton al posto della rotellina: mostra già la forma della
          // pagina, come fa `loading.tsx` nella PWA.
          return const ListSkeleton(items: 2);
        }
        if (snapshot.hasError || snapshot.data == null) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Home non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: _refresh,
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Row(
                children: [
                  const KicklyMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bentornato,',
                          style: TextStyle(color: AppTheme.muted, fontSize: 11),
                        ),
                        Text(
                          data.profile.firstName ?? data.profile.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Badge(
                    isLabelVisible: data.unreadNotifications > 0,
                    label: Text('${data.unreadNotifications}'),
                    child: IconButton.filledTonal(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_none),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kSectionGap),

              // --- Gruppo "partite": prossima, ultima, in arrivo ---
              // Le tre sezioni rispondono tutte alla stessa domanda con cui si
              // apre l'app ("quando/dove gioco?"), quindi ora stanno vicine
              // invece di avere le statistiche di stagione in mezzo. La
              // prossima partita resta il vero hero della pagina (unica card
              // con ombra e gradiente); l'ultima partita è un promemoria
              // volutamente più piccolo, subordinato; il calendario prosegue
              // subito sotto perché è un naturale "e poi?" rispetto all'hero.
              const SectionTitle(
                eyebrow: 'Next up',
                title: 'La prossima partita',
              ),
              const SizedBox(height: _kTitleGap),
              if (data.nextMatch == null)
                const _EmptyHeroMatch()
              else
                _HeroMatch(match: data.nextMatch!),
              if (data.lastMatch != null) ...[
                const SizedBox(height: 14),
                _LastMatchStrip(match: data.lastMatch!),
              ],
              const SizedBox(height: _kSectionGap),
              SectionTitle(
                eyebrow: 'Le tue prossime partite',
                title: 'In programma',
                trailing: TextButton(
                  onPressed: () => context.go('/matches'),
                  child: const Text('Vedi tutte'),
                ),
              ),
              const SizedBox(height: _kTitleGap),
              if (data.nearby.isEmpty)
                const EmptyState(
                  icon: Icons.event_available,
                  title: 'Nessun altro appuntamento',
                  body: 'Le nuove partite delle tue leghe compariranno qui.',
                )
              else
                ...data.nearby.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MatchCard(
                      match: match,
                      onTap: () => context.push('/matches/${match.id}'),
                    ),
                  ),
                ),
              const SizedBox(height: _kSectionGap),

              // --- Stagione: statistiche personali ---
              const SectionTitle(
                eyebrow: 'La tua stagione',
                title: 'Numeri in campo',
              ),
              const SizedBox(height: _kTitleGap),
              // Overall non è più la quinta tessera della griglia: su schermo
              // stretto (2 colonne) restava sempre da sola nell'ultima riga,
              // con mezza riga vuota accanto (spazio sprecato). Qui invece è
              // una fascia a piena larghezza: niente più buco nel layout, e il
              // numero di sintesi della stagione ottiene il risalto che
              // merita invece di confondersi fra i quattro conteggi.
              StatGrid(
                tiles: [
                  StatTile(
                    label: 'Partite',
                    value: data.stats.matches,
                    icon: Icons.sports_soccer,
                  ),
                  StatTile(
                    label: 'Gol',
                    value: data.stats.goals,
                    icon: Icons.sports_score,
                  ),
                  StatTile(
                    label: 'Assist',
                    value: data.stats.assists,
                    icon: Icons.assistant_direction,
                  ),
                  StatTile(
                    label: 'MVP',
                    value: data.stats.mvp,
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _OverallBanner(value: data.stats.overall),

              const SizedBox(height: _kSectionGap),

              // --- Community: le leghe ---
              SectionTitle(
                eyebrow: 'Community',
                title: 'Le tue leghe',
                trailing: TextButton(
                  onPressed: () => context.go('/leagues'),
                  child: const Text('Vedi tutte'),
                ),
              ),
              const SizedBox(height: _kTitleGap),
              if (data.leagues.isEmpty)
                EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Nessuna lega',
                  body: 'Creane una o unisciti con un codice invito.',
                  action: FilledButton(
                    onPressed: () => context.push('/leagues/join'),
                    child: const Text('Unisciti a una lega'),
                  ),
                )
              else
                ...data.leagues.map(
                  (league) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        onTap: () => context.push('/leagues/${league.slug}'),
                        contentPadding: const EdgeInsets.all(13),
                        leading: LeagueLogo(league: league),
                        title: Text(
                          league.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${league.city} · ${league.memberCountLabel} · ${league.footballFormat}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
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

/// Riepilogo dell'ultima partita giocata.
///
/// Prima era una Card piena della stessa taglia di quella della prossima
/// partita: le due finivano per pesare uguale sulla pagina, mentre
/// concettualmente una è l'evento imminente (il protagonista della Home) e
/// l'altra solo un promemoria del risultato passato. Qui è una striscia
/// compatta — meno padding, punteggio più piccolo — così resta leggibile ma
/// visivamente subordinata all'hero sopra di lei.
class _LastMatchStrip extends StatelessWidget {
  const _LastMatchStrip({required this.match});
  final LastMatchSummary match;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => context.push('/matches/${match.id}'),
      // Raggio preso dal tema (non un numero a sé, come 22 prima) così resta
      // sempre identico a quello che la Card usa per il proprio clip.
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ULTIMA PARTITA',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    match.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    match.leagueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${match.teamAScore} – ${match.teamBScore}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 15,
              backgroundColor: AppTheme.primary.withValues(alpha: .14),
              child: Text(
                match.result == 'win'
                    ? 'W'
                    : match.result == 'loss'
                    ? 'L'
                    : 'D',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Stato vuoto della prossima partita.
///
/// Non è il solito `EmptyState` generico usato per leghe o calendario:
/// questa è la sezione più importante della Home, quindi la teniamo nella
/// stessa famiglia visiva della card della partita (bordo, raggio, alone
/// verde) invece di farla sembrare un errore o un buco nel layout. Il
/// pulsante porta al calendario, la stessa rotta già usata dal "Vedi tutte"
/// più sotto nella pagina.
class _EmptyHeroMatch extends StatelessWidget {
  const _EmptyHeroMatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outline),
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: .08), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primary.withValues(alpha: .14),
            child: const Icon(Icons.event_available, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Il calendario è libero',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          const Text(
            'Quando un admin crea una partita, la troverai subito qui.',
            style: TextStyle(color: AppTheme.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/matches'),
            child: const Text('Vedi il calendario'),
          ),
        ],
      ),
    );
  }
}

/// Fascia a piena larghezza per l'Overall, il voto di sintesi della stagione.
///
/// Separarla dalla `StatGrid` risolve due cose insieme: niente più tessera
/// spaiata nell'ultima riga della griglia (vedi il commento dove viene
/// costruita) e più risalto per l'unico numero "di sintesi" della sezione,
/// che prima si perdeva visivamente in mezzo ai quattro conteggi.
class _OverallBanner extends StatelessWidget {
  const _OverallBanner({required this.value});

  final Object value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.onPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            'Overall',
            style: TextStyle(
              color: AppTheme.onPrimary.withValues(alpha: .8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card della prossima partita: l'elemento più importante della Home.
///
/// È l'unica card della pagina con un'ombra propria: le altre restano piatte
/// (elevation 0, da tema) per non appesantire lo scroll, ma qui un'ombra
/// verde molto tenue la fa percepire come "sollevata" sopra il resto — il
/// tocco premium richiesto, senza aggiungere rumore visivo altrove.
class _HeroMatch extends StatelessWidget {
  const _HeroMatch({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: .10),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/matches/${match.id}'),
          // Stesso raggio del tema (AppTheme.radiusLg) usato dal gradiente
          // qui sotto: prima erano due numeri hard-coded diversi (20 la Card,
          // 22 l'altra card della pagina) che per puro caso combaciavano più
          // o meno col resto — con la costante combaciano sempre.
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: .13),
                  Colors.transparent,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Chip(
                            backgroundColor: AppTheme.primary,
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: AppTheme.background,
                              fontWeight: FontWeight.w900,
                            ),
                            label: Text(
                              match.footballFormat.replaceAll('v', ' vs '),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            match.leagueName,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            match.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    if (match.currentResponse == 'going')
                      const Chip(
                        backgroundColor: AppTheme.primary,
                        side: BorderSide.none,
                        avatar: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.background,
                        ),
                        labelStyle: TextStyle(
                          color: AppTheme.background,
                          fontWeight: FontWeight.w900,
                        ),
                        label: Text('Confermato'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'EEE dd MMM · HH:mm',
                          'it_IT',
                        ).format(match.startsAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(match.locationName)),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${match.goingCount}/${match.maxPlayers} giocatori',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${match.maxPlayers - match.goingCount} posti',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (match.goingCount / match.maxPlayers).clamp(
                          0,
                          1,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.push('/matches/${match.id}'),
                    child: const Text('Visualizza partita'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
