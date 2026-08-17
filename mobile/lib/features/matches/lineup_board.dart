import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'lineup_config.dart';

/// Campo interattivo per la scelta della formazione pre-partita.
///
/// Equivalente mobile di `src/features/matches/match-lineup-board.tsx`.
/// Rispetto alla versione precedente cambia su quattro punti che rendevano la
/// funzione inutilizzabile nella pratica:
///
/// 1. c'è la candidatura a capitano, senza la quale nessuno tranne gli admin di
///    lega poteva cambiare modulo (la RPC richiede capitano oppure owner/admin);
/// 2. gli slot sono disabilitati con una spiegazione se non hai confermato la
///    presenza, invece di far partire una RPC che fallisce con errore generico;
/// 3. le due tabelle sono in ascolto Realtime, così due giocatori che scelgono
///    insieme si vedono a vicenda invece di scoprire il conflitto con un errore;
/// 4. lo stato si aggiorna dallo snapshot restituito dalla RPC, non con una
///    `getMatch()` da sei query dopo ogni singolo tocco.
class LineupBoard extends StatefulWidget {
  const LineupBoard({super.key, required this.match});

  final MatchDetail match;

  @override
  State<LineupBoard> createState() => _LineupBoardState();
}

class _LineupBoardState extends State<LineupBoard> {
  /// Stato corrente della formazione, inizializzato dal dettaglio partita già
  /// caricato e poi aggiornato da RPC e Realtime.
  late LineupSnapshot _lineup = LineupSnapshot(
    teams: widget.match.lineupTeams,
    players: widget.match.lineupPlayers,
  );

  /// Chiave dell'azione in corso ('1:p3', 'captain', 'release', 'formation:2'):
  /// serve a mostrare lo spinner sul solo elemento toccato invece che su tutto.
  String? _pending;

  /// Candidatura a capitano espressa prima di aver scelto una posizione: viene
  /// applicata al primo slot occupato, come fa la PWA.
  bool _wantsCaptain = false;

  /// Squadra mostrata quando lo schermo è troppo stretto per due campi affiancati.
  late int _activeTeam = _myAssignment()?['team_number'] == null
      ? 1
      : asInt(_myAssignment()!['team_number'], 1);

  RealtimeChannel? _channel;

  /// Debounce degli eventi Realtime: una singola RPC tocca entrambe le tabelle e
  /// genera più eventi ravvicinati, che altrimenti diventerebbero più riletture.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Il primo frame non ha ancora il context per AppScope, quindi la
    // sottoscrizione parte subito dopo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  // --------------------------------------------------------------- Realtime

  void _subscribe() {
    if (!mounted) return;
    final repository = AppScope.of(context).repository;
    final client = repository.client;
    // Modalità demo: nessun backend a cui agganciarsi.
    if (client == null) {
      return;
    }

    final matchId = widget.match.summary.id;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'match_id',
      value: matchId,
    );

