import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Soglia di overall oltre la quale un giocatore riceve il trattamento
/// "elite" (oro invece del verde del marchio). Condivisa fra profilo privato
/// e pubblico: prima ogni file ne teneva una copia propria, con lo stesso
/// valore scritto due volte e il rischio che un domani cambiasse in una sola
/// delle due card.
const eliteOverallThreshold = 85;

/// Massimo scala dell'anello dell'overall. 99 e non 100 di proposito: e la
/// stessa convenzione delle card FIFA/FUT gia citata nei commenti storici di
/// questo file, cosi un overall "alto" riempie l'anello quasi per intero
/// invece di fermarsi visibilmente sotto meta.
const _ringMax = 99;

String roleLabel(String? role) => switch (role) {
  'goalkeeper' => 'Portiere',
  'defender' => 'Difensore',
  'midfielder' => 'Centrocampista',
  'forward' => 'Attaccante',
  _ => 'Giocatore',
};

/// A differenza di [roleLabel] non ha un valore di default: se il piede
/// preferito non e stato impostato, chi lo mostra deve semplicemente
/// ometterlo invece di inventare un dato.
String? footLabel(String? foot) => switch (foot) {
  'right' => 'Destro',
  'left' => 'Sinistro',
  'both' => 'Entrambi',
  _ => null,
};

/// Idem per il livello.
String? skillLabel(String? level) => switch (level) {
  'beginner' => 'Principiante',
  'amateur' => 'Amatore',
  'competitive' => 'Competitivo',
  _ => null,
};

/// Anello di progresso attorno al numero dell'overall, sul modello degli
/// anelli attivita di Apple Fitness: sostituisce la vecchia tessera
/// rettangolare a tinta unita, che comunicava il numero ma non quanto fosse
/// "pieno" rispetto al massimo della scala.
class OverallRing extends StatelessWidget {
  const OverallRing({
    super.key,
    required this.value,
    required this.elite,
    this.diameter = 132,
    this.strokeWidth = 11,
  });

  final int value;
  final bool elite;
  final double diameter;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(diameter),
            painter: _RingPainter(
              fraction: (value / _ringMax).clamp(0, 1),
              elite: elite,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'OVERALL',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.elite,
    required this.strokeWidth,
  });

  final double fraction;
  final bool elite;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceHigh;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (fraction <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // Sfumatura oro->verde solo per le card elite, cosi l'anello "brilla"
    // come la fascia da capitano invece di essere di un oro piatto.
    progress.shader = elite
        ? SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 1.5,
            colors: const [AppTheme.gold, AppTheme.primary, AppTheme.gold],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect)
        : null;
    // Ignorato quando lo shader e impostato (caso elite): resta il colore
    // pieno per il caso normale.
    progress.color = AppTheme.primary;

    // Da ore 12 in senso orario, come gli anelli Activity.
    const start = -math.pi / 2;
    canvas.drawArc(rect, start, math.pi * 2 * fraction, false, progress);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.elite != elite ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Barra dei risultati: vittorie, pareggi e sconfitte come segmenti
/// proporzionali sulla stessa riga, sul modello delle barre a stadi
/// (sonno, categorie di spesa) delle app Apple. Sostituisce la vecchia barra
/// rosso-giallo-verde con un singolo indicatore: quella comunicava un voto
/// unico ("quanto sei bravo"), questa comunica una composizione ("come sono
/// andate le partite"), che e l'informazione che i tre numeri sotto
/// descrivono davvero.
class ResultsBar extends StatelessWidget {
  const ResultsBar({
    super.key,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  final int wins;
  final int draws;
  final int losses;

  int get _total => wins + draws + losses;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(height: 10, color: AppTheme.surfaceHigh),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (wins > 0) Expanded(flex: wins, child: const _BarSegment(AppTheme.primary)),
                if (wins > 0 && (draws > 0 || losses > 0))
                  const SizedBox(width: 2),
                if (draws > 0) Expanded(flex: draws, child: const _BarSegment(AppTheme.muted)),
                if (draws > 0 && losses > 0) const SizedBox(width: 2),
                if (losses > 0) Expanded(flex: losses, child: const _BarSegment(AppTheme.danger)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _ResultLegend(color: AppTheme.primary, label: 'Vittorie', value: wins),
            _ResultLegend(color: AppTheme.muted, label: 'Pareggi', value: draws),
            _ResultLegend(color: AppTheme.danger, label: 'Sconfitte', value: losses),
          ],
        ),
      ],
    );
  }
}

class _BarSegment extends StatelessWidget {
  const _BarSegment(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => ColoredBox(color: color);
}

class _ResultLegend extends StatelessWidget {
  const _ResultLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$value',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12.5)),
    ],
  );
}

/// Grafico dell'andamento dell'overall nel tempo, ricavato da
/// `player_rating_history` (il campo `history` di `ProfileDetails`, raccolto
/// da tempo ma prima mai mostrato da nessuna schermata). Linea con
/// riempimento sfumato sotto, sul modello dei grafici di Apple Health/Fitness
/// — non un semplice numero statico ma un vero andamento.
class RatingTrendChart extends StatelessWidget {
  const RatingTrendChart({super.key, required this.history});

  final List<Map<String, dynamic>> history;

  List<double> get _values => history
      .map((row) => (row['new_rating'] as num?)?.toDouble())
      .whereType<double>()
      .toList();

  @override
  Widget build(BuildContext context) {
    final values = _values;
    if (values.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Ancora poche partite valutate per mostrare un andamento.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
      );
    }
    final delta = values.last - values.first;
    final (deltaLabel, deltaColor) = switch (delta) {
      > 0 => ('+${delta.round()}', AppTheme.primary),
      < 0 => ('${delta.round()}', AppTheme.danger),
      _ => ('±0', AppTheme.muted),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ULTIME VALUTAZIONI',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                deltaLabel,
                style: TextStyle(
                  color: deltaColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          width: double.infinity,
          child: CustomPaint(painter: _TrendPainter(values)),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min) - 1;
    final maxV = values.reduce(math.max) + 1;
    final span = (maxV - minV).clamp(1, double.infinity);
    final stepX = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final normalized = (values[i] - minV) / span;
      return Offset(stepX * i, size.height * (1 - normalized));
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = pointAt(i - 1);
      final curr = pointAt(i);
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    line.lineTo(pointAt(values.length - 1).dx, pointAt(values.length - 1).dy);

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: .28),
            AppTheme.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppTheme.primary,
    );

    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = AppTheme.background);
    canvas.drawCircle(
      last,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppTheme.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Badge coerente per ruolo/piede/livello, sia sul profilo privato sia su
/// quello pubblico: prima ognuno dei due file disegnava la propria pillola
/// (una con `Container`, l'altra con `Chip`), quindi lo stesso dato aveva un
/// aspetto leggermente diverso a seconda di dove compariva.
class ProfileInfoPill extends StatelessWidget {
  const ProfileInfoPill({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppTheme.muted),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
