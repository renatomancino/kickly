import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  Future<(List<MatchSummary>, UserProfile?)>? _future;
  String _filter = 'nearby';
  double _radiusKm = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
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

  Future<(List<MatchSummary>, UserProfile?)> _load() async {
    final repository = AppScope.of(context).repository;
    final values = await Future.wait<dynamic>([
      repository.getMatches(),
      repository.getCurrentProfile(),
    ]);
    return (values[0] as List<MatchSummary>, values[1] as UserProfile?);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partite',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Trova un campo, unisciti e gioca.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => context.push('/matches/new'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              const filters = {
                'nearby': ('Vicino a me', Icons.near_me_outlined),
                'going': ('Partecipo', Icons.check_circle_outline),
                'league': ('Partite lega', Icons.shield_outlined),
                'past': ('Passate', Icons.history),
              };
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filters.entries.map((entry) {
                  final selected = _filter == entry.key;
                  return SizedBox(
                    width: width,
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(entry.value.$2, size: 17),
                      // Niente SizedBox(width: double.infinity) attorno
                      // all'etichetta: serviva a centrare il testo, ma
                      // chiedeva al contenuto del chip la larghezza massima
                      // possibile, e sommata all'icona faceva sfondare il chip
                      // dal riquadro da mezza riga in cui è incastonato. Il
                      // chip ora si dimensiona sul testo, che si accorcia da
                      // solo quando lo spazio non basta.
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        entry.value.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_filter == 'nearby') ...[
            const SizedBox(height: 12),
            // Wrap e non una Row con lo Spacer: l'etichetta più i tre valori
            // non entrano in una riga sola su uno schermo da 320pt (né su uno
            // da 430 con il testo di sistema ingrandito), e con la Row il
            // risultato erano le barre gialle e nere di overflow. Così i
            // valori scendono sotto l'etichetta quando serve, e restano in
            // linea quando c'è spazio.
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Raggio',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                ...[25.0, 50.0, 100.0].map(
                  (radius) => FilterChip(
                    selected: _radiusKm == radius,
                    showCheckmark: false,
                    label: Text('${radius.toInt()} km'),
                    onSelected: (_) => setState(() => _radiusKm = radius),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FutureBuilder<(List<MatchSummary>, UserProfile?)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // Column e non ListSkeleton: qui siamo già dentro una
                // ListView, annidare uno scroll romperebbe il gesto.
                return const Column(
                  children: [
                    CardSkeleton(),
                    SizedBox(height: 12),
                    CardSkeleton(),
                  ],
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Partite non disponibili',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _refresh,
                    child: const Text('Riprova'),
                  ),
                );
              }
              final data = snapshot.data;
              final allMatches = data?.$1 ?? const <MatchSummary>[];
              final profile = data?.$2;
              if (_filter == 'nearby' &&
                  (profile?.latitude == null || profile?.longitude == null)) {
                return EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Imposta la tua zona',
                  body: 'Seleziona comune e provincia nel profilo per vedere le partite vicine.',
                  action: FilledButton(
                    onPressed: () => context.push('/profile/edit'),
                    child: const Text('Completa località'),
                  ),
                );
              }
              final matches = allMatches.where((match) {
                return switch (_filter) {
                  'nearby' =>
                    !match.isPast &&
                        match.visibility == 'public' &&
                        match.distanceKm != null &&
                        match.distanceKm! <= _radiusKm,
                  'going' => !match.isPast && match.currentResponse == 'going',
                  'league' => !match.isPast && match.isLeagueMember,
                  'past' => match.isPast && match.currentResponse == 'going',
                  _ => false,
                };
              }).toList();
              if (matches.isEmpty) {
                // Ogni tab vuoto propone un'azione diversa e pertinente
                // invece del generico "Non ci sono partite in questa
                // sezione": un elenco vuoto senza via d'uscita si legge come
                // un vicolo cieco, mentre qui c'è sempre un passo successivo
                // sensato (allargare la ricerca, esplorare, organizzare).
                // Fa eccezione solo "Passate", dove non c'è nulla da fare.
                return _EmptyMatches(
                  filter: _filter,
                  radiusKm: _radiusKm,
                  onWidenRadius: () => setState(() => _radiusKm = 100),
                  onExploreNearby: () => setState(() => _filter = 'nearby'),
                );
              }
              if (_filter == 'past') {
                matches.sort((a, b) => b.startsAt.compareTo(a.startsAt));
              } else if (_filter == 'nearby') {
                matches.sort(
                  (a, b) => (a.distanceKm ?? double.infinity).compareTo(
                    b.distanceKm ?? double.infinity,
                  ),
                );
              }
              // Raggruppare per fascia temporale (Oggi/Domani/...) rende la
              // lista scorribile a colpo d'occhio invece di un muro di card
              // identiche per struttura: ma ha senso solo quando l'ordine
              // della lista è cronologico. "Vicino a me" è ordinato per
              // distanza (v. sort sopra), quindi lì le date sarebbero sparse
              // e i titoli di gruppo si ripeterebbero a ogni card: si salta.
              return Column(
                children: _filter == 'nearby'
                    ? matches
                          .map(
                            (match) => Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _MatchListEntry(
                                match: match,
                                onTap: () =>
                                    context.push('/matches/${match.id}'),
                              ),
                            ),
                          )
                          .toList()
                    : _groupedMatchEntries(
                        matches,
                        pastTab: _filter == 'past',
                        onTap: (match) => context.push('/matches/${match.id}'),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Costruisce la lista di card intervallate dalle intestazioni di gruppo
/// temporale ("Oggi", "Domani", "Questa settimana", ...).
///
/// [matches] deve già essere ordinata cronologicamente (crescente per le tab
/// future, decrescente per "Passate"): la funzione si limita a inserire un
/// titolo ogni volta che l'etichetta del gruppo cambia rispetto alla card
/// precedente, senza riordinare nulla.
List<Widget> _groupedMatchEntries(
  List<MatchSummary> matches, {
  required bool pastTab,
  required ValueChanged<MatchSummary> onTap,
}) {
  final now = DateTime.now();
  final children = <Widget>[];
  String? lastBucket;
  for (final match in matches) {
    final bucket = pastTab
        ? _pastBucket(match.startsAt, now)
        : _upcomingBucket(match.startsAt, now);
    if (bucket != lastBucket) {
      if (lastBucket != null) children.add(const SizedBox(height: 4));
      children.add(_DateGroupHeader(label: bucket));
      lastBucket = bucket;
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: _MatchListEntry(match: match, onTap: () => onTap(match)),
      ),
    );
  }
  return children;
}

/// Etichetta di gruppo per una partita futura, relativa a oggi.
String _upcomingBucket(DateTime startsAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
  final diff = day.difference(today).inDays;
  if (diff <= 0) return 'Oggi';
  if (diff == 1) return 'Domani';
  if (diff <= 7) return 'Questa settimana';
  if (day.month == today.month && day.year == today.year) return 'Questo mese';
  return _monthLabel(startsAt);
}

/// Come [_upcomingBucket] ma per la tab "Passate", che scorre a ritroso nel
/// tempo (la partita più recente prima).
String _pastBucket(DateTime startsAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 7) return 'Ultimi 7 giorni';
  if (day.month == today.month && day.year == today.year) return 'Questo mese';
  return _monthLabel(startsAt);
}

