/// Configurazione della formazione: moduli ammessi, geometria degli slot sul
/// campo e nomi dei ruoli.
///
/// È il gemello Dart di `src/features/matches/lineup-config.ts` della PWA e
/// deve restare allineato con le funzioni SQL `private.is_valid_lineup_formation`
/// e `private.is_valid_lineup_slot`: se le tre fonti divergono, il giocatore
/// vede uno slot che poi il database rifiuta.
library;

/// Moduli selezionabili per ogni formato di partita.
///
/// Stessa lista di `formationOptions` nella PWA e del CASE dentro
/// `private.is_valid_lineup_formation`. Il primo di ogni riga è il default
/// applicato dal trigger `initialize_match_lineups`.
const Map<String, List<String>> lineupFormations = {
  '5v5': ['1-2-1', '2-1-1', '1-1-2'],
  '7v7': ['2-3-1', '3-2-1', '2-2-2'],
  '8v8': ['3-3-1', '2-3-2', '3-2-2'],
  '10v10': ['3-4-2', '4-3-2', '4-4-1'],
  '11v11': ['4-3-3', '4-4-2', '3-5-2'],
};

/// Moduli validi per un formato, con fallback al 5v5 per formati sconosciuti.
List<String> formationsFor(String format) =>
    lineupFormations[format] ?? lineupFormations['5v5']!;

/// Numero di giocatori per squadra, portiere incluso: '7v7' -> 7.
///
/// Rispecchia `private.lineup_side_size`.
int lineupSideSize(String format) =>
    int.tryParse(format.split('v').first) ?? 5;

/// Modulo di default di un formato, cioè quello che il database assegna alla
/// creazione della partita.
String defaultFormationFor(String format) => formationsFor(format).first;

/// Riporta un modulo arbitrario a uno valido per il formato.
///
/// Serve perché il modulo arriva dal database come testo libero: se la partita
/// ha cambiato formato o il dato è vecchio, disegnare il campo con un modulo
/// incoerente produrrebbe slot che la RPC rifiuta.
String normalizeFormation(String format, String? formation) {
  final options = formationsFor(format);
  if (formation != null && options.contains(formation)) return formation;
  return options.first;
}

/// Una posizione sul campo: la chiave dello slot che va nel database, il ruolo
/// mostrato al giocatore e le coordinate relative (0..1) sul rettangolo.
class LineupSlot {
  const LineupSlot({
    required this.key,
    required this.role,
    required this.shortRole,
    required this.x,
    required this.y,
  });

  /// Chiave persistita in `match_lineup_players.slot_key`: 'gk' oppure 'p1'..'p10'.
  final String key;

  /// Ruolo esteso in italiano, es. 'Terzino SX'. Solo presentazione.
  final String role;

  /// Sigla mostrata dentro lo slot vuoto, es. 'D', 'C', 'A', 'P'.
  final String shortRole;

  /// Posizione orizzontale relativa: 0 = fascia sinistra, 1 = fascia destra.
  final double x;

  /// Posizione verticale relativa: 0 = area avversaria, 1 = porta propria.
  final double y;
}

/// Costruisce gli slot di un modulo, portiere incluso.
///
/// Le coordinate sono le stesse della PWA (portiere a y .91, linee a .72/.50/.27)
/// così che campo web e campo mobile si leggano allo stesso modo. Il risultato è
/// troncato a `lineupSideSize` perché il database rifiuta slot con indice pari o
/// superiore alla dimensione della squadra.
List<LineupSlot> buildLineupSlots(String format, String? formation) {
  final resolved = normalizeFormation(format, formation);
  final lines = resolved
      .split('-')
      .map((value) => int.tryParse(value) ?? 0)
      .where((value) => value > 0)
      .toList();

  // Y delle tre linee: difesa, centrocampo, attacco. Per moduli con un numero
  // diverso di linee le distribuiamo uniformemente nella stessa fascia.
  final lineY = switch (lines.length) {
    3 => const [.72, .50, .27],
    1 => const [.50],
    _ => List.generate(
        lines.length,
        (index) => .72 - index * (.45 / (lines.length - 1)),
      ),
  };

  final slots = <LineupSlot>[
    const LineupSlot(
      key: 'gk',
      role: 'Portiere',
      shortRole: 'P',
      x: .5,
      y: .91,
    ),
  ];

  var slotNumber = 1;
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final count = lines[lineIndex];
    final roles = _rolesForLine(lineIndex, lines.length, count);
    final shortRole = _shortRoleForLine(lineIndex, lines.length);
    for (var index = 0; index < count; index++) {
      slots.add(
        LineupSlot(
          key: 'p$slotNumber',
          role: roles[index],
          shortRole: shortRole,
          // Distribuzione uniforme sulla linea: con 3 giocatori -> .25, .50, .75.
          x: (index + 1) / (count + 1),
          y: lineY[lineIndex],
        ),
      );
      slotNumber += 1;
    }
  }

  final side = lineupSideSize(format);
  return slots.length <= side ? slots : slots.sublist(0, side);
}

/// Nomi dei ruoli di una linea, scelti in base a quanti giocatori la compongono.
///
/// Un 4 in difesa sono due terzini e due centrali, un 3 in attacco sono due ali
/// e una punta: senza questa distinzione il campo mostrerebbe 'Difensore 1..4'.
List<String> _rolesForLine(int line, int totalLines, int count) {
  // Prima linea davanti al portiere: difesa.
  if (line == 0) {
    return switch (count) {
      1 => const ['Difensore'],
      2 => const ['Terzino SX', 'Terzino DX'],
      3 => const ['Terzino SX', 'Difensore', 'Terzino DX'],
      4 => const ['Terzino SX', 'Dif. centrale', 'Dif. centrale', 'Terzino DX'],
      _ => List.generate(count, (index) => 'Difensore ${index + 1}'),
    };
  }
  // Ultima linea: attacco.
  if (line == totalLines - 1) {
    return switch (count) {
      1 => const ['Punta'],
      2 => const ['Attaccante SX', 'Attaccante DX'],
      3 => const ['Ala SX', 'Punta', 'Ala DX'],
      _ => List.generate(count, (index) => 'Attaccante ${index + 1}'),
    };
  }
  // Linee intermedie: centrocampo.
  return switch (count) {
    1 => const ['Mediano'],
    2 => const ['Centrocampista SX', 'Centrocampista DX'],
    3 => const ['Esterno SX', 'Mediano', 'Esterno DX'],
    4 => const ['Esterno SX', 'Centrocampista', 'Centrocampista', 'Esterno DX'],
    5 => const [
      'Esterno SX',
      'Mezzala SX',
      'Mediano',
      'Mezzala DX',
      'Esterno DX',
    ],
    _ => List.generate(count, (index) => 'Centrocampista ${index + 1}'),
  };
}

/// Sigla della linea, mostrata dentro lo slot ancora libero.
String _shortRoleForLine(int line, int totalLines) {
  if (line == 0) return 'D';
  if (line == totalLines - 1) return 'A';
  return 'C';
}