    _channel = client
        .channel('kickly-lineup-$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'match_lineup_players',
          filter: filter,
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'match_lineup_teams',
          filter: filter,
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      final next = await AppScope.of(context).repository
          .getLineup(widget.match.summary.id);
      if (next != null && mounted) setState(() => _lineup = next);
    });
  }

  // ----------------------------------------------------------------- Azioni

  /// Esegue un'azione sulla formazione applicando lo snapshot restituito.
  ///
  /// Tutte le regole (partita bloccata, slot occupato, fascia già assegnata)
  /// vivono nelle RPC: qui ci limitiamo a tradurre l'errore in italiano.
  Future<void> _run(
    String key,
    Future<LineupSnapshot?> Function() action, {
    String? success,
  }) async {
    if (_pending != null) return;
    setState(() => _pending = key);
    try {
      final snapshot = await action();
      if (!mounted) return;
      setState(() {
        if (snapshot != null) _lineup = snapshot;
        _wantsCaptain = false;
      });
      if (success != null) _toast(success);
    } catch (error) {
      if (mounted) _toast(friendlyError(error));
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _claim(int team, String slot) {
    final repository = AppScope.of(context).repository;
    setState(() => _activeTeam = team);
    _run(
      '$team:$slot',
      () => repository.setLineupSlot(
        widget.match.summary.id,
        team,
        slot,
        // Chi è già capitano mantiene la fascia spostandosi di posizione.
        captain: _isCaptain(_myUserId) || _wantsCaptain,
      ),
      success: _myAssignment() == null
          ? 'Sei in formazione.'
          : 'Posizione aggiornata.',
    );
  }

  void _release() {
    final repository = AppScope.of(context).repository;
    _run(
      'release',
      () => repository.leaveLineup(widget.match.summary.id),
      success: 'Posizione liberata.',
    );
  }

  /// Attiva o disattiva la fascia da capitano.
  ///
  /// Se il giocatore non è ancora schierato la candidatura resta in sospeso e
  /// viene applicata al primo slot che sceglie: la RPC assegna la fascia solo
  /// insieme a una posizione.
  void _toggleCaptain() {
    final mine = _myAssignment();
    if (mine == null) {
      setState(() => _wantsCaptain = !_wantsCaptain);
      return;
    }
    final repository = AppScope.of(context).repository;
    final becoming = !_isCaptain(_myUserId);
    _run(
      'captain',
      () => repository.setLineupSlot(
        widget.match.summary.id,
        asInt(mine['team_number'], 1),
        mine['slot_key']?.toString() ?? 'gk',
        captain: becoming,
      ),
      success: becoming ? 'Ora sei il capitano.' : 'Non sei più capitano.',
    );
  }

  void _changeFormation(int team, String formation) {
    final repository = AppScope.of(context).repository;
    _run(
      'formation:$team',
      () => repository.setLineupFormation(
        widget.match.summary.id,
        team,
        formation,
      ),
      success: 'Modulo Team ${team == 1 ? 'A' : 'B'} aggiornato.',
    );
  }

  // ------------------------------------------------------------- Selettori

  String get _myUserId => widget.match.currentUserId;

  /// Riga di `match_lineup_players` del giocatore corrente, se schierato.
  JsonMap? _myAssignment() => _lineup.players
      .where((row) => row['user_id']?.toString() == _myUserId)
      .firstOrNull;

  bool _isCaptain(String userId) => _lineup.teams.any(
    (team) => team['captain_user_id']?.toString() == userId,
  );

  JsonMap? _teamRow(int team) => _lineup.teams
      .where((row) => asInt(row['team_number']) == team)
      .firstOrNull;

  String _formationOf(int team) => normalizeFormation(
    widget.match.summary.footballFormat,
    _teamRow(team)?['formation']?.toString(),
  );

  MatchParticipant? _participant(String? userId) => userId == null
      ? null
      : widget.match.participants
            .where((player) => player.userId == userId)
            .firstOrNull;

  /// Il giocatore può scegliere una posizione solo se ha confermato la presenza
  /// e la partita non è chiusa: sono le stesse condizioni che la RPC
  /// `set_match_lineup_slot` verifica prima di scrivere.
  bool get _canChoose {
    final status = widget.match.summary.status;
    return widget.match.summary.currentResponse == 'going' &&
        status != 'cancelled' &&
        status != 'completed';
  }

  /// Spiegazione del perché il campo è in sola lettura, mostrata al posto di un
  /// errore generico dopo un tocco a vuoto.
  String get _lockedReason {
    final status = widget.match.summary.status;
    if (status == 'completed') {
      return 'La partita è conclusa: la formazione è ora solo consultabile.';
    }
    if (status == 'cancelled') {
      return 'La partita è annullata, la formazione è bloccata.';
    }
    if (!widget.match.summary.isLeagueMember) {
      return 'Entra nella lega per scegliere una posizione in campo.';
    }
    return 'Conferma "Ci sono" nella scheda Dettagli per scegliere la tua posizione.';
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final mine = _myAssignment();
    // Due campi affiancati richiedono spazio: sotto questa soglia mostriamo una
    // squadra per volta con un selettore, come fa la PWA sotto il breakpoint xl.
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (_canChoose)
          const Text(
            'Tocca una posizione libera. Puoi spostarti finché la partita non viene chiusa.',
            // Token e non un bianco al 55%: il grigio dei testi secondari è lo
            // stesso in tutta l'app, e a occhio nudo un bianco trasparente su
            // una card cambia tinta a seconda di cosa ha sotto.
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          )
        else
          _LockedNotice(message: _lockedReason),
        const SizedBox(height: 16),
        if (_canChoose) ...[
          _CaptainBar(
            isCaptain: _isCaptain(_myUserId),
            wantsCaptain: _wantsCaptain,
            hasSlot: mine != null,
            pending: _pending,
            onToggleCaptain: _toggleCaptain,
            onRelease: _release,
          ),
          const SizedBox(height: 16),
        ],
        if (!wide) ...[
          _TeamSwitcher(
            active: _activeTeam,
            counts: [_playersOf(1).length, _playersOf(2).length],
            side: lineupSideSize(widget.match.summary.footballFormat),
            onChanged: (team) => setState(() => _activeTeam = team),
          ),
          const SizedBox(height: 14),
          _teamCard(_activeTeam),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _teamCard(1)),
              const SizedBox(width: 14),
              Expanded(child: _teamCard(2)),
            ],
          ),
        const SizedBox(height: 18),
        const _PitchLegend(),
      ],
    );
  }

  List<JsonMap> _playersOf(int team) => _lineup.players
      .where((row) => asInt(row['team_number']) == team)
      .toList();

  Widget _teamCard(int teamNumber) {
    final players = _playersOf(teamNumber);
    final side = lineupSideSize(widget.match.summary.footballFormat);
    final captainId = _teamRow(teamNumber)?['captain_user_id']?.toString();
    final formation = _formationOf(teamNumber);
    final accent = teamNumber == 1 ? AppTheme.primary : _teamBColor;

    // Media overall dei soli giocatori effettivamente schierati, come il badge
    // OVR della PWA.
    final schierati = players
        .map((row) => _participant(row['user_id']?.toString()))
        .whereType<MatchParticipant>()
        .toList();
    final average = schierati.isEmpty
        ? null
        : (schierati.fold<int>(0, (sum, p) => sum + p.overall) /
                  schierati.length)
              .round();

    // Il modulo lo cambiano capitano della squadra e admin di lega: stessa
    // regola applicata da `set_match_lineup_formation`.
    final canChangeFormation =
        (widget.match.canManage || captainId == _myUserId) &&
        widget.match.summary.status != 'completed' &&
        widget.match.summary.status != 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    teamNumber == 1 ? 'A' : 'B',
                    style: const TextStyle(
                      color: AppTheme.background,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team ${teamNumber == 1 ? 'A' : 'B'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${players.length}/$side in campo',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // InfoPill invece della pillola costruita a mano: è la stessa
                // informazione neutra delle altre schermate (un attributo, non
                // uno stato) e ora ne condivide superficie, bordo e raggio.
                if (average != null) InfoPill(label: 'OVR $average'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'MODULO',
                  // Occhiello di sezione come nel resto dell'app: maiuscolo,
                  // 11/w800/1.5 in muted. Prima era un'etichetta a sé, con una
                  // taglia e un grigio che non comparivano da nessun'altra
                  // parte.
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_pending == 'formation:$teamNumber')
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (canChangeFormation)
                  _FormationPicker(
                    value: formation,
                    options: formationsFor(widget.match.summary.footballFormat),
                    onSelected: (value) => _changeFormation(teamNumber, value),
                  )
                else
                  // Il Chip di Material era l'ultimo rimasto qui dentro: fuori
                  // dal linguaggio delle pillole del design system, con un
                  // raggio e un grigio suoi. Sola lettura, quindi InfoPill.
                  InfoPill(label: formation),
              ],
            ),
            const SizedBox(height: 12),
            _Pitch(
              slots: buildLineupSlots(
                widget.match.summary.footballFormat,
                formation,
              ),
              teamNumber: teamNumber,
              accent: accent,
              formation: formation,
              rows: players,
              captainId: captainId,
              currentUserId: _myUserId,
              canChoose: _canChoose,
              pending: _pending,
              participantOf: _participant,
              onClaim: (slot) => _claim(teamNumber, slot),
              onOccupiedTap: _showOccupant,
            ),
          ],
        ),
      ),
    );
  }

  /// Uno slot occupato non è più un tocco che non fa niente: mostra chi lo ha
  /// preso e, se sei tu, permette di liberarlo.
  void _showOccupant(MatchParticipant player, String role) {
    final isMine = player.userId == _myUserId;
    final isCaptain = _isCaptain(player.userId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerAvatar(
                name: player.displayName,
                url: player.avatarUrl,
                radius: 30,
              ),
              const SizedBox(height: 12),
              Text(
                player.displayName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              // Le stesse pillole del resto dell'app al posto della riga di
              // testo con i puntini: un Wrap perché con la fascia da capitano
              // sono tre, e con il testo di sistema ingrandito devono andare a
              // capo invece di sfondare il foglio.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  InfoPill(label: role, icon: Icons.place_outlined),
                  InfoPill(label: '${player.overall} OVR', icon: Icons.bolt),
                  if (isCaptain) const _CaptainPill(),
                ],
              ),
              const SizedBox(height: 20),
              if (isMine)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _release();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Libera la posizione'),
                  ),
                )
              else
                const Text(
                  'Questa posizione è occupata. Scegline una libera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Azzurro del Team B, per distinguerlo dal verde Kickly del Team A.
/// Corrisponde a `sky-400` usato dalla PWA.
const Color _teamBColor = Color(0xFF38BDF8);

/// Pillola della fascia da capitano, gemella di `InfoPill` ma in oro.
///
/// Non usa `InfoPill` perché quella è deliberatamente neutra: descrive un
/// attributo. Il capitano invece è un ruolo, l'unico che può cambiare modulo, e
/// sul campo è già segnato dalla "C" dorata: qui riusa lo stesso oro così che
/// la scheda del giocatore e il token sul campo si riconoscano come la stessa
/// cosa.
class _CaptainPill extends StatelessWidget {
  const _CaptainPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.gold.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.gold.withValues(alpha: .45)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.military_tech, size: 13, color: AppTheme.gold),
        SizedBox(width: 5),
        Text(
          'Capitano',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.gold,
          ),
        ),
      ],
    ),
  );
}

