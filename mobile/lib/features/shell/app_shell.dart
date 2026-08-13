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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFA0B0D0C),
        border: Border(top: BorderSide(color: AppTheme.outline)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(child: _item(context, items[i], i == active)),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -13),
                child: Center(
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
                          color: AppTheme.background,
                          size: 27,
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
      ),
    );
  }

  Widget _item(
    BuildContext context,
    (IconData, IconData, String, String) item,
    bool active,
  ) {
    return InkWell(
      onTap: () => context.go(item.$4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.$2 : item.$1,
            size: 21,
            color: active ? AppTheme.primary : Colors.white54,
          ),
          const SizedBox(height: 3),
          Text(
            item.$3,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active ? AppTheme.primary : Colors.white54,
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
                style: TextStyle(color: Colors.white54),
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
