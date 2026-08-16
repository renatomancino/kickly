import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    // Il FutureBuilder sta *sopra* lo Scaffold e non dentro al body: serve per
    // poter intitolare la AppBar con il nome della lega invece del generico
    // "Lega". Non è un vezzo — la testata con il nome scorre via appena si
    // sfoglia un tab, e da lì in poi la barra in alto era l'unica cosa ferma
    // sullo schermo senza dire in quale lega ci si trova.
    return FutureBuilder<
      (
        LeagueDetail?,
        List<MatchSummary>,
        List<LeagueCommunication>,
        List<LeaderboardPlayer>,
      )
    >(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.connectionState == ConnectionState.done
            ? snapshot.data?.$1
            : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              detail?.summary.name ?? 'Lega',
              // Un nome lungo qui non può andare a capo (la AppBar ha
              // un'altezza fissa): senza ellissi verrebbe tagliato a metà
              // carattere con l'overflow giallo-nero in debug.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(child: _body(context, snapshot, detail)),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<
      (
        LeagueDetail?,
        List<MatchSummary>,
        List<LeagueCommunication>,
        List<LeaderboardPlayer>,
      )
    >
    snapshot,
    LeagueDetail? detail,
  ) {
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
              child: _LeagueHeader(detail: detail, onRefresh: onRefresh),
            ),
          ),
          const SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              TabBar(
                isScrollable: true,
                // Con `isScrollable` Material 3 usa di default
                // `TabAlignment.startOffset`, che stacca il primo tab dal bordo
                // di una cinquantina di pixel: la fila di tab risultava
                // disallineata rispetto ai 20px di margine di tutto il resto
                // della pagina, come se fosse già stata scorsa un po'.
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 12),
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