/// Avviso mostrato quando il campo è in sola lettura, con il motivo esplicito.
class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: AppTheme.outline),
    ),
    child: Row(
      children: [
        // Lucchetto grigio e non verde: qui non c'è niente da fare e niente da
        // celebrare, è uno stato passivo. Il verde del marchio in questa
        // schermata appartiene al campo — ai giocatori del Team A e alla
        // propria posizione — e un'icona accesa in cima glielo rubava.
        const Icon(Icons.lock_outline, size: 18, color: AppTheme.muted),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

/// Barra con candidatura a capitano e uscita dalla formazione.
class _CaptainBar extends StatelessWidget {
  const _CaptainBar({
    required this.isCaptain,
    required this.wantsCaptain,
    required this.hasSlot,
    required this.pending,
    required this.onToggleCaptain,
    required this.onRelease,
  });

  final bool isCaptain;
  final bool wantsCaptain;
  final bool hasSlot;
  final String? pending;
  final VoidCallback onToggleCaptain;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final active = isCaptain || wantsCaptain;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        // Il capitano è l'unico ruolo non-admin che può cambiare modulo: senza
        // questo pulsante la tendina del modulo resta inattiva per quasi tutti.
        active
            ? FilledButton.icon(
                onPressed: pending == null ? onToggleCaptain : null,
                icon: pending == 'captain'
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.military_tech, size: 18),
                label: Text(
                  isCaptain ? 'Sei capitano' : 'Capitano al prossimo slot',
                ),
              )
            : OutlinedButton.icon(
                onPressed: pending == null ? onToggleCaptain : null,
                icon: const Icon(Icons.military_tech_outlined, size: 18),
                label: const Text('Candidati capitano'),
              ),
        if (hasSlot)
          TextButton.icon(
            onPressed: pending == null ? onRelease : null,
            icon: pending == 'release'
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_outlined, size: 18),
            label: const Text('Libera posizione'),
          ),
      ],
    );
  }
}

