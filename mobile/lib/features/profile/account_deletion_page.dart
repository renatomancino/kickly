import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
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

/// Pagina "Elimina account": controlla prima le leghe bloccanti (vedi
/// AccountDeletionBlockersList) e, solo se non ce ne sono, mostra cosa si
/// perde/cosa resta e il pulsante che apre il dialog di conferma.
class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  Future<List<AccountDeletionBlocker>>? _future;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getAccountDeletionBlockers();
  }

  void _recheck() {
    setState(() {
      _future = AppScope.of(context).repository.getAccountDeletionBlockers();
    });
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.deleteAccount();
      // Nessun context.go('/login') qui: lo stesso pattern già usato per
      // "Esci" in profile_page.dart. AppState.signOut() chiama già
      // notifyListeners(), e il redirect del router (refreshListenable)
      // manda già da solo al login quando isSignedIn diventa false. Un
      // context.go qui in più correrebbe in parallelo con quel redirect
      // automatico.
      if (mounted) await AppScope.of(context).appState.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
        // Caso raro (corsa fra il controllo fatto al caricamento della
        // pagina e questo tap: nel frattempo l'utente e' tornato owner di
        // una lega con altri membri): request_account_deletion() ricontrolla
        // sempre lato server e puo' rifiutarsi anche se la pagina si era
        // aperta senza leghe bloccanti. Rifare il fetch porta subito alla
        // schermata di risoluzione invece di lasciare l'utente su uno
        // SnackBar senza via d'uscita chiara.
        if (error.toString().contains('account_has_blocking_leagues')) {
          _recheck();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Elimina account')),
    body: FutureBuilder<List<AccountDeletionBlocker>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 1);
        }
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Impossibile controllare l\'account',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: _recheck,
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final blockers = snapshot.data ?? const [];
        if (blockers.isNotEmpty) {
          // SingleChildScrollView: se l'utente possiede molte leghe
          // bloccanti, la Column di AccountDeletionBlockersList (una card
          // per lega, altezza non limitata) può superare l'altezza dello
          // schermo su dispositivi piccoli. Senza scroll qui sotto,
          // Flutter lancerebbe un overflow "RenderFlex overflowed" invece
          // di lasciare l'utente scorrere fino al pulsante "Ricontrolla".
          return SingleChildScrollView(
            child: AccountDeletionBlockersList(
              blockers: blockers,
              onOpenLeague: (slug) => context.push('/leagues/$slug'),
              onOpenLeagueSettings: (slug) =>
                  context.push('/leagues/$slug/settings'),
              onRecheck: _recheck,
            ),
          );
        }
        return SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perdi foto profilo, nome, data di nascita e città. Restano, '
                  'in forma anonima, le partite giocate e le statistiche '
                  'condivise con le tue leghe. Non si torna indietro.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: AppTheme.background,
                    ),
                    onPressed: _busy ? null : _confirmAndDelete,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Elimina il mio account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// Widget dedicato (non un TextEditingController locale distrutto subito
// dopo l'await di showDialog) così il controller vive quanto l'Element del
// dialog: stesso motivo di _DeleteLeagueDialog in league_settings_page.dart.
class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  final _confirmation = TextEditingController();

  /// Vero solo se il testo digitato è esattamente "ELIMINA".
  ///
  /// Testo fisso invece del nome utente o di una password: a differenza di
  /// _DeleteLeagueDialog (dove digitare il nome della lega è anche una
  /// prova di aver letto qual è la lega giusta), qui l'account è uno solo e
  /// non c'è ambiguità da disambiguare — l'obiettivo è solo rallentare un
  /// tap accidentale, senza chiedere una password che chi ha fatto login
  /// con Google o Apple potrebbe non avere mai impostato.
  bool get _matches => _confirmation.text.trim() == 'ELIMINA';

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.warning_amber_outlined, color: AppTheme.danger),
    title: const Text('Eliminare l\'account?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perdi foto profilo, nome, data di nascita e città. Restano, in '
          'forma anonima, le partite giocate e le statistiche condivise con '
          'le tue leghe. Non si torna indietro.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 14),
        const Text(
          'Per confermare, digita "ELIMINA".',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmation,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ELIMINA',
            suffixIcon: _matches
                ? const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.primary,
                    size: 20,
                  )
                : null,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Annulla'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.danger,
          foregroundColor: AppTheme.background,
        ),
        onPressed: _matches ? () => Navigator.pop(context, true) : null,
        child: const Text('Elimina'),
      ),
    ],
  );
}
