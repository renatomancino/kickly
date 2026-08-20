import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';

/// Contenuto di un passo della vetrina: numero, titolo, corpo.
///
/// `isLast` decide sia se il tap a destra chiude la vetrina invece di
/// avanzare, sia se mostrare il pulsante "Comincia" al posto di lasciare
/// che sia solo il tap/il timer a far proseguire.
class _StoryStep {
  const _StoryStep({
    required this.number,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String body;
  final bool isLast;
}

const _steps = [
  _StoryStep(
    number: '1',
    title: 'Trova la lega',
    body: 'Cerca, unisciti, o creane una nuova.',
  ),
  _StoryStep(
    number: '2',
    title: 'Rispondi presente',
    body: 'Un tap per dire che ci sei.',
  ),
  _StoryStep(
    number: '3',
    title: 'Gioca e traccia tutto',
    body: 'Gol, assist, MVP: restano nella tua scheda.',
    isLast: true,
  ),
];

/// Durata di avanzamento automatico di un passo, cioè quanto impiega il
/// segmento a riempirsi. Tenerla sull'ultimo passo non fa scattare un
/// avanzamento (non c'è un passo successivo): resta semplicemente pieno,
/// col pulsante "Comincia" già visibile.
const _stepDuration = Duration(milliseconds: 4200);

/// Sopra questa soglia una pressione prolungata non conta come tap: è la
/// stessa distinzione delle storie Instagram, "tieni premuto per mettere
/// in pausa, rilascia veloce per avanzare/tornare indietro".
const _holdThreshold = Duration(milliseconds: 300);

/// Vetrina a episodi mostrata una sola volta, al primissimo avvio dell'app,
/// PRIMA del login (instradata da app.dart quando AppState.introSeen è
/// false). Tre passi, avanzamento a tempo con barra segmentata in alto,
/// tap laterale per andare avanti/indietro a mano, tieni premuto per
/// mettere in pausa — stessa grammatica delle storie Instagram/Spotify
/// Wrapped, applicata alla direzione "3 passi, via veloce" scelta dopo aver
/// confrontato le alternative sulla canvas di design.
class StoryOnboardingPage extends StatefulWidget {
  const StoryOnboardingPage({super.key});

  @override
  State<StoryOnboardingPage> createState() => _StoryOnboardingPageState();
}

class _StoryOnboardingPageState extends State<StoryOnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;
  DateTime? _pressStartedAt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _stepDuration)
      ..addStatusListener(_handleAnimationStatus)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Sull'ultimo passo il timer arriva comunque a fine corsa (la barra si
    // riempie), ma non deve chiudere la vetrina da solo: l'uscita, lì, è
    // sempre una scelta esplicita (tap a destra o "Comincia").
    if (_steps[_currentIndex].isLast) return;
    _goToStep(_currentIndex + 1);
  }

  void _goToStep(int index) {
    setState(() => _currentIndex = index);
    _controller
      ..stop()
      ..reset()
      ..forward();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressStartedAt = DateTime.now();
    _controller.stop();
  }

  void _handleTapUp(TapUpDetails details) {
    final startedAt = _pressStartedAt;
    _pressStartedAt = null;
    final wasHold =
        startedAt != null &&
        DateTime.now().difference(startedAt) >= _holdThreshold;
    if (wasHold) {
      // Solo una pausa: riprende da dove si era fermata, niente navigazione.
      _controller.forward();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx < width / 2) {
      _goBack();
    } else {
      _goForward();
    }
  }

  void _handleTapCancel() {
    _pressStartedAt = null;
    // Un tap "annullato" (es. il dito scivola oltre la soglia di tolleranza)
    // non deve lasciare la barra ferma per sempre.
    _controller.forward();
  }

  void _goBack() {
    if (_currentIndex == 0) {
      _controller.forward();
      return;
    }
    _goToStep(_currentIndex - 1);
  }

  void _goForward() {
    if (_steps[_currentIndex].isLast) {
      _finish();
      return;
    }
    _goToStep(_currentIndex + 1);
  }

  Future<void> _finish() async {
    _controller.stop();
    await AppScope.of(context).appState.completeIntro();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Numero enorme e sbiadito sullo sfondo, sotto a tutto: stesso
            // dettaglio della direzione scelta sulla canvas, dà peso visivo
            // al passo senza competere con testo/CTA sopra.
            Positioned(
              right: -18,
              top: 70,
              child: IgnorePointer(
                child: Text(
                  step.number,
                  style: const TextStyle(
                    fontSize: 260,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -10,
                    height: 1,
                    color: Color(0x0DFFFFFF),
                  ),
                ),
              ),
            ),
            // Livello di tap: sotto ai controlli (X, CTA) nello z-order dello
            // Stack, così quei due restano gli unici punti dove il tap non
            // naviga. Ovunque altro sullo schermo, testo compreso, ricade
            // qui perché Text/Container non hanno un proprio gesture
            // detector che intercetti il tocco prima.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => Row(
                            children: [
                              for (var i = 0; i < _steps.length; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                Expanded(
                                  child: _Segment(fill: _segmentFill(i)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 44x44 di tap target reale (IconButton di Material),
                      // anche se l'icona disegnata è più piccola: sotto quella
                      // soglia il tocco diventa impreciso su schermo vero.
                      IconButton(
                        onPressed: _finish,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.muted,
                        ),
                        tooltip: 'Salta',
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'PASSO ${step.number}',
                              style: const TextStyle(
                                color: AppTheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            step.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppTheme.muted),
                          ),
                          if (step.isLast) ...[
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _finish,
                              child: const Text('Comincia'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quanto del segmento `index` dev'essere pieno, in base al passo corrente
  /// e (per il passo attivo) al valore live dell'animazione.
  double _segmentFill(int index) {
    if (index < _currentIndex) return 1;
    if (index > _currentIndex) return 0;
    return _controller.value;
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        // Positioned.fill è necessario: dentro a uno Stack un ColoredBox
        // senza figlio riceve vincoli "loose" e collassa a dimensione zero
        // (si vedeva sul simulatore: barra invisibile). Positioned.fill
        // forza i vincoli tight della dimensione dello Stack, sia sulla
        // traccia sia sul riquadro da ridurre con FractionallySizedBox.
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x26FFFFFF))),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill.clamp(0.0, 1.0).toDouble(),
                child: const ColoredBox(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