/// Selettore Team A / Team B per gli schermi troppo stretti da mostrare due
/// campi affiancati.
class _TeamSwitcher extends StatelessWidget {
  const _TeamSwitcher({
    required this.active,
    required this.counts,
    required this.side,
    required this.onChanged,
  });

  final int active;
  final List<int> counts;
  final int side;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          for (var team = 1; team <= 2; team++)
            Expanded(
              // Semantics esplicito: a un lettore di schermo questo è un
              // selettore a due stati, non due testi affiancati, e senza
              // `selected` non c'è modo di sapere quale squadra si sta
              // guardando.
              child: Semantics(
                button: true,
                selected: active == team,
                child: GestureDetector(
                  onTap: () => onChanged(team),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active == team
                          ? (team == 1 ? AppTheme.primary : _teamBColor)
                          : Colors.transparent,
                      // Raggio interno del token: il contenitore è a radiusLg
                      // con 4 di padding, quindi il tassello selezionato deve
                      // stare un gradino sotto o gli angoli non seguono la
                      // curva esterna.
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'Team ${team == 1 ? 'A' : 'B'}  ${counts[team - 1]}/$side',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: active == team
                            ? AppTheme.background
                            : AppTheme.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tendina dei moduli disponibili per il formato della partita.
class _FormationPicker extends StatelessWidget {
  const _FormationPicker({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    initialValue: value,
    onSelected: onSelected,
    itemBuilder: (_) => options
        .map((option) => PopupMenuItem(value: option, child: Text(option)))
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    ),
  );
}

/// Legenda dei colori e del ruolo del capitano.
class _PitchLegend extends StatelessWidget {
  const _PitchLegend();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      _LegendItem(color: AppTheme.primary, label: 'Team A'),
      _LegendItem(color: _teamBColor, label: 'Team B'),
      // Token e non l'esadecimale scritto a mano: è lo stesso oro della "C"
      // sul campo e dei trofei, e tenerlo in due posti come costante separata
      // era il modo più rapido per farli divergere.
      _LegendItem(
        color: AppTheme.gold,
        icon: Icons.military_tech,
        label: 'Il capitano sceglie il modulo',
      ),
    ],
  );
}

/// Voce della legenda: pallino (o icona) più didascalia.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.icon});

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null)
        Icon(icon, size: 13, color: color)
      else
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      const SizedBox(width: 6),
      // Flexible e non il solo Text: dentro una Wrap la riga riceve tutta la
      // larghezza disponibile come massimo, e una didascalia lunga come quella
      // del capitano sfondava di 65px su uno schermo da 320. Così invece la
      // voce si stringe e va a capo con le altre.
      Flexible(
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.mutedSoft, fontSize: 11),
        ),
      ),
    ],
  );
}

