import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Elenco delle leghe che bloccano la cancellazione dell'account: il
/// chiamante ne è owner e ci sono altri membri attivi oltre a lui.
///
/// Widget puro (dati e callback passati dal chiamante, nessuna chiamata di
/// rete propria): le azioni per sbloccare sono quelle già esistenti in
/// LeagueDetailPage ("Trasferisci proprietà", per membro) e
/// LeagueSettingsPage ("Elimina lega") — questa lista si limita a linkarle,
/// non le reimplementa.
class AccountDeletionBlockersList extends StatelessWidget {
  const AccountDeletionBlockersList({
    super.key,
    required this.blockers,
    required this.onOpenLeague,
    required this.onOpenLeagueSettings,
    required this.onRecheck,
  });

  final List<AccountDeletionBlocker> blockers;
  final ValueChanged<String> onOpenLeague;
  final ValueChanged<String> onOpenLeagueSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prima di eliminare l\'account devi risolvere la proprietà di '
          'queste leghe: trasferiscile a un altro membro oppure eliminale, '
          'se sei rimasto l\'unico.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        for (final blocker in blockers) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blocker.leagueName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${blocker.activeMemberCount} membri attivi',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onOpenLeague(blocker.leagueSlug),
                          child: const Text('Trasferisci proprietà'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              onOpenLeagueSettings(blocker.leagueSlug),
                          child: const Text('Elimina lega'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRecheck,
            child: const Text('Ricontrolla'),
          ),
        ),
      ],
    ),
  );
}
