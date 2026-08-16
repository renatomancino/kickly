import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Chiusura della partita: squadre, punteggio, gol e assist dei singoli.
///
/// È la schermata più delicata dell'app: quello che un admin scrive qui finisce
/// nelle statistiche di tutti i partecipanti, e spesso viene compilata in piedi
/// al campo subito dopo il fischio finale. Per questo la gerarchia è: prima il
/// punteggio (il dato che l'admin ha in testa in quel momento), poi le squadre,
/// poi la tabella gol/assist.
///
/// L'accento verde del marchio in questa vista si accende su una cosa sola: il
/// pulsante che chiude la partita, cioè l'unica azione che cambia stato e
/// pubblica il risultato a tutti. Tutto il resto — occhielli, frecce di
/// spostamento, contatori — resta neutro, così l'unico altro colore che può
/// comparire (il rosso di `AppTheme.danger`) significa davvero "qui c'è un
/// problema".
class MatchResultPage extends StatefulWidget {
  const MatchResultPage({super.key, required this.matchId});
  final String matchId;
  @override
  State<MatchResultPage> createState() => _MatchResultPageState();
}

class _MatchResultPageState extends State<MatchResultPage> {
  Future<MatchDetail?>? _future;
  final Set<String> _teamA = {};
  final Map<String, Map<String, int>> _totals = {};
  int _scoreA = 0;
  int _scoreB = 0;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getMatch(widget.matchId);
  }

  void _initialize(MatchDetail match) {
    if (_initialized) return;
    final confirmed = match.participants
        .where((p) => p.response == 'going')
        .toList();
    final savedA =
        match.postGame?.teams
            .where((team) => asInt(team['team_number']) == 1)
            .expand(
              (team) => (team['player_ids'] as List<dynamic>? ?? const []).map(
                (id) => id.toString(),
              ),
            )
            .toList() ??
        const <String>[];
    _teamA.addAll(
      savedA.isEmpty
          ? confirmed.indexed
                .where((entry) => entry.$1.isEven)
                .map((entry) => entry.$2.userId)
          : savedA,
    );
    for (final player in confirmed) {
      final stats = match.postGame?.playerStats
          .where((row) => row['user_id']?.toString() == player.userId)
          .firstOrNull;
      _totals[player.userId] = {
        'goals': asInt(stats?['goals']),
        'assists': asInt(stats?['assists']),
      };
    }
    _scoreA = match.postGame?.teamAScore ?? 0;
    _scoreB = match.postGame?.teamBScore ?? 0;
    _initialized = true;
  }

  /// Somma dei gol già assegnati ai singoli giocatori di una squadra.
  ///
  /// È esattamente il numero che il server confronta con il punteggio della
  /// squadra prima di accettare la chiusura (`team_a_goals_mismatch` /
  /// `team_b_goals_mismatch`). Non è logica nuova: il vincolo esiste già, qui
  /// lo rendiamo solo visibile mentre si compila, invece di lasciarlo scoprire
  /// con un errore dopo aver premuto "Chiudi partita".
  int _assignedGoals(Iterable<MatchParticipant> team) => team.fold<int>(
    0,
    (sum, player) => sum + (_totals[player.userId]?['goals'] ?? 0),
  );

  Future<void> _submit(MatchDetail match) async {
    final confirmed = match.participants
        .where((p) => p.response == 'going')
        .toList();
    final teamB = confirmed
        .where((p) => !_teamA.contains(p.userId))
        .map((p) => p.userId)
        .toList();
    if (_teamA.isEmpty || teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assegna almeno un giocatore a ogni squadra.'),
        ),
      );
      return;
    }
    // Riscontro tattile alla conferma: chiudere la partita pubblica il
    // risultato finale a tutti i partecipanti, un momento che merita un
    // piccolo feedback fisico come la pubblicazione di una nuova partita.
    // `unawaited`: è un effetto collaterale sul motore aptico, attenderlo
    // ritarderebbe la chiusura della partita senza alcun beneficio.
    unawaited(HapticFeedback.lightImpact());
    setState(() => _saving = true);
    try {
      await AppScope.of(context).repository.finalizeMatch(
        widget.matchId,
        teamA: _teamA.toList(),
        teamB: teamB,
        scoreA: _scoreA,
        scoreB: _scoreB,
        playerTotals: confirmed
            .map(
              (p) => <String, dynamic>{
                'user_id': p.userId,
                ..._totals[p.userId]!,
              },
            )
            .toList(),
      );
      if (mounted) context.go('/matches/${widget.matchId}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post partita')),
    body: FutureBuilder<MatchDetail?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        // Ramo errore separato da "partita non trovata": un fallimento di
        // rete non è la stessa cosa di una partita cancellata/inesistente,
        // e qui merita un "riprova" invece di un vicolo cieco.
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Risultato non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: () => setState(
                  () =>
                      _future = AppScope.of(context).repository
                          .getMatch(widget.matchId),
                ),
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final match = snapshot.data;
        if (match == null) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Partita non trovata',
              // Con un'azione invece che con il solo messaggio: senza uscita,
              // l'unica strada da qui è il tasto indietro di sistema.
              body: 'Potrebbe essere stata annullata o non essere più accessibile.',
              action: FilledButton.icon(
                onPressed: () => context.go('/matches'),
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Vai alle partite'),
              ),
            ),
          );
        }
        _initialize(match);
        return _form(match);
      },
    ),
  );

  Widget _form(MatchDetail match) {
    final players = match.participants
        .where((p) => p.response == 'going')
        .toList();

    // Senza presenze confermate non c'è niente da compilare e il salvataggio
    // fallirebbe comunque (`teams_required`): meglio dirlo subito con un'uscita
    // verso la partita che mostrare un modulo vuoto e un pulsante che rifiuta.
    if (players.isEmpty) {
      return PageFrame(
        child: EmptyState(
          icon: Icons.group_off_outlined,
          title: 'Nessuna presenza confermata',
          body:
              'Serve almeno un giocatore per squadra per chiudere la partita. '
              'Controlla le presenze nella scheda Dettagli.',
          action: FilledButton.icon(
            onPressed: () => context.go('/matches/${widget.matchId}'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torna alla partita'),
          ),
        ),
      );
    }

    final teamA = players.where((p) => _teamA.contains(p.userId)).toList();
    final teamB = players.where((p) => !_teamA.contains(p.userId)).toList();
    final goalsA = _assignedGoals(teamA);
    final goalsB = _assignedGoals(teamB);

    // Due elenchi affiancati funzionano solo se a ogni nome resta spazio per
    // essere letto: su un telefono restavano una manciata di pixel e ogni nome
    // finiva troncato, proprio nel momento in cui devi verificare chi sta dove.
    final sideBySide = MediaQuery.sizeOf(context).width >= 520;

    final rosters = [
      _TeamRosterCard(
        team: 'Team A',
        otherTeam: 'Team B',
        players: teamA,
        onMove: _move,
      ),
      _TeamRosterCard(
        team: 'Team B',
        otherTeam: 'Team A',
        players: teamB,
        onMove: _move,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _Eyebrow('Post partita'),
        const SizedBox(height: 6),
        Text(
          match.postGame == null ? 'Chiudi la partita' : 'Modifica risultato',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Quello che salvi qui entra nelle statistiche di tutti i giocatori.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 22),

        // Il punteggio apre la pagina: è il dato che l'admin ha in testa appena
        // finita la partita, ed è quello che tutti leggeranno dopo. Prima stava
        // sotto le squadre, con numeri della stessa taglia dei pulsanti che gli
        // stavano ai lati.
        _ScoreBoard(
          scoreA: _scoreA,
          scoreB: _scoreB,
          goalsA: goalsA,
          goalsB: goalsB,
          onScoreA: (value) => setState(() => _scoreA = value),
          onScoreB: (value) => setState(() => _scoreB = value),
        ),
        const SizedBox(height: 20),

        const SectionTitle(title: 'Squadre', eyebrow: 'Chi ha giocato con chi'),
        const SizedBox(height: 12),
        if (sideBySide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rosters[0]),
              const SizedBox(width: 12),
              Expanded(child: rosters[1]),
            ],
          )
        else ...[
          rosters[0],
          const SizedBox(height: 12),
          rosters[1],
        ],
        const SizedBox(height: 20),

        const SectionTitle(
          title: 'Gol e assist',
          eyebrow: 'Statistiche giocatori',
        ),
        const SizedBox(height: 12),
        // Una tabella per squadra invece di una card per giocatore: le
        // intestazioni "Gol" e "Assist" si scrivono una volta sola, i nomi
        // restano incolonnati e il totale della squadra sta in cima, accanto
        // ai giocatori che lo compongono. Raggruppare per squadra non è
        // decorativo: è l'unico modo per capire a colpo d'occhio *quale* dei
        // due totali non torna.
        if (teamA.isNotEmpty)
          _StatsTeamCard(
            team: 'Team A',
            players: teamA,
            assigned: goalsA,
            expected: _scoreA,
            totals: _totals,
            onChanged: _setTotal,
          ),
        if (teamA.isNotEmpty && teamB.isNotEmpty) const SizedBox(height: 12),
        if (teamB.isNotEmpty)
          _StatsTeamCard(
            team: 'Team B',
            players: teamB,
            assigned: goalsB,
            expected: _scoreB,
            totals: _totals,
            onChanged: _setTotal,
          ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _submit(match),
            // Stesso pattern di match_form_page.dart: l'icona diventa
            // uno spinner compatto durante il salvataggio, invece di
            // restare ferma mentre il bottone appare bloccato.
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.emoji_events),
            label: Text(
              match.postGame == null ? 'Chiudi partita' : 'Salva correzione',
            ),
          ),
        ),
      ],
    );
  }

  /// Sposta un giocatore da una squadra all'altra.
  ///
  /// L'appartenenza è tenuta con il solo insieme `_teamA`: chi non c'è dentro è
  /// del Team B. Toccare un nome in una delle due liste è quindi la stessa
  /// operazione, invertita.
  void _move(MatchParticipant player) => setState(() {
    if (!_teamA.remove(player.userId)) _teamA.add(player.userId);
  });

  void _setTotal(String userId, String key, int value) =>
      setState(() => _totals[userId]?[key] = value);
}