/// Rettangolo di gioco con gli slot posizionati sopra.
class _Pitch extends StatelessWidget {
  const _Pitch({
    required this.slots,
    required this.teamNumber,
    required this.accent,
    required this.formation,
    required this.rows,
    required this.captainId,
    required this.currentUserId,
    required this.canChoose,
    required this.pending,
    required this.participantOf,
    required this.onClaim,
    required this.onOccupiedTap,
  });

  final List<LineupSlot> slots;
  final int teamNumber;
  final Color accent;
  final String formation;
  final List<JsonMap> rows;
  final String? captainId;
  final String currentUserId;
  final bool canChoose;
  final String? pending;
  final MatchParticipant? Function(String?) participantOf;
  final ValueChanged<String> onClaim;
  final void Function(MatchParticipant player, String role) onOccupiedTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .70,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // La larghezza del token deriva dalla linea più affollata del modulo:
          // con 5 giocatori in linea gli slot stanno a 1/6, 2/6... della
          // larghezza, quindi lo spazio disponibile è width/6. Prima era una
          // costante in pixel e su schermi stretti i token si sovrapponevano.
          final widest = slots
              .where((slot) => slot.key != 'gk')
              .fold<Map<double, int>>({}, (counts, slot) {
                counts[slot.y] = (counts[slot.y] ?? 0) + 1;
                return counts;
              })
              .values
              .fold<int>(
                1,
                (largest, count) => count > largest ? count : largest,
              );
          final spacing = width / (widest + 1);
          final tokenWidth = spacing.clamp(34.0, 76.0) - 2;
          final avatar = (tokenWidth * .62).clamp(26.0, 44.0);
          // Cerchio + etichetta nome + ruolo.
          final tokenHeight = avatar + 30;

