import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../data/kickly_repository.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppState? _appState;
  int _seenRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context).appState;
    if (!identical(state, _appState)) {
      _appState?.removeListener(_onStateChanged);
      _appState = state;
      _seenRevision = state.notificationRevision;
      state.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    _appState?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final state = _appState!;
    if (state.notificationRevision == _seenRevision) return;
    _seenRevision = state.notificationRevision;
    final notification = state.latestNotification;
    if (notification == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notification.title}\n${notification.body}'),
          action: notification.link?.startsWith('/') == true
              ? SnackBarAction(
                  label: 'Apri',
                  onPressed: () => context.push(notification.link!),
                )
              : null,
        ),
      );
    });
  }

  int get _selectedIndex {
    if (widget.location.startsWith('/leagues')) return 1;
    if (widget.location.startsWith('/matches')) return 2;
    if (widget.location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: widget.child),
      bottomNavigationBar: _KicklyBottomBar(selectedIndex: _selectedIndex),
    );
  }
}

class _KicklyBottomBar extends StatelessWidget {
  const _KicklyBottomBar({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home, 'Home', '/dashboard'),
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        'Partite',
        '/matches',
      ),
      (Icons.shield_outlined, Icons.shield, 'Leghe', '/leagues'),
      (Icons.person_outline, Icons.person, 'Profilo', '/profile'),
    ];
    // The route order in the original shell was Home, Leagues, Matches, Profile.
    final active = switch (selectedIndex) {
      1 => 2,
      2 => 1,
      _ => selectedIndex,
    };
    // Slot nella Row: 5 in tutto (4 item + il "+" al centro). L'item attivo
    // dopo lo slot del "+" scala di uno per restare allineato alla Row.
    const slots = 5;
    final activeSlot = active < 2 ? active : active + 1;
    // Centro dello slot attivo, in coordinate Alignment (-1..1). Alignment
    // posiziona il figlio in base al proprio bordo (non al centro assoluto
    // del parent) quando ha una larghezza propria: con un figlio largo
    // 1/slots del parent, il centro dello slot k è a x = 2k/(slots-1) - 1,
    // non -1 + 2(k+0.5)/slots (quella formula ignorerebbe la larghezza del
    // figlio e sfaserebbe la lampada rispetto all'icona).
    final lampAlignX = 2 * activeSlot / (slots - 1) - 1;
    // Ispirata al pattern "tubelight navbar" (capsula fluttuante, sfondo
    // vetro, indicatore luminoso che scivola da una tab all'altra) invece
    // del rettangolo squadrato incollato al bordo di prima. Adattata da
    // React/Tailwind/Framer Motion a Flutter: niente CSS `layoutId`, la
    // lampada scivola con un AnimatedAlign dentro uno Stack sopra la Row.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Superficie semitrasparente: lascia intravedere l'alone verde
          // di `KicklyBackdrop` dietro, per l'aria "di vetro" del
          // `backdrop-blur-lg` originale (un vero blur richiederebbe che il
          // contenuto scorra sotto la barra, che qui non fa).
          color: AppTheme.surfaceHigh.withValues(alpha: .74),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment(lampAlignX, -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / slots,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          // Doppio alone sfumato sotto la barretta, come i
                          // tre blob sovrapposti (`blur-md`/`blur-sm`) del
                          // componente originale.
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: .55),
                              blurRadius: 14,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: .28),
                              blurRadius: 26,
                              spreadRadius: 3,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(child: _item(context, items[i], i == active)),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -13),
                      child: Center(
                        child: DecoratedBox(
                          // Alone verde sotto al pulsante, come lo
                          // `shadow-[0_10px_28px_-8px_var(--primary)]` della
                          // PWA: è quello che lo fa sembrare acceso invece di
                          // un quadrato verde appiccicato sulla barra.
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: .45),
                                blurRadius: 22,
                                spreadRadius: -6,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: Material(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _quickActions(context),
                              child: const SizedBox(
                                width: 50,
                                height: 50,
                                child: Icon(
                                  Icons.add,
                                  color: AppTheme.onPrimary,
                                  size: 27,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 2; i < items.length; i++)
                    Expanded(child: _item(context, items[i], i == active)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    (IconData, IconData, String, String) item,
    bool active,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.go(item.$4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.$2 : item.$1,
            size: 21,
            color: active ? AppTheme.primary : AppTheme.muted,
          ),
          const SizedBox(height: 3),
          Text(
            item.$3,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active ? AppTheme.primary : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  void _quickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Azioni rapide',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Cosa vuoi organizzare?',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/matches/new');
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Crea partita'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/leagues/new');
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('Crea lega'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
