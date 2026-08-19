import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'lineup_board.dart';

class MatchDetailPage extends StatefulWidget {
  const MatchDetailPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  Future<MatchDetail?>? _future;
  bool _responding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getMatch(widget.matchId);
  }

  Future<void> _reload() async {
    final next = AppScope.of(context).repository.getMatch(widget.matchId);
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

  Future<void> _respond(String response) async {
    setState(() => _responding = true);
    try {
      await AppScope.of(context).repository
          .setMatchResponse(widget.matchId, response);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Risposta aggiornata.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partita')),
      body: SafeArea(
        child: FutureBuilder<MatchDetail?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ListSkeleton(items: 2);
            }
            if (snapshot.hasError) {
              return PageFrame(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Partita non disponibile',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _reload,
                    child: const Text('Riprova'),
                  ),
                ),
              );
            }
            final match = snapshot.data;
            if (match == null) {
              return const PageFrame(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'Partita non trovata',
                  body: 'Potresti non avere accesso a questo evento.',
                ),
              );
            }
            return _MatchContent(
              match: match,
              responding: _responding,
              onRespond: _respond,
              onReload: _reload,
            );
          },
        ),
      ),
    );
  }
}

class _MatchContent extends StatelessWidget {
  const _MatchContent({
    required this.match,
    required this.responding,
    required this.onRespond,
    required this.onReload,
  });

  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final summary = match.summary;
    final date = DateFormat('EEEE d MMMM y', 'it_IT').format(summary.startsAt);
    final time = DateFormat('HH:mm').format(summary.startsAt);
    // Conteggio, non stato: la pillola qui sotto legge `summary.status`, che
    // lo decide il server, mentre questo confronto serve solo al testo dei
    // posti liberi. Sono due cose diverse di proposito — una partita può
    // essere 'open' con i posti esauriti, e il testo deve dirlo anche se la
    // pillola resta verde. `maxPlayers > 0` evita di dichiarare piena una
    // partita senza capienza impostata.
    final isFull =
        summary.maxPlayers > 0 && summary.goingCount >= summary.maxPlayers;
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 7, 20, 18),
              child: Card(
                child: Container(
                  padding: const EdgeInsets.all(21),
                  decoration: BoxDecoration(
                    // Lo stesso raggio della Card che lo contiene, preso dal
                    // token invece che da un 20 scritto a mano: la Card ritaglia
                    // a 18, quindi con 20 il gradiente veniva tagliato e agli
                    // angoli restava un filo di superficie piatta al posto
                    // della sfumatura.
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: .12),
                        Colors.transparent,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (match.coverImageUrl?.isNotEmpty == true) ...[
                        ClipRRect(
                          // radiusMd e non radiusLg: questa copertina sta
                          // DENTRO la card, e un elemento annidato con lo stesso
                          // raggio del contenitore sembra una seconda card
                          // incastrata. Il raggio piu' stretto lo tiene
                          // subordinato. (La foto del campo piu' in basso, che
                          // invece sta al livello delle card, usa radiusLg.)
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: match.coverImageUrl!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Lo stato viene per primo: è l'unica di queste
                          // etichette che cambia nel tempo (aperta -> completa
                          // -> conclusa/annullata), quindi è quella che l'occhio
                          // deve trovare per prima. Pillola colorata, con la
                          // stessa "voce" delle pillole di risposta/distanza
                          // usate dalla card partite in lista.
                          _StatusPill.matchStatus(summary.status),
                          // Il formato è un attributo fisso della partita, non
                          // uno stato: pillola neutra del design system, così
                          // non compete con lo stato qui accanto. Prima era un
                          // Chip di Material, cioè il linguaggio vecchio che
                          // stiamo togliendo.
                          InfoPill(
                            label: summary.footballFormat.replaceAll(
                              'v',
                              ' vs ',
                            ),
                            icon: Icons.sports_soccer,
                          ),
                          // Anche il campo prenotato è uno stato, quindi resta
                          // colorato — ma tinto come le altre pillole invece che
                          // a fondo verde pieno. Riempito era l'elemento più
                          // urlato dell'intera testata e schiacciava proprio lo
                          // stato della partita, che è ciò da cui dipende la
                          // decisione di giocare; la prenotazione ha già una sua
                          // card verde nella scheda Dettagli, qui basta il
                          // fatto.
                          if (match.fieldBookedAt != null)
                            const _StatusPill.fieldBooked(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Titolo e nome lega li scrivono gli utenti: senza un
                      // tetto alle righe un nome fiume in headlineMedium
                      // spingeva data, luogo e barra dei posti sotto la piega,
                      // cioè proprio i dati per cui si apre questa pagina.
                      Text(
                        summary.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.leagueName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.event, color: AppTheme.primary),
                          const SizedBox(width: 9),
                          Expanded(child: Text(date)),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 9),
                          // Anche il nome del campo è testo utente: due righe
                          // al massimo, poi ellissi, altrimenti una struttura
                          // con un nome lunghissimo allontanava la barra dei
                          // posti dal blocco data/luogo a cui appartiene.
                          Expanded(
                            child: Text(
                              summary.locationName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 19),
                      LinearProgressIndicator(
                        value: (summary.goingCount / summary.maxPlayers).clamp(
                          0,
                          1,
                        ),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 7),
                      // Stesso linguaggio della card della lista partite
                      // (MatchCard in core/widgets/common.dart): "posti
                      // liberi" invece del solo conteggio, verde e in
                      // grassetto quando è piena. Prima c'era sempre e solo
                      // "x/y confermati" in grigio, anche a posti esauriti,
                      // quindi lista e dettaglio raccontavano la stessa cosa
                      // con due voci diverse.
                      Text(
                        isFull
                            ? 'Al completo · ${summary.goingCount}/${summary.maxPlayers}'
                            : '${summary.goingCount}/${summary.maxPlayers} confermati · ${summary.maxPlayers - summary.goingCount} posti liberi',
                        style: TextStyle(
                          color: isFull ? AppTheme.primary : AppTheme.muted,
                          fontSize: 12,
                          fontWeight: isFull
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverPersistentHeader(
            pinned: true,
            delegate: _MatchTabDelegate(
              TabBar(
                tabs: [
                  Tab(text: 'Dettagli'),
                  Tab(text: 'Giocatori'),
                  Tab(text: 'Formazione'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _DetailsTab(
              match: match,
              responding: responding,
              onRespond: onRespond,
              onReload: onReload,
            ),
            _PlayersTab(participants: match.participants),
            LineupBoard(match: match),
          ],
        ),
      ),
    );
  }
}

class _MatchTabDelegate extends SliverPersistentHeaderDelegate {
  const _MatchTabDelegate(this.tabBar);
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
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.background,
      // Ombra solo quando c'è contenuto che scorre sotto la barra: è il
      // segnale che comunica "sei agganciata in cima", non decorazione
      // fissa. Con l'ombra sempre presente, a pagina appena aperta (nulla
      // ancora scrollato) sembrerebbe un difetto di rendering.
      boxShadow: overlapsContent
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    ),
    child: tabBar,
  );
  @override
  bool shouldRebuild(_MatchTabDelegate oldDelegate) => false;
}

/// Pillola colorata per gli STATI di questa schermata.
///
/// Stessa forma delle pillole di risposta/distanza di [MatchCard] (raggio a
/// pillola, colore pieno sul testo, sfondo tenue): è il modo in cui il dettaglio
/// parla la stessa lingua visiva della card in lista, invece dei Chip grigi di
/// Material che rendevano "aperta", "completa" e "annullata" tutte uguali a un
/// primo sguardo.
///
/// I tre costruttori nominati esistono per non moltiplicare pillole quasi
/// identiche: stato partita, campo prenotato e risposta di un giocatore sono la
/// stessa cosa (un valore che cambia nel tempo) e devono avere lo stesso peso
/// visivo — cambia solo la mappa valore -> colore. Averne tre classi separate
/// era il modo sicuro per farle divergere alla prima modifica.
///
/// Il colore non è decorazione: verde = confermato, oro = in sospeso, rosso =
/// fuori, grigio = ininfluente. È la stessa scala in tutte e tre le varianti.
class _StatusPill extends StatelessWidget {
  /// Variante col pallino: `icon` è fissata a null qui e non esposta come
  /// parametro, altrimenti resterebbe un'opzione che nessuno passa (l'unica
  /// pillola con icona ha il suo costruttore dedicato più sotto).
  const _StatusPill._({required this.color, required this.label}) : icon = null;

  /// Stato della partita, in testata.
  factory _StatusPill.matchStatus(String status) => _StatusPill._(
    color: switch (status) {
      'open' => AppTheme.primary,
      'full' => AppTheme.gold,
      'cancelled' => AppTheme.danger,
      _ => AppTheme.muted, // 'completed' e stati non previsti
    },
    label: _statusLabel(status),
  );

  /// Risposta di un giocatore nell'elenco.
  factory _StatusPill.response(String response) => _StatusPill._(
    color: switch (response) {
      'going' => AppTheme.primary,
      'waitlist' => AppTheme.gold,
      'not_going' => AppTheme.danger,
      _ => AppTheme.muted, // 'maybe' e risposte non previste
    },
    label: _responseLabel(response),
  );

  /// Campo prenotato: unico valore possibile, quindi costruttore const e
  /// nessun parametro. L'icona sostituisce il pallino perché qui il colore da
  /// solo direbbe "verde come lo stato aperto" e le due pillole, affiancate in
  /// testata, si confonderebbero.
  const _StatusPill.fieldBooked()
    : color = AppTheme.primary,
      label = 'Campo prenotato',
      icon = Icons.verified;

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          // Flexible + ellissi: la pillola si dimensiona sul contenuto, ma
          // `_statusLabel` e `_responseLabel` ricadono sul valore grezzo del
          // database per i casi non previsti, quindi l'etichetta è di fatto
          // una stringa arbitraria. Senza questo, un valore nuovo lato server
          // sfonderebbe la pillola.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.match,
    required this.responding,
    required this.onRespond,
    required this.onReload,
  });
  final MatchDetail match;
  final bool responding;
  final ValueChanged<String> onRespond;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final summary = match.summary;
    final perPlayer = match.costTotal == null || summary.maxPlayers == 0
        ? null
        : match.costTotal! / summary.maxPlayers;
    // registrationClosedAt e' impostato da set_match_admin_state('close', ...)
    // senza toccare `status`: senza questo controllo i bottoni RSVP
    // restavano visibili e cliccabili anche a iscrizioni chiuse, e
    // set_match_response rifiutava con un errore generico invece di
    // spiegare perche'.
    final isOpen =
        (summary.status == 'open' || summary.status == 'full') &&
        summary.registrationClosedAt == null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!summary.isLeagueMember && summary.visibility == 'public') ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partita pubblica',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Entra nella lega per confermare la presenza e scegliere la formazione.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _joinPublic(context),
                      child: const Text('Entra nella lega'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PostGameStats(match: match),
          const SizedBox(height: 18),
        ],
        if (match.postGame != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'RISULTATO FINALE',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${match.postGame!.teamAScore} – ${match.postGame!.teamBScore}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Team A   ·   Team B',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const Divider(height: 28),
                  if (match.postGame!.mvpFinalizedAt != null) ...[
                    // Token invece del giallo scritto a mano: `AppTheme.gold`
                    // è già pensato per questo caso ("oro... dei trofei"), qui
                    // era rimasto un esadecimale non allineato al design system.
                    const Icon(
                      Icons.emoji_events,
                      color: AppTheme.gold,
                      size: 30,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _mvpName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'MVP della partita',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ] else ...[
                    const Text(
                      'VOTA L’MVP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      alignment: WrapAlignment.center,
                      children: match.participants
                          .where((p) => p.response == 'going')
                          .map(
                            // ChoiceChip resta un Chip di Material di
                            // proposito: qui non è un'etichetta ma un comando a
                            // selezione singola, con la semantica di scelta che
                            // i lettori di schermo annunciano. Le pillole del
                            // design system sono decorative e non la danno.
                            (player) => ChoiceChip(
                              selected:
                                  match.postGame!.ownVotePlayerId ==
                                  player.userId,
                              onSelected: (_) => _vote(context, player.userId),
                              label: Text(
                                player.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (match.canManage) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _finalizeMvp(context),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Chiudi votazione MVP'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        // La conferma di presenza sta PRIMA degli strumenti admin, non dopo.
        // È la ragione per cui si apre questa schermata, e chi gestisce la lega
        // è quasi sempre anche un giocatore: con l'ordine di prima, un
        // admin-giocatore trovava per primo un blocco di comandi di gestione —
        // fra cui l'unico bottone verde pieno della pagina, "Chiudi partita" —
        // e solo scorrendo oltre la domanda a cui deve rispondere davvero. Il
        // verde più forte finiva così sull'azione che archivia la partita
        // invece che su quella che la fa giocare.
        if (isOpen && summary.isLeagueMember) ...[
          const SectionTitle(title: 'Ci sarai?', eyebrow: 'Conferma presenza'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ResponseButton(
                  label: 'Ci sono',
                  icon: Icons.check_circle_outline,
                  selected: summary.currentResponse == 'going',
                  onTap: responding ? null : () => onRespond('going'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResponseButton(
                  label: 'Forse',
                  icon: Icons.help_outline,
                  selected: summary.currentResponse == 'maybe',
                  onTap: responding ? null : () => onRespond('maybe'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResponseButton(
                  label: 'Non posso',
                  icon: Icons.cancel_outlined,
                  selected: summary.currentResponse == 'not_going',
                  onTap: responding ? null : () => onRespond('not_going'),
                ),
              ),
            ],
          ),
          if (responding)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 24),
        ] else if (summary.isLeagueMember &&
            summary.registrationClosedAt != null &&
            (summary.status == 'open' || summary.status == 'full')) ...[
          // Spiega perche' i bottoni di conferma presenza non ci sono,
          // invece di lasciare un vuoto silenzioso dove prima c'erano.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: AppTheme.muted),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Le iscrizioni a questa partita sono chiuse: non puoi più cambiare la tua presenza.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (match.canManage) ...[
          const SectionTitle(
            title: 'Gestione partita',
            eyebrow: 'Strumenti admin',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/matches/${summary.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica'),
              ),
              OutlinedButton.icon(
                onPressed: () => _reminder(context),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Promemoria'),
              ),
              OutlinedButton.icon(
                onPressed: () => _adminAction(
                  context,
                  summary.registrationClosedAt == null ? 'close' : 'reopen',
                ),
                icon: Icon(
                  summary.registrationClosedAt == null
                      ? Icons.lock_outline
                      : Icons.lock_open,
                ),
                label: Text(
                  summary.registrationClosedAt == null
                      ? 'Chiudi iscrizioni'
                      : 'Riapri',
                ),
              ),
              if (summary.status != 'completed')
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/matches/${summary.id}/manage-result'),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Chiudi partita'),
                ),
              if (summary.status == 'completed')
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/matches/${summary.id}/manage-result'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Correggi risultato'),
                ),
              if (summary.status != 'completed' &&
                  summary.status != 'cancelled')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _adminAction(context, 'cancel'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annulla partita'),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (match.venuePhone?.isNotEmpty == true) ...[
          _FieldBookingCard(
            match: match,
            canBook: match.canManage || summary.currentResponse == 'going',
            onBooked: onReload,
          ),
          const SizedBox(height: 14),
        ],
        if (match.venueImageUrl?.isNotEmpty == true) ...[
          ClipRRect(
            // radiusLg: questa foto non è dentro una card, è una sorella delle
            // card nella lista. Con il 20 di prima aveva angoli leggermente più
            // aperti della card di prenotazione che le sta appena sopra, e
            // nella colonna si notava come un allineamento sbagliato.
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: CachedNetworkImage(
              imageUrl: match.venueImageUrl!,
              width: double.infinity,
              height: 210,
              fit: BoxFit.cover,
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
                  'Informazioni',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (match.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    match.description!,
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ],
                const Divider(height: 30),
                _Info(
                  icon: Icons.place_outlined,
                  label: 'Indirizzo',
                  value:
                      match.address ??
                      '${summary.locationName}, ${summary.city}',
                ),
                if (match.costTotal != null) ...[
                  const Divider(height: 30),
                  _Info(
                    icon: Icons.payments_outlined,
                    label: 'Quota per giocatore',
                    value:
                        '${perPlayer == null ? '' : '€ ${perPlayer.toStringAsFixed(2)} a persona · '}totale € ${match.costTotal!.toStringAsFixed(2)}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _adminAction(BuildContext context, String action) async {
    try {
      await AppScope.of(context).repository
          .setMatchAdminState(match.summary.id, action);
      await onReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _joinPublic(BuildContext context) async {
    try {
      await AppScope.of(context).repository
          .joinPublicLeague(match.summary.leagueId);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  String _mvpName() {
    final winnerId = match.postGame!.playerStats
        .where((row) => row['is_mvp'] == true)
        .map((row) => row['user_id']?.toString())
        .firstOrNull;
    return match.participants
            .where((player) => player.userId == winnerId)
            .map((player) => player.displayName)
            .firstOrNull ??
        'MVP';
  }

  Future<void> _vote(BuildContext context, String playerId) async {
    try {
      await AppScope.of(context).repository
          .castMvpVote(match.summary.id, playerId);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _finalizeMvp(BuildContext context) async {
    try {
      await AppScope.of(context).repository.finalizeMvp(match.summary.id);
      await onReload();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _reminder(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Ricordati di confermare la presenza per ${match.summary.title}.',
    );
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invia promemoria'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Messaggio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().length < 3 || !context.mounted) return;
    try {
      final count = await AppScope.of(context).repository
          .sendMatchReminder(match.summary.id, body);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promemoria inviato a $count giocatori.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _PostGameStats extends StatelessWidget {
  const _PostGameStats({required this.match});
  final MatchDetail match;
  @override
  Widget build(BuildContext context) {
    final stats = match.postGame!.playerStats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prestazioni', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...stats.map((row) {
              final player = match.participants
                  .where((p) => p.userId == row['user_id']?.toString())
                  .firstOrNull;
              final delta = asDouble(row['rating_delta']);
              return ListTile(
                onTap: player == null
                    ? null
                    : () => context.push('/player/${player.username}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: PlayerAvatar(
                  name: player?.displayName ?? 'Giocatore',
                  url: player?.avatarUrl,
                  radius: 18,
                ),
                title: Text(
                  player?.displayName ?? 'Giocatore',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${asInt(row['goals'])} gol · ${asInt(row['assists'])} assist · voto ${row['match_rating'] ?? '—'}',
                ),
                trailing: Text(
                  delta == 0
                      ? '—'
                      : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                    // `AppTheme.danger` invece di `Colors.redAccent`: è lo
                    // stesso rosso usato per le sconfitte nel profilo privato,
                    // non un rosso Material scollegato dal resto del tema.
                    color: delta >= 0 ? AppTheme.primary : AppTheme.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: selected
          ? AppTheme.primary.withValues(alpha: .14)
          : AppTheme.surface,
      // radiusMd: nel design system è il raggio di pulsanti e campi, e questo
      // è un pulsante. Prima era un 15 scritto a mano, cioè un valore che non
      // combaciava con nessun altro angolo della schermata.
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: selected ? AppTheme.primary : AppTheme.outline),
    ),
    // L'InkWell sta DENTRO al contenitore, con un Material trasparente sopra
    // cui appoggiare l'onda. Prima stava fuori: l'onda del tocco veniva
    // disegnata nel Material della pagina, quindi sotto allo sfondo opaco del
    // pulsante, e spariva del tutto. Nessun riscontro visivo proprio sulle tre
    // uniche azioni che cambiano stato in questa schermata — con la rete
    // lenta, sembravano tap andati a vuoto.
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // Stesso raggio del contenitore: se differisce, l'onda esce dagli
        // angoli arrotondati.
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppTheme.primary : AppTheme.muted),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  // `AppTheme.muted` come l'icona qui sopra: prima la label
                  // usava `Colors.white70`, un grigio leggermente diverso da
                  // quello dell'icona nello stesso pulsante.
                  color: selected ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FieldBookingCard extends StatefulWidget {
  const _FieldBookingCard({
    required this.match,
    required this.canBook,
    required this.onBooked,
  });

  final MatchDetail match;
  final bool canBook;
  final Future<void> Function() onBooked;

  @override
  State<_FieldBookingCard> createState() => _FieldBookingCardState();
}

class _FieldBookingCardState extends State<_FieldBookingCard> {
  bool _loading = false;

  /// Istante della prenotazione, tenuto localmente.
  ///
  /// La card si aggiorna dal valore restituito dalla RPC invece di aspettare
  /// che l'intera pagina si ricarichi: il ricaricamento resta (serve per il
  /// badge "Campo prenotato" nell'intestazione) ma non è più l'unica cosa che
  /// fa cambiare stato a questa card.
  DateTime? _bookedAt;

  @override
  void initState() {
    super.initState();
    _bookedAt = widget.match.fieldBookedAt;
  }

  @override
  void didUpdateWidget(_FieldBookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se il ricaricamento porta un dato più fresco, vince quello del server.
    final incoming = widget.match.fieldBookedAt;
    if (incoming != null && incoming != _bookedAt) _bookedAt = incoming;
  }

  @override
  Widget build(BuildContext context) {
    final bookedAt = _bookedAt;
    final booked = bookedAt != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: booked
            ? AppTheme.primary.withValues(alpha: .1)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: booked
              ? AppTheme.primary.withValues(alpha: .5)
              : AppTheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                child: Icon(booked ? Icons.verified : Icons.stadium_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booked ? 'Campo prenotato' : 'Prenota il campo',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(booked),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.canBook) ...[
            const SizedBox(height: 15),
            // Wrap invece di Row: con il testo ingrandito due pulsanti
            // affiancati non ci stavano e andavano in overflow.
            LayoutBuilder(
              builder: (context, constraints) {
                final call = OutlinedButton.icon(
                  onPressed: _call,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Chiama campo'),
                );
                if (booked) {
                  return SizedBox(width: double.infinity, child: call);
                }
                final confirm = FilledButton.icon(
                  onPressed: _loading ? null : _confirm,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all),
                  label: const Text('Conferma'),
                );
                // Sotto i 320 px i due pulsanti si impilano.
                if (constraints.maxWidth < 320) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: call),
                      const SizedBox(height: 9),
                      SizedBox(width: double.infinity, child: confirm),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: call),
                    const SizedBox(width: 9),
                    Expanded(child: confirm),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Testo di stato della prenotazione.
  ///
  /// A campo prenotato dice chi l'ha fatto e quando: prima si limitava a
  /// "Prenotazione confermata a tutti i partecipanti", quindi nessuno sapeva a
  /// chi chiedere conferma. I dati (`field_booked_by`, `field_booked_at`) erano
  /// già caricati ma non venivano mostrati.
  String _subtitle(bool booked) {
    if (!booked) {
      return widget.canBook
          ? 'Chiama la struttura e poi conferma la prenotazione.'
          : 'Disponibile dopo aver confermato la presenza.';
    }
    final when = DateFormat('d MMM · HH:mm', 'it_IT').format(_bookedAt!);
    // Subito dopo la conferma il ricaricamento potrebbe non essere ancora
    // arrivato: in quel caso chi ha prenotato è per forza l'utente corrente.
    final bookerId = widget.match.fieldBookedBy ?? widget.match.currentUserId;
    final booker = widget.match.participants
        .where((player) => player.userId == bookerId)
        .firstOrNull;
    return booker == null
        ? 'Confermato il $when. Tutti i partecipanti sono stati avvisati.'
        : 'Confermato da ${booker.displayName} il $when.';
  }

  Future<void> _call() async {
    final phone = widget.match.venuePhone!;
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il telefono.')),
      );
    }
  }

  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Campo prenotato?'),
        content: const Text(
          'Conferma solo dopo aver parlato con la struttura. Tutti i partecipanti riceveranno una notifica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sì, conferma'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final bookedAt = await AppScope.of(context).repository
          .confirmFieldBooking(widget.match.summary.id);
      if (!mounted) return;
      // La card passa subito allo stato "prenotato" con il timestamp del
      // server, senza dipendere dal ricaricamento della pagina.
      setState(() {
        _bookedAt = bookedAt ?? DateTime.now();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campo prenotato: partecipanti avvisati.'),
        ),
      );
    } catch (error) {
      debugPrint('Prenotazione campo non riuscita: $error');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
      return;
    }

    // Ricarica il resto della schermata (badge "Campo prenotato"
    // nell'intestazione) fuori dal try: se il ricaricamento fallisce la
    // prenotazione è comunque andata a buon fine, e mostrare un errore qui
    // farebbe credere il contrario.
    try {
      await widget.onBooked();
    } catch (error) {
      debugPrint('Ricaricamento partita dopo la prenotazione fallito: $error');
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppTheme.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.participants});
  final List<MatchParticipant> participants;
  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]
      ..sort((a, b) {
        const order = {'going': 0, 'waitlist': 1, 'maybe': 2, 'not_going': 3};
        return (order[a.response] ?? 9).compareTo(order[b.response] ?? 9);
      });
    if (sorted.isEmpty) {
      return const PageFrame(
        child: EmptyState(
          icon: Icons.group_outlined,
          title: 'Nessuna risposta',
          body: 'I giocatori appariranno qui dopo la prima conferma.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final player = sorted[index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/player/${player.username}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: PlayerAvatar(
              name: player.displayName,
              url: player.avatarUrl,
            ),
            // Nome e username li scrivono gli utenti: senza tetto alle righe
            // un nome lungo mandava a capo il titolo e faceva crescere la
            // riga, rompendo il passo regolare che rende scorrevole l'elenco.
            title: Text(
              player.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '@${player.username} · ${player.overall} OVR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // La risposta è uno stato, non un attributo, quindi pillola
            // colorata e non InfoPill: con il Chip grigio di prima "Ci sarà" e
            // "Non viene" erano identici a colpo d'occhio e l'elenco — che
            // esiste proprio per contare chi c'è — andava letto riga per riga.
            // Ora il verde si accende solo sui confermati, che l'ordinamento
            // raggruppa già in cima: chi c'è si vede senza leggere.
            trailing: _StatusPill.response(player.response),
          ),
        );
      },
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'open' => 'Iscrizioni aperte',
  'full' => 'Completa',
  'completed' => 'Conclusa',
  'cancelled' => 'Annullata',
  _ => status,
};
String _responseLabel(String response) => switch (response) {
  'going' => 'Ci sarà',
  'waitlist' => 'Attesa',
  'maybe' => 'Forse',
  'not_going' => 'Non viene',
  _ => response,
};