/// Occhiello di sezione: maiuscolo, piccolo, spaziato.
///
/// Ripete a mano lo stile dell'eyebrow di `SectionTitle` perché qui serve anche
/// dentro card e colonne, dove il titolo grande non ci sta. Quello che conta è
/// che i numeri (11 / w800 / 1.5 / `AppTheme.muted`) restino gli stessi del
/// resto dell'app.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    style: const TextStyle(
      color: AppTheme.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

/// Pulsante tondo neutro usato dai contatori.
///
/// Volutamente senza verde: in questa pagina i "+" e i "–" si toccano decine di
/// volte di fila e sono lo sfondo del lavoro, non il traguardo. L'unico verde
/// resta sul pulsante che chiude la partita.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: size * .45),
    style: IconButton.styleFrom(
      backgroundColor: AppTheme.surfaceHigh,
      foregroundColor: AppTheme.foreground,
      // Il "–" disabilitato a quota zero deve restare leggibile come pulsante
      // spento, non sparire: senza questo colore esplicito Material lo porta a
      // un grigio quasi invisibile sulla superficie rialzata.
      disabledForegroundColor: AppTheme.mutedSoft,
      side: const BorderSide(color: AppTheme.outline),
      padding: EdgeInsets.zero,
      minimumSize: Size(size, size),
      fixedSize: Size(size, size),
      // Senza questo, `fixedSize` non è autorevole: IconButton riserva
      // comunque il bersaglio da toccare predefinito di Material (48x48), e
      // due pulsanti finivano per occupare 96pt in una colonna larga 92 —
      // esattamente l'overflow di 4px che il test di rendering ha scoperto.
      // Il bersaglio resta comunque comodo perché `size` qui è 40.
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// Riquadro del punteggio finale, in cima alla pagina.
class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({
    required this.scoreA,
    required this.scoreB,
    required this.goalsA,
    required this.goalsB,
    required this.onScoreA,
    required this.onScoreB,
  });

  final int scoreA;
  final int scoreB;
  final int goalsA;
  final int goalsB;
  final ValueChanged<int> onScoreA;
  final ValueChanged<int> onScoreB;

  @override
  Widget build(BuildContext context) {
    final mismatchA = goalsA != scoreA;
    final mismatchB = goalsB != scoreB;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Column(
          children: [
            const _Eyebrow('Risultato finale', align: TextAlign.center),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TeamScore(
                    team: 'Team A',
                    value: scoreA,
                    assigned: goalsA,
                    onChanged: onScoreA,
                  ),
                ),
                // Il trattino è allineato all'altezza delle cifre, non al
                // centro della colonna: sotto i numeri c'è tutto il blocco dei
                // pulsanti e del totale, e centrandolo sarebbe finito sotto il
                // punteggio invece che fra i due.
                const Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: Text(
                    '–',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.mutedSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamScore(
                    team: 'Team B',
                    value: scoreB,
                    assigned: goalsB,
                    onChanged: onScoreB,
                  ),
                ),
              ],
            ),
            if (mismatchA || mismatchB) ...[
              const Divider(height: 26),
              _MismatchNotice(
                scoreA: scoreA,
                scoreB: scoreB,
                goalsA: goalsA,
                goalsB: goalsB,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Punteggio di una squadra: cifra grande, contatore sotto, totale dei gol
/// assegnati ai singoli in fondo.
class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.team,
    required this.value,
    required this.assigned,
    required this.onChanged,
  });

  final String team;
  final int value;
  final int assigned;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Eyebrow(team, align: TextAlign.center),
        const SizedBox(height: 2),
        // FittedBox e non una dimensione fissa: con il testo di sistema al
        // massimo una cifra da 54 punti uscirebbe dalla colonna.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 54,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              icon: Icons.remove,
              tooltip: 'Un gol in meno per il $team',
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            const SizedBox(width: 10),
            _RoundButton(
              icon: Icons.add,
              tooltip: 'Un gol in più per il $team',
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GoalsTally(assigned: assigned, expected: value),
      ],
    );
  }
}

