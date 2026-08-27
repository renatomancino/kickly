import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import 'profile_widgets.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, required this.username});
  final String username;
  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  Future<ProfileDetails?>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).repository
        .getPublicProfile(widget.username);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // AppBar trasparente sopra allo sfondo dell'app (l'alone verde di
    // KicklyBackdrop), gia il default del tema: coerente col resto
    // dell'app. Niente extendBodyBehindAppBar: con quello attivo la card
    // dell'hero scorreva SOTTO la barra e, essendo trasparente, si vedeva
    // l'avatar sovrapposto al titolo mentre si scrollava.
    appBar: AppBar(
      title: Text('@${widget.username}'),
      actions: [
        // Stesso `future` del corpo pagina: Flutter permette piu'
        // FutureBuilder sullo stesso Future, nessuna chiamata di rete
        // duplicata. Il menu resta vuoto finche' il profilo non e'
        // caricato (niente da segnalare/bloccare prima di sapere chi si
        // sta guardando) e sparisce del tutto sul proprio profilo, dove
        // segnalare/bloccare se stessi non ha senso (e il database lo
        // rifiuterebbe comunque, vedi user_blocks_no_self_block/
        // user_reports_no_self_report).
        FutureBuilder<ProfileDetails?>(
          future: future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final currentUserId = AppScope.of(context).repository.currentUserId;
            if (data == null || data.profile.id == currentUserId) {
              return const SizedBox.shrink();
            }
            return _ReportBlockMenu(profile: data.profile);
          },
        ),
      ],
    ),
    body: FutureBuilder<ProfileDetails?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        // Ramo errore separato da "profilo assente": senza, un fallimento
        // di rete cadeva nello stesso `data == null` di un profilo privato
        // o inesistente, dicendo all'utente qualcosa di sbagliato invece
        // che "riprova".
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Profilo non disponibile',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: () => setState(
                  () =>
                      future = AppScope.of(context).repository
                          .getPublicProfile(widget.username),
                ),
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const PageFrame(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Profilo non disponibile',
              body: 'Il profilo non esiste oppure è privato.',
            ),
          );
        }
        final profile = data.profile, stats = data.stats;
        final elite = stats.overall >= eliteOverallThreshold;
        final accent = elite ? AppTheme.gold : AppTheme.primary;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Stessa impostazione "identita a sinistra, anello dell'overall a
            // destra" della testata del profilo privato: chi guarda un
            // profilo altrui deve riconoscere subito lo stesso linguaggio
            // visivo del proprio, non un layout diverso.
            Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: elite ? .18 : .09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: .6),
                            width: elite ? 3 : 2.4,
                          ),
                        ),
                        child: PlayerAvatar(
                          name: profile.displayName,
                          url: profile.avatarUrl,
                          radius: 46,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '@${profile.username}',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      if (profile.city != null &&
                          profile.city!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppTheme.mutedSoft,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              profile.city!,
                              style: const TextStyle(
                                color: AppTheme.mutedSoft,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      OverallRing(value: stats.overall, elite: elite),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          InfoPill(label: roleLabel(profile.primaryPosition)),
                          if (footLabel(profile.preferredFoot)
                              case final label?)
                            InfoPill(label: label, icon: Icons.sports_soccer),
                          if (skillLabel(profile.skillLevel) case final label?)
                            InfoPill(
                              label: label,
                              icon: Icons.military_tech_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            StatGrid(
              tiles: [
                StatTile(
                  label: 'Partite',
                  value: stats.matches,
                  icon: Icons.sports_soccer,
                ),
                StatTile(
                  label: 'Gol',
                  value: stats.goals,
                  icon: Icons.sports_score,
                ),
                StatTile(
                  label: 'Assist',
                  value: stats.assists,
                  icon: Icons.assistant_direction,
                ),
                StatTile(
                  label: 'MVP',
                  value: stats.mvp,
                  icon: Icons.emoji_events,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'RISULTATI',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${stats.winRate}% win rate',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ResultsBar(
                      wins: stats.wins,
                      draws: stats.draws,
                      losses: stats.losses,
                    ),
                    if (data.form.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'FORMA RECENTE',
                        style: TextStyle(
                          color: AppTheme.mutedSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        children: data.form.map((r) {
                          final (label, color) = switch (r) {
                            'win' => ('W', AppTheme.primary),
                            'loss' => ('L', AppTheme.danger),
                            _ => ('D', AppTheme.muted),
                          };
                          return CircleAvatar(
                            radius: 17,
                            backgroundColor: color.withValues(alpha: .16),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (data.history.length >= 2) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: RatingTrendChart(history: data.history),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// Menu "Segnala/Blocca" nell'AppBar del profilo di un altro giocatore.
///
/// Widget a parte (non inline nell'AppBar) perche' le due azioni hanno
/// bisogno del proprio BuildContext per aprire dialog e mostrare snackbar
/// dopo un `await`, e un widget con la propria vita e' piu' semplice da
/// tenere corretto di una closure che cattura il context della pagina.
class _ReportBlockMenu extends StatelessWidget {
  const _ReportBlockMenu({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    // Tooltip esplicito con il nome, stesso motivo di "Gestisci
    // ${member.displayName}" in league_detail_page.dart: il tooltip
    // generico "Show menu" non dice su chi agisce.
    tooltip: 'Azioni su ${profile.displayName}',
    onSelected: (action) {
      if (action == 'report') _report(context);
      if (action == 'block') _block(context);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'report', child: Text('Segnala utente')),
      PopupMenuItem(
        value: 'block',
        // Rosso: e' l'unica voce del menu che ha un effetto permanente
        // sulla relazione fra i due utenti, stesso trattamento di "Rimuovi
        // dalla lega" in league_detail_page.dart.
        child: Text('Blocca utente', style: TextStyle(color: AppTheme.danger)),
      ),
    ],
  );

  Future<void> _report(BuildContext context) async {
    final draft = await showDialog<_ReportDraft>(
      context: context,
      builder: (dialogContext) =>
          _ReportUserDialog(displayName: profile.displayName),
    );
    if (draft == null || !context.mounted) return;
    try {
      await AppScope.of(context).repository.reportUser(
        reportedUserId: profile.id,
        reason: draft.reason,
        details: draft.details,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Segnalazione inviata. Grazie, la esamineremo.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _block(BuildContext context) async {
    // Aptico prima del dialog, stesso schema di "Trasferisci proprietà" in
    // league_detail_page.dart: il primo momento in cui l'utente dichiara
    // l'intenzione e' il tocco sulla voce di menu, non la conferma.
    unawaited(HapticFeedback.mediumImpact());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bloccare ${profile.displayName}?'),
        content: Text(
          'Non vedrai più il profilo di ${profile.displayName} nella lega '
          'che condividete, e nemmeno lui/lei vedrà il tuo. '
          'Non potrai annullare questa azione da qui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: AppTheme.background,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await AppScope.of(context).repository.blockUser(profile.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hai bloccato ${profile.displayName}.')),
        );
        // Il profilo bloccato non ha piu' motivo di restare in primo
        // piano: stesso "torna indietro dopo l'azione" gia' usato per
        // "Lascia lega" altrove nell'app.
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }
}

class _ReportDraft {
  const _ReportDraft(this.reason, this.details);
  final String reason;
  final String? details;
}

/// Widget (non funzione locale) cosi' il TextEditingController del testo
/// libero e' creato in initState e distrutto in dispose(): stesso motivo di
/// _ComposeCommunicationDialogState in league_detail_page.dart — senza,
/// l'animazione di uscita del dialog potrebbe ancora usare un controller
/// gia' disposato e andare in crash.
class _ReportUserDialog extends StatefulWidget {
  const _ReportUserDialog({required this.displayName});
  final String displayName;
  @override
  State<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<_ReportUserDialog> {
  String _reason = reportReasons.first;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Segnala ${widget.displayName}'),
    content: SizedBox(
      // Larghezza esplicita, stesso motivo di _ComposeCommunicationDialog:
      // senza, l'AlertDialog si stringe attorno al contenuto e l'elenco dei
      // motivi diventa strettissimo su schermi larghi.
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motivo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            // RadioGroup avvolge i tile invece di passare groupValue/onChanged
            // a ciascuno: da Flutter 3.32 sono le API deprecate (vedi
            // deprecated_member_use in `flutter analyze`), sostituite da un
            // singolo ancestor che gestisce la selezione per tutto il gruppo.
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reason in reportReasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: reason,
                      title: Text(reportReasonLabel(reason)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Aggiungi dettagli (facoltativo)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _ReportDraft(
            _reason,
            _details.text.trim().isEmpty ? null : _details.text.trim(),
          ),
        ),
        child: const Text('Invia segnalazione'),
      ),
    ],
  );
}