/// Testata della lega: identità prima, numeri dopo.
///
/// La versione precedente apriva con due `Chip` (formato e visibilità) messi
/// *sopra* al nome: la prima cosa che si leggeva entrando in una lega era
/// "5v5 / Privata", cioè il dettaglio più banale, e il nome arrivava dopo. Qui
/// l'ordine è quello di una carta d'identità — stemma, nome, luogo — e gli
/// attributi scendono sotto come pillole neutre, tutte uguali fra loro perché
/// nessuna delle tre conta più delle altre.
class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.detail, required this.onRefresh});

  final LeagueDetail detail;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final league = detail.summary;
    final private = league.visibility == 'private';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        // Token e non il 25 scritto a mano di prima: questa è la superficie
        // più grande della pagina, quindi prende il raggio dei contenitori
        // grandi (26) e non un valore intermedio inventato.
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.outline),
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: .10), AppTheme.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // In alto e non centrato: con un nome su due righe il logo, se
            // centrato, resterebbe sospeso a metà con un vuoto sopra, slegato
            // dal nome che dovrebbe accompagnare.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LeagueLogo(league: league, size: 66),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      // Il nome lega è testo scritto dagli utenti: due righe
                      // al massimo e poi ellissi, altrimenti un nome
                      // chilometrico allunga la testata a dismisura e spinge
                      // i tab fuori dalla prima schermata.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.mutedSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${league.city}, ${league.country}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.mutedSoft,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Wrap e non la vecchia Row con lo `Spacer()`: quella riga teneva
          // città e capienza agli estremi e con il testo di sistema ingrandito
          // i due blocchi si scontravano al centro senza poter andare a capo.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoPill(
                label: league.footballFormat.replaceAll('v', ' vs '),
                icon: Icons.sports_soccer,
              ),
              InfoPill(
                label: private ? 'Privata' : 'Pubblica',
                // Icona piena per il lucchetto chiuso, contorno per il mondo
                // aperto: l'icona da sola dice già di cosa si tratta.
                icon: private ? Icons.lock : Icons.public_outlined,
              ),
              InfoPill(
                label: '${league.memberCount}/${league.maxMembers} membri',
                icon: Icons.group_outlined,
              ),
            ],
          ),
          if (league.canManage) ...[
            const SizedBox(height: 16),
            _InviteCodeBar(
              league: league,
              code: detail.inviteCode,
              onRefresh: onRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

/// Riquadro del codice invito, per chi amministra la lega.
///
/// Prima era un `OutlinedButton` con etichetta "Invita · ABC123": il codice —
/// cioè l'unico dato che serve davvero copiare — era annegato dentro
/// un'etichetta di pulsante, con lo stesso peso della parola "Invita". Qui il
/// codice diventa il contenuto, con l'occhiello sopra a spiegare cos'è.
///
/// Sull'accento: il riquadro resta sulla superficie neutra e solo i caratteri
/// del codice si accendono di verde. È l'unico verde della testata di
/// proposito — nella tab Home il blocco acceso è il messaggio fissato, e due
/// blocchi verdi impilati si annullerebbero a vicenda.
class _InviteCodeBar extends StatelessWidget {
  const _InviteCodeBar({
    required this.league,
    required this.code,
    required this.onRefresh,
  });

  final LeagueSummary league;
  final String code;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isOwner = league.currentUserRole == 'owner';
    // Material e non Container: l'onda del tocco viene dipinta sul Material
    // antenato più vicino, che qui sarebbe lo sfondo della pagina — con un
    // Container decorato l'onda sarebbe finita *dietro* al riquadro e si
    // sarebbe allargata oltre i suoi bordi. Il Material con `shape` porta con
    // sé colore, bordo e ritaglio, così l'onda resta dentro gli angoli.
    return Material(
      color: AppTheme.surfaceHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _copy(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CODICE INVITO',
                      style: TextStyle(
                        color: AppTheme.mutedSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              // Crenatura larga: un codice si legge carattere
                              // per carattere mentre lo si detta a voce, non
                              // come una parola intera.
                              letterSpacing: 2,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: AppTheme.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwner)
            IconButton(
              // Pulsante di sola icona: senza tooltip nessuno (né un lettore
              // di schermo né chi ci passa sopra) può sapere che rigenera il
              // codice invece di ricaricare la pagina.
              tooltip: 'Genera un nuovo codice',
              color: AppTheme.muted,
              onPressed: () => _rotate(context),
              icon: const Icon(Icons.autorenew, size: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Codice invito copiato.')));
  }

  Future<void> _rotate(BuildContext context) async {
    // Aptico qui e non sulla copia: rigenerare il codice invalida quello
    // vecchio (chi ce l'ha in chat non entra più), quindi è un cambio di
    // stato vero. `unawaited` perché la regola unawaited_futures è attiva e
    // perché la vibrazione non deve far aspettare la chiamata di rete.
    unawaited(HapticFeedback.mediumImpact());
    await AppScope.of(context).repository.rotateLeagueInvite(league.id);
    await onRefresh();
    if (!context.mounted) return;
    // Prima della rifinitura questa azione non dava alcun riscontro: il codice
    // cambiava sotto gli occhi e restava il dubbio se il tocco fosse andato a
    // buon fine o se il codice fosse sempre stato quello.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nuovo codice invito generato.')),
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
    // Sfondo pieno e non trasparente: la barra è `pinned`, quindi il contenuto
    // del tab le scorre sotto e senza un fondo opaco le scritte dei tab si
    // sovrapporrebbero alle card in transito.
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
    final league = detail.summary;
    final upcoming = matches.where((match) => !match.isPast).toList();
    final pinned = communications.where((item) => item.pinned).firstOrNull;
    final admins = detail.members
        .where(
          (item) => item.leagueRole == 'admin' || item.leagueRole == 'owner',
        )
        .length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pinned != null) ...[
          _PinnedBanner(item: pinned),
          const SizedBox(height: 16),
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
                  league.description ??
                      'Una lega Kickly pronta per nuove partite e rivalità.',
                  style: const TextStyle(color: AppTheme.muted, height: 1.45),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        icon: Icons.group_outlined,
                        label: 'Membri',
                        value: '${detail.members.length}',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      // Conta anche il proprietario, non solo chi ha ruolo
                      // 'admin': la domanda a cui la casella risponde è
                      // "quante persone possono gestire questa lega", e il
                      // proprietario è la prima di quelle persone.
                      child: _Metric(
                        icon: Icons.shield_outlined,
                        label: 'Admin',
                        value: '$admins',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      // Al posto del "Formato": quello è già una pillola nella
                      // testata due centimetri più su, e ripetere lo stesso
                      // dato spreca una delle tre caselle. Il numero di
                      // partite invece non compare da nessun'altra parte in
                      // questa schermata.
                      child: _Metric(
                        icon: Icons.event_outlined,
                        label: 'Partite',
                        value: '${matches.length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(
          title: 'Prossima partita',
          eyebrow: 'Calendario',
          trailing: upcoming.length > 1
              ? TextButton(
                  // Grigio e non verde: in questa tab l'unico elemento che si
                  // accende è il messaggio fissato, e un collegamento verde
                  // qui sotto se ne contenderebbe l'attenzione.
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () =>
                      DefaultTabController.of(context).animateTo(2),
                  child: Text('Tutte (${upcoming.length})'),
                )
              : null,
        ),
        const SizedBox(height: 11),
        if (upcoming.isEmpty)
          // Stato vuoto differenziato per ruolo: a un admin il vicolo cieco ha
          // un'uscita (creare la partita), a un membro no — e proporgliela
          // sarebbe solo un pulsante che poi il server rifiuta.
          EmptyState(
            icon: Icons.event_busy,
            title: league.canManage
                ? 'Calendario da riempire'
                : 'Nessuna partita in programma',
            body: league.canManage
                ? 'Fissa la prossima sfida: i membri la vedranno subito nella loro dashboard.'
                : 'Quando un admin fisserà la prossima sfida la troverai qui.',
            action: league.canManage
                ? FilledButton.icon(
                    onPressed: () =>
                        context.push('/matches/new?league=${league.id}'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crea partita'),
                  )
                : null,
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

/// Richiamo al messaggio fissato, in cima alla tab Home.
///
/// È l'unico blocco acceso della schermata: un avviso fissato da un admin è
/// per definizione la cosa che chi entra deve leggere prima di tutto. Rispetto
/// a prima porta anche autore e data — un avviso senza firma né data non si sa
/// se sia di stamattina o di tre mesi fa, e la decisione di leggerlo o meno
/// dipende esattamente da quello.
class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({required this.item});

  final LeagueCommunication item;

  @override
  Widget build(BuildContext context) {
    // Come per il codice invito: Material invece di Container + InkWell, così
    // l'onda del tocco resta dentro gli angoli arrotondati invece di essere
    // dipinta sul Material della pagina dietro al riquadro colorato.
    return Material(
      color: AppTheme.primary.withValues(alpha: .10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: .45)),
      ),
      child: InkWell(
        onTap: () => DefaultTabController.of(context).animateTo(1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.push_pin, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'MESSAGGIO FISSATO',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                item.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  PlayerAvatar(
                    name: item.authorName,
                    url: item.authorAvatarUrl,
                    radius: 10,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      item.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    ' · ',
                    style: TextStyle(color: AppTheme.mutedSoft, fontSize: 11.5),
                  ),
                  Text(
                    _relativeDate(item.createdAt),
                    style: const TextStyle(
                      color: AppTheme.mutedSoft,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Casella compatta di un numero della lega, dentro la card "Dentro la lega".
///
/// Non è una [StatTile]: quella è alta 104px ed è pensata per le griglie di
/// statistiche a tutta pagina; qui le caselle stanno tre per riga dentro una
/// card e devono restare basse per non trasformarla in un cruscotto.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceHigh,
      // Token invece del 14 di prima: qui dentro serve il raggio dei
      // contenitori piccoli, altrimenti la casella ha angoli leggermente
      // diversi dagli input e dai pulsanti a fianco.
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.outline),
    ),
    child: Column(
      children: [
        Icon(icon, size: 15, color: AppTheme.muted),
        const SizedBox(height: 7),
        // FittedBox come nelle StatTile: con il testo di sistema ingrandito un
        // numero a tre cifre usciva dalla casella, che è larga un terzo di card.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
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
    // Divisione in due gruppi e non riordino: l'ordine con cui la RPC le
    // restituisce resta quello, ma passate e future non si mescolano più nella
    // stessa colonna. Prima, scorrendo, si passava da una partita di domani a
    // una di tre mesi fa senza alcun segnale di confine.
    final upcoming = matches.where((match) => !match.isPast).toList();
    final past = matches.where((match) => match.isPast).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (league.canManage) ...[
          SizedBox(
            width: double.infinity,
            // L'unico pieno di verde della tab: è l'azione che crea qualcosa e
            // il motivo per cui un admin apre questa scheda.
            child: FilledButton.icon(
              onPressed: () => context.push('/matches/new?league=${league.id}'),
              icon: const Icon(Icons.add),
              label: const Text('Crea partita'),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (matches.isEmpty)
          EmptyState(
            icon: Icons.sports_soccer,
            title: 'Calendario vuoto',
            body: league.canManage
                ? 'Nessuna partita in archivio: crea la prima con il pulsante qui sopra.'
                : 'Gli admin non hanno ancora messo in calendario nessuna partita.',
          )
        else ...[
          if (upcoming.isNotEmpty) ...[
            const _ListGroupHeader(label: 'In programma'),
            ...upcoming.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: MatchCard(
                  match: match,
                  onTap: () => context.push('/matches/${match.id}'),
                ),
              ),
            ),
          ],
          if (past.isNotEmpty) ...[
            _ListGroupHeader(
              label: 'Archivio',
              topSpacing: upcoming.isEmpty ? 0 : 12,
            ),
            ...past.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: MatchCard(
                  match: match,
                  onTap: () => context.push('/matches/${match.id}'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Intestazione leggera per i gruppi dentro una lista.
///
/// Non è un [SectionTitle]: quello è l'intestazione grande di una pagina, qui
/// invece si ripete più volte nella stessa colonna e deve restare defilato,
/// come un separatore etichettato più che come un titolo.
class _ListGroupHeader extends StatelessWidget {
  const _ListGroupHeader({required this.label, this.topSpacing = 0});

  final String label;
  final double topSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topSpacing, bottom: 10, left: 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );
}

/// Pillola del ruolo di lega di un membro.
///
/// Nell'elenco leghe abbiamo stabilito che fra i metadati di una lega il RUOLO
/// è l'unico che merita l'accento, perché è l'unico che dice cosa uno *può
/// fare* lì dentro. Qui vale lo stesso, riga per riga: chi amministra si
/// accende, chi è membro semplice resta una pillola neutra. Scorrendo la rosa
/// si vede subito a chi chiedere di aprire una partita senza leggere un nome.
///
/// Owner e admin si distinguono con la stessa icona in due pesi — scudo pieno
/// per il proprietario, scudo di contorno per l'admin — invece che con due
/// forme diverse: sono lo stesso tipo di potere, uno solo è quello definitivo.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    // Etichetta tradotta e non il valore grezzo del database: prima qui
    // compariva letteralmente "owner" in mezzo a un'interfaccia in italiano.
    final label = leagueRoleLabel(role);
    final owner = role == 'owner';
    if (!owner && role != 'admin') {
      return InfoPill(label: label, icon: Icons.person_outline);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owner ? Icons.shield : Icons.shield_outlined,
            size: 13,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.detail, required this.onRefresh});
  final LeagueDetail detail;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Copia ordinata: prima il proprietario, poi gli admin, poi i membri, e
    // dentro ogni gruppo in ordine alfabetico. La rosa arrivava in ordine di
    // iscrizione, quindi chi comanda poteva stare a metà elenco e per capire
    // "a chi devo chiedere" toccava scorrere tutto. È un riordino di sola
    // presentazione: i dati e le azioni restano quelli.
    final members = [...detail.members]
      ..sort((a, b) {
        final rank = _roleRank(a.leagueRole).compareTo(_roleRank(b.leagueRole));
        if (rank != 0) return rank;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    final canManage = detail.summary.canManage;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      // +1 per l'intestazione in testa alla lista.
      itemCount: members.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 13 : 9),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SectionTitle(
            eyebrow: 'Rosa',
            title:
                '${members.length} '
                '${members.length == 1 ? 'membro' : 'membri'}',
          );
        }
        final member = members[index - 1];
        return _MemberTile(
          member: member,
          // Il proprietario non è gestibile da nessuno, nemmeno da sé stesso:
          // le voci del menu (declassa, trasferisci, rimuovi) non hanno senso
          // applicate a lui.
          menu: canManage && member.leagueRole != 'owner'
              ? PopupMenuButton<String>(
                  // Il tooltip predefinito è "Show menu", che non dice su chi
                  // agisce: in una lista di venti righe identiche il nome è
                  // l'unica cosa che disambigua per un lettore di schermo.
                  tooltip: 'Gestisci ${member.displayName}',
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
                      // Rosso: è l'unica voce del menu che toglie qualcosa a
                      // qualcuno, e in un elenco di voci tutte uguali era
                      // indistinguibile dalle altre fino a dopo il tocco.
                      child: Text(
                        'Rimuovi dalla lega',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  /// Peso di ordinamento del ruolo: più basso, più in alto nella rosa.
  static int _roleRank(String role) => switch (role) {
    'owner' => 0,
    'admin' => 1,
    _ => 2,
  };

  Future<void> _memberAction(
    BuildContext context,
    LeagueMember member,
    String action,
  ) async {
    // "Trasferisci proprietà" era l'unica voce del menu senza conferma
    // (Lascia/Elimina lega ce l'hanno): un tap accidentale sul menu
    // trasferiva la proprietà della lega in modo irreversibile con un
    // solo tocco.
    if (action == 'owner') {
      // Aptico prima del dialog, come in "Lascia lega": il primo momento in
      // cui l'utente dichiara l'intenzione è il tocco sulla voce di menu, non
      // la conferma. `unawaited` perché il dialog non deve aspettare il
      // motore aptico per aprirsi.
      unawaited(HapticFeedback.mediumImpact());
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Trasferire la proprietà?'),
          content: Text(
            '${member.displayName} diventerà il nuovo proprietario della lega. '
            'Non potrai annullare questa azione da qui.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Trasferisci'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) return;
    }
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

/// Riga di un membro della rosa.
///
/// Sostituisce la `ListTile` di prima per due motivi. Il primo è il ruolo: la
/// ListTile mostrava la pillola *oppure* il menu di gestione, quindi per un
/// admin il suo ruolo spariva del tutto e restava solo il "⋮" — la sola
/// persona di cui interessava sapere il ruolo era l'unica a non mostrarlo. Il
/// secondo è il raggio dell'onda del tocco, che con la ListTile è quello di
/// default e non quello della Card che la contiene.
///
/// La pillola del ruolo sta sotto al nome e non in fondo alla riga: allineata
/// a destra doveva dividersi la larghezza con nome, avatar e menu, e su uno
/// schermo da 360dp a "Proprietario" (l'etichetta più lunga, e proprio quella
/// della riga che conta di più) restavano una settantina di pixel per il nome.
/// Sotto, invece, tutte le pillole partono dalla stessa ascissa: la colonna dei
/// ruoli si legge in verticale anche meglio di prima, senza rubare spazio.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.menu});

  final LeagueMember member;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/player/${member.username}'),
        // Stesso raggio della Card: con un valore diverso l'onda del tocco
        // esce dagli angoli arrotondati che dovrebbero contenerla.
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, menu == null ? 14 : 4, 12),
          child: Row(
            // In alto: la colonna di destra è alta due righe più la pillola, e
            // centrata lascerebbe l'avatar a mezz'aria rispetto al nome.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerAvatar(
                name: member.displayName,
                url: member.avatarUrl,
                radius: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      // Nome scritto dall'utente: una riga sola, altrimenti
                      // due nomi lunghi rendono le righe di altezza diversa e
                      // l'elenco perde il ritmo.
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${member.username} · ${_footballRoleLabel(member.footballRole)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RolePill(role: member.leagueRole),
                  ],
                ),
              ),
              // `?menu`: elemento null-aware, cioè "mettilo solo se c'è".
              // Equivale a `if (menu != null) menu!` ma senza il `!`, che è
              // proprio l'operatore che la regola use_null_aware_elements
              // vuole togliere di mezzo.
              ?menu,
            ],
          ),
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    final canManage = detail.summary.canManage;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (canManage) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _compose(context),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Nuova comunicazione'),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (items.isEmpty)
          // Due vicoli ciechi diversi: l'admin può uscirne scrivendo, il
          // membro può solo aspettare — e dirgli "scrivi il primo avviso"
          // sarebbe un invito a premere un pulsante che non ha.
          EmptyState(
            icon: Icons.campaign_outlined,
            title: canManage ? 'Nessun avviso pubblicato' : 'Ancora silenzio',
            body: canManage
                ? 'Convocazioni, regole del campo, cambi di orario: qui arrivano a tutti i membri in una volta sola.'
                : 'Gli avvisi degli admin della lega compariranno qui.',
            action: canManage
                ? FilledButton.icon(
                    onPressed: () => _compose(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Scrivi il primo avviso'),
                  )
                : null,
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _CommunicationCard(
                item: item,
                canManage: canManage,
                onDeleted: onRefresh,
              ),
            ),
          ),
      ],
    );
  }

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

/// Card di un avviso della lega.
///
/// Riordinata secondo l'ordine in cui la si legge davvero: prima *chi* e
/// *quando* (la firma decide se vale la pena leggere), poi il titolo, poi il
/// testo. Prima la data stava in fondo, minuscola e nel formato grezzo
/// `7/3/2026`, cioè nel punto in cui non serviva più a nessuno.
class _CommunicationCard extends StatelessWidget {
  const _CommunicationCard({
    required this.item,
    required this.canManage,
    required this.onDeleted,
  });

  final LeagueCommunication item;
  final bool canManage;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    return Card(
      // Solo l'avviso fissato cambia bordo: è l'unico segnale di gerarchia
      // dentro una colonna di card altrimenti tutte identiche. Il colore pieno
      // resta al pulsante "Nuova comunicazione" in cima alla tab.
      shape: item.pinned
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: BorderSide(color: AppTheme.primary.withValues(alpha: .40)),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, canManage ? 6 : 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerAvatar(
                  name: item.authorName,
                  url: item.authorAvatarUrl,
                  radius: 17,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        // Data relativa e non "7/3/2026": l'unica domanda che
                        // ci si fa scorrendo gli avvisi è "questo è recente?",
                        // e "oggi · 18:30" ci risponde senza far fare i conti.
                        '@${item.authorUsername} · ${_relativeDate(item.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.mutedSoft,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.pinned) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 11, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          'FISSATO',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (canManage)
                  IconButton(
                    // Tooltip perché è un pulsante di sola icona, e rosso
                    // perché è l'unico comando distruttivo della card: prima
                    // era un cestino grigio identico a qualunque altra icona.
                    tooltip: 'Elimina la comunicazione',
                    color: AppTheme.danger,
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, size: 19),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              item.body,
              // Interlinea larga e non compressa: il corpo di un avviso è
              // l'unico blocco di prosa dell'app e a interlinea stretta
              // diventava il "muro di testo" che rendeva la tab illeggibile.
              style: const TextStyle(
                color: AppTheme.foreground,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    // Aptico: eliminare un avviso è un cambio di stato irreversibile, ed è
    // l'unico riscontro fisico che qualcosa è successo davvero.
    unawaited(HapticFeedback.mediumImpact());
    await AppScope.of(context).repository.deleteLeagueCommunication(item.id);
    await onDeleted();
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
    content: SizedBox(
      // Larghezza esplicita: senza, l'AlertDialog si stringe attorno al
      // contenuto e i due campi diventano strettissimi su schermi larghi.
      width: 380,
      child: SingleChildScrollView(
        // Scorrevole perché con la tastiera aperta su un telefono basso lo
        // spazio residuo non basta per due campi più l'interruttore, e il
        // contenuto sfondava il dialog invece di poter scorrere.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Messaggio'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              title: const Text('Fissa in alto'),
              // Sottotitolo: "fissa in alto" non dice dove finisce il
              // messaggio, e l'effetto vero (comparire nella Home della lega)
              // è la ragione per cui si accende l'interruttore.
              subtitle: const Text(
                'Compare anche nella Home della lega.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
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

/// Metriche della classifica: etichetta, icona spenta, icona accesa e unità.
///
/// L'icona esiste in due versioni perché il linguaggio dell'app vuole i
/// contorni per lo stato inattivo e il pieno per l'attivo: è un secondo
/// segnale, oltre al colore, di quale classifica si sta guardando.
const _leaderboardMetrics = <String, (String, IconData, IconData, String)>{
  'overall': ('Overall', Icons.bolt_outlined, Icons.bolt, 'ovr'),
  'goals': ('Gol', Icons.sports_soccer_outlined, Icons.sports_soccer, 'gol'),
  'assists': (
    'Assist',
    Icons.assistant_direction_outlined,
    Icons.assistant_direction,
    'assist',
  ),
  'mvp': ('MVP', Icons.emoji_events_outlined, Icons.emoji_events, 'mvp'),
  'matches': (
    'Presenze',
    Icons.calendar_month_outlined,
    Icons.calendar_month,
    'presenze',
  ),
};

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
    final unit = _leaderboardMetrics[metric]!.$4;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Wrap di pillole a larghezza naturale al posto della vecchia griglia
        // a due colonne calcolata con LayoutBuilder: i pulsanti erano tutti
        // larghi uguale e le etichette corte ("Gol", "MVP") venivano ingrandite
        // dal FittedBox fino a stonare con quelle lunghe.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _leaderboardMetrics.entries
              .map(
                (entry) => _MetricChip(
                  label: entry.value.$1,
                  icon: metric == entry.key ? entry.value.$3 : entry.value.$2,
                  selected: metric == entry.key,
                  onTap: () => setState(() => metric = entry.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        if (players.isEmpty)
          const EmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'Classifica in attesa',
            body:
                'I numeri compaiono quando la prima partita della lega viene '
                'chiusa con risultati e marcatori.',
          )
        else
          ...players.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _LeaderRow(
                rank: entry.$1 + 1,
                player: entry.$2,
                value: _value(entry.$2),
                unit: unit,
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

/// Pillola di selezione della metrica in classifica.
///
/// Prima le cinque metriche erano cinque `FilledButton` tutti verdi — quella
/// selezionata piena, le altre quattro con fondo e bordo verde tenue: la
/// schermata si apriva con cinque accenti, e quindi con nessuno. Qui le
/// spente sono grigie come qualunque altro comando neutro e solo la scelta
/// attiva porta il colore del marchio.
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.onPrimary : AppTheme.foreground;
    return Material(
      color: selected ? AppTheme.primary : AppTheme.surfaceHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga della classifica.
///
/// Il valore della metrica non è più verde: prima ogni riga aveva il proprio
/// numerone acceso e la colonna intera diventava una parete di verde, così il
/// podio — l'unica cosa che in una classifica si cerca a colpo d'occhio — non
/// si distingueva dal quindicesimo posto. Adesso il segnale sta nel medaglione
/// del piazzamento e il valore resta bianco, leggibile e uguale per tutti.
class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.player,
    required this.value,
    required this.unit,
  });

  final int rank;
  final LeaderboardPlayer player;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/player/${player.username}'),
        // Stesso raggio della Card, altrimenti l'onda esce dagli angoli.
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
          child: Row(
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 11),
              // L'avatar c'era nei dati (`avatarUrl`) ma non veniva usato: una
              // classifica di soli numeri e nomi si legge come un tabulato,
              // con le facce si riconoscono i compagni di squadra al volo.
              PlayerAvatar(
                name: player.name,
                url: player.avatarUrl,
                radius: 18,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${player.username} · ${player.matches} '
                      '${player.matches == 1 ? 'partita' : 'partite'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -.5,
                    ),
                  ),
                  // Unità sotto al numero: cambiando metrica cambia anche
                  // questa, così la colonna dice sempre di cosa sono i numeri
                  // senza dover risalire alla pillola selezionata in cima.
                  Text(
                    unit.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.mutedSoft,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Medaglione del piazzamento.
///
/// L'oro è già il colore dei trofei e dei giocatori "elite" nell'app, quindi
/// qui indica il podio e non c'è bisogno di inventare un secondo linguaggio.
/// Solo il primo posto è pieno: secondo e terzo lo portano appena accennato,
/// dal quarto in giù il medaglione torna neutro. Tre gradi bastano — con
/// cinque sfumature il podio smetterebbe di essere un podio.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    final podium = rank <= 3;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: first
            ? AppTheme.gold
            : podium
            ? AppTheme.gold.withValues(alpha: .14)
            : AppTheme.surfaceHigh,
        border: Border.all(
          color: podium
              ? AppTheme.gold.withValues(alpha: .5)
              : AppTheme.outline,
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          // Testo scuro sull'oro pieno: l'oro è chiaro, il bianco su bianco
          // non si leggerebbe.
          color: first
              ? AppTheme.background
              : podium
              ? AppTheme.gold
              : AppTheme.muted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
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
        if (players.isEmpty)
          // Senza questo, una lega nuova mostrava quattro tessere di zeri:
          // legge come un guasto, non come "non è ancora successo niente".
          const EmptyState(
            icon: Icons.query_stats,
            title: 'Ancora nessun numero',
            body:
                'Le statistiche della lega si riempiono da sole appena una '
                'partita viene chiusa con risultati e marcatori.',
          )
        else
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
              // L'unica tessera accesa della tab: le altre tre contano eventi
              // (quante volte è successo qualcosa), questa è l'unica che dice
              // com'è fatta la lega — quanto vale chi ci gioca.
              StatTile(
                label: 'OVR medio',
                value: average,
                icon: Icons.auto_graph,
                highlight: true,
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
    // Il proprietario si ricava dalla rosa già caricata: `ownerId` da solo è
    // un UUID, che nella scheda informazioni non dice niente a nessuno.
    final owner = detail.members
        .where((member) => member.userId == detail.ownerId)
        .firstOrNull;
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
                if (owner != null) ...[
                  const Divider(height: 27),
                  _InfoRow(label: 'Proprietario', value: owner.displayName),
                ],
                const Divider(height: 27),
                _InfoRow(
                  label: 'Il tuo ruolo',
                  // `roleLabel` e non `currentUserRole`: qui compariva il
                  // valore grezzo del database, cioè letteralmente "owner".
                  value: league.roleLabel,
                  // L'unico accento della tab, e coerente con l'elenco leghe:
                  // fra tutte le righe, l'unica che dice cosa PUOI FARE qui
                  // dentro è il tuo ruolo — e conta solo se è un ruolo che ti
                  // dà dei poteri.
                  accent: league.canManage,
                ),
              ],
            ),
          ),
        ),
        if (league.canManage) ...[
          const SizedBox(height: 24),
          const SectionTitle(eyebrow: 'Amministrazione', title: 'Gestisci'),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/leagues/${league.slug}/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Impostazioni lega'),
            ),
          ),
        ],
        if (league.currentUserRole != 'owner') ...[
          const SizedBox(height: 24),
          // Sezione a sé e non un secondo pulsante identico sotto a
          // "Impostazioni": erano due OutlinedButton uguali, uno apriva un
          // modulo e l'altro ti buttava fuori dalla lega.
          const SectionTitle(eyebrow: 'Uscita', title: 'Lascia la lega'),
          const SizedBox(height: 8),
          const Text(
            'Perdi accesso a partite, classifiche e comunicazioni. '
            'Per rientrare servirà un nuovo invito.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // Rosso, non neutro: è l'unica azione della pagina che toglie
              // qualcosa a chi la preme, e deve riconoscersi prima del tocco.
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: BorderSide(color: AppTheme.danger.withValues(alpha: .45)),
              ),
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
    // `unawaited`: la vibrazione deve partire *insieme* al dialog, non prima,
    // altrimenti l'apertura della conferma aspetterebbe il motore aptico.
    unawaited(HapticFeedback.mediumImpact());
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
    try {
      await AppScope.of(context).repository.leaveLeague(detail.summary.id);
      if (context.mounted) context.go('/leagues');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.muted)),
      const SizedBox(width: 14),
      // Expanded al posto della coppia Spacer + Flexible di prima: quei due
      // erano entrambi flessibili con lo stesso peso, quindi si spartivano lo
      // spazio a metà e il valore poteva usarne solo la parte destra anche
      // quando l'etichetta a sinistra era cortissima. Con Expanded il valore
      // prende tutto lo spazio libero e `textAlign: right` lo tiene comunque
      // incollato al bordo: stesso aspetto, ma il doppio di respiro.
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          // Città e paese arrivano dagli utenti: senza limite, un valore lungo
          // spinge la riga a occupare mezza card.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: accent ? AppTheme.primary : AppTheme.foreground,
          ),
        ),
      ),
    ],
  );
}

/// Ruolo in campo del giocatore, tradotto.
String _footballRoleLabel(String? role) => switch (role) {
  'goalkeeper' => 'Portiere',
  'defender' => 'Difensore',
  'midfielder' => 'Centrocampista',
  'forward' => 'Attaccante',
  _ => 'Giocatore',
};

/// Data di un avviso, espressa rispetto a oggi.
///
/// Serve a rispondere alla sola domanda che ci si fa scorrendo le
/// comunicazioni: "è roba fresca?". Oltre la settimana la distanza relativa
/// smette di aiutare ("23 giorni fa" non dice nulla) e si torna alla data.
String _relativeDate(DateTime when) {
  final now = DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'oggi · ${DateFormat('HH:mm').format(when)}';
  if (days == 1) return 'ieri · ${DateFormat('HH:mm').format(when)}';
  // `days > 1` e non solo `days < 7`: se l'orologio del dispositivo è indietro
  // rispetto al server la differenza diventa negativa, e senza questo limite
  // un avviso appena pubblicato si sarebbe letto "-1 giorni fa".
  if (days > 1 && days < 7) return '$days giorni fa';
  if (day.year == today.year) return DateFormat('d MMM', 'it_IT').format(when);
  return DateFormat('d MMM y', 'it_IT').format(when);
}