/// Pillola "gol assegnati / punteggio".
///
/// È la traduzione visiva del vincolo del server: finché i due numeri non
/// coincidono la chiusura viene rifiutata. Rossa solo quando c'è davvero
/// discrepanza, così il colore conserva il suo significato.
class _GoalsTally extends StatelessWidget {
  const _GoalsTally({required this.assigned, required this.expected});

  final int assigned;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final ok = assigned == expected;
    final color = ok ? AppTheme.muted : AppTheme.danger;
    return Semantics(
      // Da sola la pillola leggerebbe "2/3", che a voce non vuol dire niente.
      label: '$assigned gol assegnati ai giocatori su $expected',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ok
              ? AppTheme.surfaceHigh
              : AppTheme.danger.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ok
                ? AppTheme.outline
                : AppTheme.danger.withValues(alpha: .5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.sports_soccer : Icons.priority_high,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              '$assigned/$expected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spiegazione della discrepanza fra gol dei singoli e punteggio.
///
/// Il pulsante di chiusura resta comunque attivo: la verifica vera è del
/// server, e bloccare il salvataggio su un conto fatto qui rischierebbe di
/// impedire un salvataggio legittimo se le due somme divergessero. Qui diciamo
/// solo, in anticipo, quello che il server direbbe dopo.
class _MismatchNotice extends StatelessWidget {
  const _MismatchNotice({
    required this.scoreA,
    required this.scoreB,
    required this.goalsA,
    required this.goalsB,
  });

  final int scoreA;
  final int scoreB;
  final int goalsA;
  final int goalsB;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (goalsA != scoreA) 'Team A $goalsA di $scoreA',
      if (goalsB != scoreB) 'Team B $goalsB di $scoreB',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 17, color: AppTheme.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'I gol dei singoli non tornano con il punteggio (${parts.join(' · ')}). '
            'Sistemali qui sotto, altrimenti la chiusura verrà rifiutata.',
            style: const TextStyle(
              color: AppTheme.danger,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Elenco dei giocatori di una squadra, con lo spostamento all'altra.
class _TeamRosterCard extends StatelessWidget {
  const _TeamRosterCard({
    required this.team,
    required this.otherTeam,
    required this.players,
    required this.onMove,
  });

  final String team;
  final String otherTeam;
  final List<MatchParticipant> players;
  final ValueChanged<MatchParticipant> onMove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow(team),
            const SizedBox(height: 2),
            Text(
              players.length == 1
                  ? '1 giocatore'
                  : '${players.length} giocatori',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              // Una squadra vuota non è uno stato accettabile — il server
              // rifiuta la chiusura — quindi lo diciamo qui invece di lasciare
              // un riquadro vuoto che sembra un errore di caricamento.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Nessuno: sposta qui qualcuno dal $otherTeam.',
                  style: const TextStyle(
                    color: AppTheme.mutedSoft,
                    fontSize: 12.5,
                  ),
                ),
              )
            else
              for (final player in players)
                Semantics(
                  button: true,
                  label: 'Sposta ${player.displayName} nel $otherTeam',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onMove(player),
                    // Raggio del token e non un numero a caso: è un InkWell
                    // dentro una Card, e con un valore diverso l'onda del
                    // tocco esce dagli angoli.
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          PlayerAvatar(
                            name: player.displayName,
                            url: player.avatarUrl,
                            radius: 15,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              player.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // La freccia sta in un cerchietto pieno: senza uno
                          // sfondo l'icona sola si leggeva come decorazione e
                          // non come "questa riga si tocca".
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceHigh,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              size: 15,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            // La destinazione scritta per esteso: la doppia freccia dice che
            // qualcosa si sposta, non dove. Con squadre impilate una sopra
            // l'altra su telefono, "l'altra squadra" non è deducibile dalla
            // posizione.
            Text(
              'Tocca un nome per spostarlo nel $otherTeam.',
              style: const TextStyle(color: AppTheme.mutedSoft, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabella gol/assist di una squadra.
class _StatsTeamCard extends StatelessWidget {
  const _StatsTeamCard({
    required this.team,
    required this.players,
    required this.assigned,
    required this.expected,
    required this.totals,
    required this.onChanged,
  });

  final String team;
  final List<MatchParticipant> players;
  final int assigned;
  final int expected;
  final Map<String, Map<String, int>> totals;
  final void Function(String userId, String key, int value) onChanged;

  /// Larghezza di una colonna di contatori: due pulsanti da 40 più la cifra.
  ///
  /// 40 e non meno: è la soglia sotto la quale un bersaglio da toccare diventa
  /// scomodo, e questa schermata si compila in piedi al campo, spesso di fretta.
  static const double _column = 104;

  /// Sotto questa larghezza le due colonne di contatori più il nome non ci
  /// stanno su una riga sola senza rimpicciolire i pulsanti: si passa al
  /// layout impilato. La soglia è il nome (minimo leggibile ~70) più le due
  /// colonne più lo spazio fra loro.
  static const double _tableMinWidth = 70 + _column * 2 + 8;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Eyebrow(team)),
                // Il totale della squadra sta accanto ai giocatori che lo
                // compongono, non solo in cima alla pagina: è qui che si
                // aggiusta, e vederlo salire mentre si assegnano i gol
                // trasforma un vincolo nascosto in un conto alla rovescia.
                _GoalsTally(assigned: assigned, expected: expected),
              ],
            ),
            const SizedBox(height: 10),
            // Due impaginazioni a seconda dello spazio reale, non della
            // dimensione dello schermo: su telefoni larghi la tabella con le
            // intestazioni scritte una volta sola si scorre con gli occhi, ma
            // sotto ~282pt (iPhone SE e Android piccoli, o testo di sistema
            // ingrandito) nome e due colonne di contatori non ci stanno più su
            // una riga. Prima il risultato era un overflow di 4px: la scelta
            // qui è impilare invece di rimpicciolire i pulsanti, perché sono
            // bersagli da toccare e vengono premuti di fretta a bordo campo.
            LayoutBuilder(
              builder: (context, constraints) {
                final table = constraints.maxWidth >= _tableMinWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (table)
                      const Row(
                        children: [
                          Spacer(),
                          SizedBox(width: _column, child: _ColumnLabel('Gol')),
                          SizedBox(width: 8),
                          SizedBox(
                            width: _column,
                            child: _ColumnLabel('Assist'),
                          ),
                        ],
                      ),
                    for (final player in players) ...[
                      const Divider(height: 9),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: table
                            ? _playerRow(player)
                            : _playerStacked(player),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Riga a tabella: nome a sinistra, le due colonne di contatori allineate
  /// sotto le rispettive intestazioni.
  Widget _playerRow(MatchParticipant player) => Row(
    children: [
      Expanded(
        child: Text(
          player.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      SizedBox(width: _column, child: _goals(player)),
      const SizedBox(width: 8),
      SizedBox(width: _column, child: _assists(player)),
    ],
  );

  /// Variante per schermi stretti: il nome prende tutta la riga e i due
  /// contatori stanno sotto, ciascuno con la propria etichetta — senza le
  /// intestazioni di colonna in cima non si saprebbe più quale è quale.
  Widget _playerStacked(MatchParticipant player) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        player.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      const SizedBox(height: 6),
      // Anche i due contatori uno sotto l'altro, non affiancati: a 320pt
      // affiancarli li rimetterebbe in overflow (due colonne da 104 più le
      // etichette superano lo spazio utile). Impilati, ciascuno tiene i suoi
      // pulsanti da 40 e l'etichetta resta accanto al numero che descrive.
      _StackedCounter(label: 'Gol', child: _goals(player)),
      const SizedBox(height: 4),
      _StackedCounter(label: 'Assist', child: _assists(player)),
    ],
  );

  Widget _goals(MatchParticipant player) => _Stepper(
    value: totals[player.userId]?['goals'] ?? 0,
    semantics: 'Gol di ${player.displayName}',
    onChanged: (value) => onChanged(player.userId, 'goals', value),
  );

  Widget _assists(MatchParticipant player) => _Stepper(
    value: totals[player.userId]?['assists'] ?? 0,
    semantics: 'Assist di ${player.displayName}',
    onChanged: (value) => onChanged(player.userId, 'assists', value),
  );
}

/// Riga "etichetta + contatore" usata solo nel layout impilato, dove non ci
/// sono le intestazioni di colonna in cima a dire quale contatore è quale.
class _StackedCounter extends StatelessWidget {
  const _StackedCounter({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.mutedSoft,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      SizedBox(width: _StatsTeamCard._column, child: child),
    ],
  );
}

/// Intestazione di colonna della tabella gol/assist.
class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: AppTheme.mutedSoft,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

/// Contatore compatto della tabella: – valore +.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.semantics,
    required this.onChanged,
  });

  final int value;
  final String semantics;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _RoundButton(
        icon: Icons.remove,
        tooltip: '$semantics: uno in meno',
        size: 40,
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
      ),
      // Expanded e non una larghezza fissa: la cifra si stringe da sola e la
      // riga non può andare in overflow nemmeno con il testo ingrandito.
      Expanded(
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            // Gli zeri arretrano, i valori inseriti restano pieni: così, in
            // una lista di dieci giocatori, si vede subito chi ha segnato.
            color: value == 0 ? AppTheme.mutedSoft : AppTheme.foreground,
          ),
        ),
      ),
      _RoundButton(
        icon: Icons.add,
        tooltip: '$semantics: uno in più',
        size: 40,
        onPressed: () => onChanged(value + 1),
      ),
    ],
  );
}