/// "marzo 2026" -> "Marzo 2026": `DateFormat` in locale it_IT restituisce il
/// mese minuscolo, ma qui serve come titolo di sezione.
String _monthLabel(DateTime date) {
  final raw = DateFormat('MMMM y', 'it_IT').format(date);
  return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}

/// Titolo di sezione leggero per i raggruppamenti temporali della lista.
///
/// Non è un [SectionTitle]: quel componente è pensato per l'intestazione di
/// un'intera pagina (grande, con eyebrow) e qui invece si ripete più volte
/// nella stessa schermata, quindi deve restare defilato e non competere con
/// le card sotto.
class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 9, left: 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    ),
  );
}

/// Avvolge [MatchCard] con un accento colorato sul bordo sinistro quando la
/// risposta dell'utente è "Ci sono" (verde primario) o "Forse" (oro).
///
/// Non tocca `MatchCard` in `core/widgets/common.dart`, condivisa anche con
/// dashboard e pagina lega: qui si aggiunge solo un livello sopra. La pillola
/// di risposta che la card mostra già in alto a destra va letta per intero,
/// l'accento invece si percepisce anche solo scorrendo la lista con la coda
/// dell'occhio — è la risposta diretta a "come rendere confermata/in dubbio
/// riconoscibili a colpo d'occhio" senza duplicare informazioni testuali.
/// Per "non ci sono" o nessuna risposta non si aggiunge nulla: la card resta
/// neutra e la pillola esistente basta.
class _MatchListEntry extends StatelessWidget {
  const _MatchListEntry({required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  Color? get _accentColor => switch (match.currentResponse) {
    'going' => AppTheme.primary,
    'maybe' => AppTheme.gold,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColor;
    final card = MatchCard(match: match, onTap: onTap);
    if (accentColor == null) return card;
    return Stack(
      children: [
        card,
        // Larghezza 4px, altezza piena: lo Stack si dimensiona sulla card
        // (unico figlio non posizionato), quindi la barra segue l'altezza
        // reale qualunque sia il contenuto (titolo su una o due righe,
        // copertina presente o no) senza calcoli manuali.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 4,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppTheme.radiusLg),
            ),
            child: ColoredBox(color: accentColor),
          ),
        ),
      ],
    );
  }
}