          return ClipRRect(
            // Raggio del token invece di un 20 a occhio: il campo sta dentro
            // una Card arrotondata a radiusLg e con un valore più largo del
            // contenitore i due archi non erano concentrici.
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      // I due verdi dell'erba non sono token e non devono
                      // diventarlo: non sono colori dell'interfaccia ma la
                      // superficie di gioco, l'unica illustrazione dell'app.
                      // Il verde del marchio qui sopra ci va per i giocatori,
                      // non per il prato.
                      gradient: LinearGradient(
                        colors: [Color(0xFF216536), Color(0xFF174A2A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(painter: const _PitchPainter()),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .34),
                      borderRadius: BorderRadius.circular(999),
                      // Non AppTheme.outline: qui l'etichetta sta sopra il
                      // verde del campo, non su una superficie della card, e
                      // le regole di contrasto sono quelle di un overlay, non
                      // quelle del design system delle card.
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .24),
                      ),
                    ),
                    child: Text(
                      'TEAM ${teamNumber == 1 ? 'A' : 'B'} · $formation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                for (final slot in slots)
                  _positioned(
                    slot: slot,
                    width: width,
                    height: height,
                    tokenWidth: tokenWidth,
                    tokenHeight: tokenHeight,
                    avatar: avatar,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positioned({
    required LineupSlot slot,
    required double width,
    required double height,
    required double tokenWidth,
    required double tokenHeight,
    required double avatar,
  }) {
    final row = rows
        .where((item) => item['slot_key']?.toString() == slot.key)
        .firstOrNull;
    final player = participantOf(row?['user_id']?.toString());
    final mine = player != null && player.userId == currentUserId;

    // I token vengono centrati sulla posizione ma tenuti dentro il rettangolo:
    // portiere e attaccanti stanno vicino ai bordi e prima venivano tagliati.
    final left = (width * slot.x - tokenWidth / 2).clamp(
      0.0,
      (width - tokenWidth).clamp(0.0, double.infinity),
    );
    final top = (height * slot.y - tokenHeight / 2).clamp(
      0.0,
      (height - tokenHeight).clamp(0.0, double.infinity),
    );

    return Positioned(
      left: left,
      top: top,
      width: tokenWidth,
      height: tokenHeight,
      child: _SlotToken(
        slot: slot,
        player: player,
        mine: mine,
        accent: accent,
        avatarSize: avatar,
        captain: player != null && player.userId == captainId,
        busy: pending == '$teamNumber:${slot.key}',
        // Uno slot libero si può prendere solo se hai confermato la presenza;
        // uno occupato apre la scheda del giocatore.
        onTap: player == null
            ? (canChoose && pending == null ? () => onClaim(slot.key) : null)
            : () => onOccupiedTap(player, slot.role),
      ),
    );
  }
}

/// Singola casella sul campo: cerchio con avatar o sigla del ruolo, nome sotto.
///
/// I bianchi e i neri trasparenti che si vedono qui sotto non sono una fuga dai
/// token: questo widget vive sopra l'erba, non su una superficie del design
/// system, quindi il contrasto va calcolato sul verde del campo. È la stessa
/// ragione per cui l'etichetta del modulo, in alto a sinistra sul campo, ha un
/// bordo bianco al 24% invece di `AppTheme.outline`.
class _SlotToken extends StatelessWidget {
  const _SlotToken({
    required this.slot,
    required this.player,
    required this.mine,
    required this.accent,
    required this.avatarSize,
    required this.captain,
    required this.busy,
    required this.onTap,
  });

  final LineupSlot slot;
  final MatchParticipant? player;
  final bool mine;
  final Color accent;
  final double avatarSize;
  final bool captain;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final free = player == null;
    // Uno slot libero che non si può prendere (partita chiusa, presenza non
    // confermata, azione in corso) prima era identico a uno prendibile: il
    // campo continuava a invitare al tocco mentre l'avviso in cima diceva il
    // contrario. Qui le caselle libere si spengono, e il blocco si vede sul
    // campo e non solo nel riquadro sopra.
    final selectable = free && onTap != null;
    final freeBorder = Colors.white.withValues(alpha: selectable ? .55 : .2);

    return Semantics(
      button: onTap != null,
      label: free
          ? 'Posizione ${slot.role} libera${selectable ? '' : ', non disponibile'}'
          : '${player!.displayName}, ${slot.role}${captain ? ', capitano' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: mine
                        ? accent
                        : free
                        ? Colors.black.withValues(alpha: selectable ? .28 : .16)
                        : AppTheme.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      // Lo slot libero ha bordo tenue, quello occupato pieno,
                      // il proprio è nel colore della squadra.
                      color: mine ? accent : (free ? freeBorder : accent),
                      width: mine ? 2.5 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      // Alone nel colore della squadra sotto al proprio token.
                      // Su un campo con dieci caselle uguali il solo riempimento
                      // pieno non bastava a farsi trovare a colpo d'occhio:
                      // l'alone lo stacca dallo sfondo anche in mezzo agli altri.
                      if (mine)
                        BoxShadow(
                          color: accent.withValues(alpha: .45),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: busy
                      ? SizedBox.square(
                          dimension: avatarSize * .4,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : free
                      ? Text(
                          slot.shortRole,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: selectable ? .85 : .4,
                            ),
                            fontSize: avatarSize * .34,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : _avatar(),
                ),
                if (captain)
                  const Positioned(right: -3, top: -3, child: _CaptainBadge()),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: mine
                    ? accent
                    : Colors.black.withValues(
                        alpha: free && !selectable ? .4 : .68,
                      ),
                // Pillola come l'etichetta del modulo in alto a sinistra:
                // erano due sovrimpressioni sullo stesso campo con due raggi
                // diversi, uno dei quali non apparteneva alla scala del tema.
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                free ? 'Libero' : _shortName(player!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mine
                      ? AppTheme.background
                      : Colors.white.withValues(
                          alpha: free && !selectable ? .55 : 1,
                        ),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final url = player!.avatarUrl;
    if (url == null || url.isEmpty) {
      return Text(
        _initials(player!),
        style: TextStyle(
          color: Colors.white,
          fontSize: avatarSize * .32,
          fontWeight: FontWeight.w900,
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Text(
          _initials(player!),
          style: TextStyle(
            color: Colors.white,
            fontSize: avatarSize * .32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  /// Sul campo c'è spazio per una parola sola: nome se disponibile, altrimenti
  /// username.
  static String _shortName(MatchParticipant player) =>
      player.firstName?.trim().isNotEmpty == true
      ? player.firstName!.trim()
      : player.username;

  static String _initials(MatchParticipant player) {
    final first = player.firstName?.trim();
    final last = player.lastName?.trim();
    if (first?.isNotEmpty == true) {
      return '${first![0]}${last?.isNotEmpty == true ? last![0] : ''}'
          .toUpperCase();
    }
    return player.username.isEmpty ? 'K' : player.username[0].toUpperCase();
  }
}

/// Fascia da capitano appuntata sul token: la "C" dorata.
///
/// Estratta dal token perché l'oro deve arrivare dal token del tema e non da un
/// esadecimale ripetuto: qui e nella legenda era scritto due volte a mano, ed è
/// così che due gialli quasi uguali finiscono nella stessa schermata.
class _CaptainBadge extends StatelessWidget {
  const _CaptainBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 17,
    height: 17,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppTheme.gold,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'C',
      style: TextStyle(
        // Il nero dello sfondo dell'app e non `Colors.black`: sull'oro la
        // differenza non si vede, ma è un colore in meno fuori dal sistema.
        color: AppTheme.background,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

/// Linee del campo: fasce d'erba, cerchio di centrocampo, aree e porte.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..color = Colors.white.withValues(alpha: .035);
    for (var index = 0; index < 8; index += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * index / 8, size.width, size.height / 8),
        stripe,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final inset = size.width * .045;
    final field = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(4)),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height / 2),
      Offset(size.width - inset, size.height / 2),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * .13,
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.white.withValues(alpha: .65),
    );

    final penaltyWidth = size.width * .55;
    final penaltyHeight = size.height * .13;
    final smallWidth = size.width * .28;
    final smallHeight = size.height * .055;
    for (final top in [true, false]) {
      canvas.drawRect(
        Rect.fromLTWH(
          (size.width - penaltyWidth) / 2,
          top ? inset : size.height - inset - penaltyHeight,
          penaltyWidth,
          penaltyHeight,
        ),
        line,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (size.width - smallWidth) / 2,
          top ? inset : size.height - inset - smallHeight,
          smallWidth,
          smallHeight,
        ),
        line,
      );
    }

    final goalWidth = size.width * .18;
    canvas.drawRect(
      Rect.fromLTWH((size.width - goalWidth) / 2, 1, goalWidth, inset - 1),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - goalWidth) / 2,
        size.height - inset,
        goalWidth,
        inset - 1,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}