/// Stato vuoto della lista partite, con un'azione diversa per ogni tab.
///
/// Prima ogni tab senza risultati mostrava lo stesso messaggio generico
/// ("Non ci sono partite in questa sezione") senza alcuna via d'uscita: per
/// un'app che vive di partite organizzate dagli utenti, un vuoto senza invito
/// all'azione è un'occasione persa, non solo un dettaglio estetico.
class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches({
    required this.filter,
    required this.radiusKm,
    required this.onWidenRadius,
    required this.onExploreNearby,
  });

  final String filter;
  final double radiusKm;
  final VoidCallback onWidenRadius;
  final VoidCallback onExploreNearby;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      'nearby' =>
        radiusKm >= 100
            ? EmptyState(
                icon: Icons.event_busy,
                title: 'Nessuna partita nel raggio',
                body: 'Non ci sono partite pubbliche entro 100 km. Prova a tornare più tardi oppure organizzane una tu.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/matches/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Crea una partita'),
                ),
              )
            : EmptyState(
                icon: Icons.event_busy,
                title: 'Nessuna partita nel raggio',
                body:
                    'Nessuna partita pubblica entro ${radiusKm.toInt()} km. Prova ad allargare la ricerca.',
                action: FilledButton.icon(
                  onPressed: onWidenRadius,
                  icon: const Icon(Icons.radar),
                  label: const Text('Allarga il raggio a 100 km'),
                ),
              ),
      'going' => EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nessuna presenza confermata',
        body: 'Non hai ancora detto "Ci sono" a nessuna partita in programma.',
        action: FilledButton.icon(
          onPressed: onExploreNearby,
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('Trova partite vicine'),
        ),
      ),
      'league' => EmptyState(
        icon: Icons.shield_outlined,
        title: 'Nessuna partita in lega',
        body: 'Le tue leghe non hanno ancora partite in programma.',
        action: FilledButton.icon(
          onPressed: () => context.push('/matches/new'),
          icon: const Icon(Icons.add),
          label: const Text('Organizza una partita'),
        ),
      ),
      _ => const EmptyState(
        icon: Icons.event_busy,
        title: 'Nessuna partita passata',
        body: 'Le partite che hai giocato compariranno qui a fine gara.',
      ),
    };
  }
}
