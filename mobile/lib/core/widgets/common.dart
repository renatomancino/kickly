import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../theme/app_theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 22,
  });

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceHigh,
      foregroundColor: AppTheme.primary,
      backgroundImage: url == null ? null : CachedNetworkImageProvider(url!),
      // Le iniziali sono un ripiego grafico per la foto mancante, non un
      // contenuto: un lettore di schermo le sillabava lettera per lettera
      // ("emme, ci") subito prima del nome per esteso, che in ogni uso di
      // questo widget sta lì accanto (ListTile, riga della rosa, testata del
      // profilo). ExcludeSemantics e non un `Semantics(label: name)`: qui
      // l'informazione non manca, è già raggiungibile dal testo vicino —
      // etichettare l'avatar col nome lo farebbe solo annunciare due volte.
      child: url == null
          ? ExcludeSemantics(
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
    );
  }
}

/// Pillola neutra per un metadato secondario (ruolo, formato, piede, livello).
///
/// Sta qui e non dentro `features/profile/` perché lo stesso identico elemento
/// serve in più aree dell'app (player card, elenco leghe): tenerlo nella
/// feature del profilo avrebbe costretto le altre feature a importarsi fra
/// loro per riusarlo.
///
/// Da non confondere con la pillola verde usata dentro `MatchCard`: quella
/// segnala uno *stato* (ci sei / lista d'attesa / distanza) e per questo è
/// tinta del colore del marchio. Questa è deliberatamente neutra, perché
/// descrive un attributo e non deve competere visivamente con i dati veri
/// della card.
class InfoPill extends StatelessWidget {
  const InfoPill({required this.label, this.icon, super.key});

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
          // Flexible: la pillola si dimensiona sul contenuto
          // (MainAxisSize.min), ma quando il genitore la stringe — riga
          // affollata, schermo piccolo, testo di sistema ingrandito — senza
          // questo l'etichetta non si accorcia e sfonda la pillola.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tessera statistica della dashboard.
///
/// Con [highlight] assume il verde pieno del marchio: serve per l'Overall, che
/// prima era una Card costruita a mano e disallineata dalle altre quattro.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final Object value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? AppTheme.onPrimary : AppTheme.foreground;
    return Card(
      color: highlight ? AppTheme.primary : null,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: highlight ? AppTheme.onPrimary : AppTheme.primary,
              size: 18,
            ),
            // FittedBox invece di una dimensione fissa: con il font di sistema
            // ingrandito un numero a tre cifre usciva dalla tessera.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$value',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: foreground,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight
                    ? AppTheme.onPrimary.withValues(alpha: .75)
                    : AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Griglia di tessere statistiche che si adatta alla larghezza disponibile.
///
/// Sostituisce il `GridView.count` con `childAspectRatio` fisso che c'era
/// prima: quel rapporto legava l'altezza alla larghezza della colonna, quindi
/// su schermi stretti o con il testo ingrandito il contenuto sfondava la
/// tessera. Qui le colonne derivano dalla larghezza e l'altezza è esplicita.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    // L'altezza segue l'ingrandimento del testo di sistema invece di essere
    // dedotta dalla larghezza della colonna: è questo che impediva l'overflow.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 104 * scale.clamp(1.0, 1.3);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // Due colonne su telefono, di più su tablet e in orizzontale.
        crossAxisCount: switch (MediaQuery.sizeOf(context).width) {
          >= 900 => 5,
          >= 620 => 3,
          _ => 2,
        },
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // Altezza esplicita: sostituisce childAspectRatio, che legava
        // l'altezza alla larghezza e su schermi stretti tagliava il contenuto.
        mainAxisExtent: height,
      ),
      children: tiles,
    );
  }
}

/// Blocco grigio animato mostrato al posto del contenuto durante il
/// caricamento.
///
/// La PWA ha degli skeleton (`loading.tsx`, `components/ui/skeleton`), l'app
/// mobile mostrava una rotellina centrata su schermo vuoto: è uno dei punti in
/// cui il mobile sembrava più povero del web.
class KicklySkeleton extends StatefulWidget {
  const KicklySkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<KicklySkeleton> createState() => _KicklySkeletonState();
}

class _KicklySkeletonState extends State<KicklySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Pulsazione lenta fra due opacità: comunica attesa senza il rumore di
      // uno shimmer che scorre.
      opacity: Tween<double>(
        begin: .45,
        end: .9,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Segnaposto a forma di card, usato mentre liste e dettagli caricano.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, this.lines = 3, this.height = 132});

  final int lines;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KicklySkeleton(height: 14, width: 110, radius: 7),
            const SizedBox(height: 12),
            KicklySkeleton(height: height, radius: 14),
            const SizedBox(height: 14),
            for (var index = 0; index < lines; index++) ...[
              KicklySkeleton(
                height: 11,
                // Righe di lunghezza diversa: un blocco di barre identiche
                // legge come un errore di rendering, non come attesa.
                width: index.isEven ? double.infinity : 180,
                radius: 6,
              ),
              if (index < lines - 1) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

/// Schermata di caricamento riutilizzabile: intestazione più alcune card finte.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.items = 2});

  final int items;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    children: [
      const KicklySkeleton(height: 22, width: 190, radius: 9),
      const SizedBox(height: 8),
      const KicklySkeleton(height: 13, width: 130, radius: 7),
      const SizedBox(height: 22),
      for (var index = 0; index < items; index++) ...[
        const CardSkeleton(),
        if (index < items - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class LeagueLogo extends StatelessWidget {
  const LeagueLogo({super.key, required this.league, this.size = 54});

  final LeagueSummary league;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: AppTheme.outline),
        image: league.logoUrl == null
            ? null
            : DecorationImage(
                image: CachedNetworkImageProvider(league.logoUrl!),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      // Stesso ragionamento di PlayerAvatar: l'iniziale è il segnaposto del
      // logo mancante, e il nome della lega è sempre subito accanto (elenco
      // leghe, dashboard, testata del dettaglio) o già dichiarato dal
      // pulsante che contiene il logo (impostazioni lega). Senza questo il
      // lettore di schermo premette una lettera isolata a ogni voce.
      child: league.logoUrl == null
          ? ExcludeSemantics(
              child: Text(
                league.name.isEmpty ? 'K' : league.name[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: size * .38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    );
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final response = switch (match.currentResponse) {
      'going' => 'Ci sei',
      'waitlist' => 'Lista attesa',
      'not_going' || 'declined' => 'Non ci sei',
      _ => null,
    };
    final full = match.goingCount >= match.maxPlayers;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La copertina esce a filo dei bordi della card invece di stare in
            // un riquadro dentro al padding: la Card ha clipBehavior antiAlias,
            // quindi gli angoli restano arrotondati.
            if (match.coverImageUrl?.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: match.coverImageUrl!,
                width: double.infinity,
                height: 136,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Riquadro data come nella PWA: giorno sopra, ora sotto.
                      // È l'elemento che rende la lista scansionabile a colpo
                      // d'occhio.
                      _DateTile(when: match.startsAt),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              match.leagueName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (response != null)
                        _Pill(
                          label: response,
                          filled: match.currentResponse == 'going',
                        )
                      else if (match.distanceKm != null)
                        _Pill(
                          label:
                              '${match.distanceKm!.toStringAsFixed(match.distanceKm! < 10 ? 1 : 0)} km',
                        ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  // Wrap invece di righe fisse: con testi lunghi o font
                  // ingrandito i metadati vanno a capo invece di troncarsi.
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        icon: Icons.location_on_outlined,
                        label: match.locationName,
                      ),
                      _Meta(
                        icon: Icons.sports_soccer,
                        label: match.footballFormat.replaceAll('v', ' vs '),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: (match.goingCount / match.maxPlayers).clamp(0, 1),
                      backgroundColor: AppTheme.surfaceHigh,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    full
                        ? 'Completa · ${match.goingCount}/${match.maxPlayers}'
                        : '${match.goingCount}/${match.maxPlayers} giocatori · ${match.maxPlayers - match.goingCount} posti',
                    style: TextStyle(
                      color: full ? AppTheme.primary : AppTheme.muted,
                      fontSize: 12,
                      fontWeight: full ? FontWeight.w800 : FontWeight.w500,
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
}

/// Riquadro con giorno e ora, come il blocco data della MatchCard della PWA.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.when});

  final DateTime when;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: .1),
      // Token e non il 14 scritto a mano: questo riquadro vive dentro la Card
      // di ogni partita, e `MatchCard` compare in Home, calendario e dettaglio
      // lega — un raggio fuori scala qui non restava un dettaglio locale, si
      // propagava a tre schermate. radiusMd (13) è il token dei blocchi
      // piccoli, lo stesso di campi e pulsanti, e resta ben dentro il
      // radiusLg (18) della Card che lo contiene: un blocco interno più
      // arrotondato del suo contenitore fa sembrare i due angoli disallineati.
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('EEE d', 'it_IT').format(when).toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          DateFormat('HH:mm').format(when),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    ),
  );
}

/// Etichetta a pillola, equivalente del Badge della PWA.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: filled
          ? AppTheme.primary
          : AppTheme.primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: filled ? AppTheme.onPrimary : AppTheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Coppia icona + testo per i metadati secondari della card.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.muted),
      const SizedBox(width: 5),
      ConstrainedBox(
        // Un nome di campo lungo non deve spingere fuori l'altro metadato.
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
      ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.primary.withValues(alpha: .12),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              body,
              style: const TextStyle(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Traduce l'errore tecnico in un messaggio comprensibile.
///
/// Le RPC Supabase segnalano i casi previsti con `raise exception '<codice>'`,
/// quindi il codice arriva nel testo dell'eccezione. Senza queste voci ogni
/// rifiuto legittimo (slot già occupato, presenza non confermata, fascia da
/// capitano già assegnata) finiva nel messaggio generico in fondo, lasciando il
/// giocatore senza idea di cosa fare.
String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Invalid login credentials')) {
    return 'Email o password non corrette.';
  }
  if (text.contains('User already registered')) {
    return 'Esiste già un account con questa email.';
  }
  if (text.contains('league_full')) {
    return 'La lega ha raggiunto il numero massimo di membri.';
  }
  if (text.contains('invalid_invite')) return 'Il codice invito non è valido.';

  // Formazione: codici sollevati da set_match_lineup_slot,
  // leave_match_lineup e set_match_lineup_formation.
  if (text.contains('lineup_slot_taken')) {
    return 'Questa posizione è appena stata presa da un altro giocatore.';
  }
  if (text.contains('lineup_captain_taken')) {
    return 'La squadra ha già un capitano.';
  }
  if (text.contains('lineup_captain_required')) {
    return 'Solo il capitano della squadra o un admin può cambiare modulo.';
  }
  if (text.contains('invalid_lineup_formation')) {
    return 'Questo modulo non è valido per il formato della partita.';
  }
  if (text.contains('invalid_lineup_slot')) {
    return 'Questa posizione non esiste nel formato della partita.';
  }
  if (text.contains('confirmed_participant_required')) {
    return 'Conferma prima la presenza alla partita.';
  }
  if (text.contains('match_locked')) {
    return 'La partita è chiusa: non si può più modificare.';
  }
  if (text.contains('match_not_found')) {
    return 'Partita non trovata o non più accessibile.';
  }
  if (text.contains('venue_phone_required')) {
    return 'Manca il telefono della struttura: aggiungilo dalle impostazioni della partita.';
  }
  if (text.contains('authentication_required')) {
    return 'Sessione scaduta: accedi di nuovo.';
  }

  // Chiusura partita: codici sollevati da finalize_match. Prima di questi
  // fix ogni errore qui cadeva nel messaggio generico in fondo, il momento
  // peggiore per un admin che sta chiudendo una partita a mano.
  if (text.contains('team_a_goals_mismatch') ||
      text.contains('team_b_goals_mismatch')) {
    return 'I gol assegnati ai giocatori non corrispondono al punteggio della squadra. Controlla i gol inseriti.';
  }
  if (text.contains('invalid_player_totals')) {
    return 'I gol o gli assist inseriti per un giocatore non sono validi.';
  }
  if (text.contains('player_totals_required')) {
    return 'Inserisci gol e assist per tutti i giocatori confermati.';
  }
  if (text.contains('duplicate_team_player')) {
    return 'Un giocatore risulta in entrambe le squadre: controlla la formazione.';
  }
  if (text.contains('teams_required')) {
    return 'Assegna tutti i giocatori confermati a una squadra prima di chiudere la partita.';
  }
  if (text.contains('all_confirmed_players_required')) {
    return 'Mancano dei giocatori confermati nelle squadre.';
  }
  if (text.contains('team_match_mismatch')) {
    return 'Questa squadra non appartiene a questa partita.';
  }
  if (text.contains('invalid_score')) {
    return 'Il punteggio inserito non è valido.';
  }

  // Iscrizioni e capienza: set_match_admin_state, set_match_response,
  // create_match/update_match.
  if (text.contains('registrations_closed')) {
    return 'Le iscrizioni a questa partita sono chiuse.';
  }
  if (text.contains('max_below_confirmed')) {
    return 'Non puoi impostare un numero massimo di giocatori inferiore alle presenze già confermate.';
  }

  // Votazione MVP: cast_mvp_vote, finalize_match_mvp.
  if (text.contains('mvp_voting_closed')) {
    return 'La votazione per l’MVP è chiusa.';
  }
  if (text.contains('mvp_voting_open')) {
    return 'La votazione per l’MVP è ancora aperta.';
  }
  if (text.contains('cannot_vote_self')) {
    return 'Non puoi votare te stesso come MVP.';
  }
  if (text.contains('invalid_mvp_candidate')) {
    return 'Questo giocatore non può essere votato come MVP.';
  }
  if (text.contains('no_mvp_candidates')) {
    return 'Nessun voto ricevuto: non è stato possibile eleggere un MVP.';
  }

  // Permessi generici sulle RPC di gestione partita/lega.
  if (text.contains('admin_required')) {
    return 'Solo un admin della lega può eseguire questa azione.';
  }
  if (text.contains('membership_required')) {
    return 'Devi essere membro della lega per eseguire questa azione.';
  }
  if (text.contains('owner_required')) {
    return 'Solo il proprietario della lega può eseguire questa azione.';
  }
  // DOPO `confirmed_participant_required`, che lo contiene come sottostringa:
  // invertirli manderebbe chi non ha confermato la presenza nel messaggio
  // sbagliato. C'è un test che pinna questo vincolo d'ordine.
  if (text.contains('participant_required')) {
    return 'Solo chi partecipa alla partita può eseguire questa azione.';
  }

  // Ingresso e uscita da una lega. Sono i codici che un utente incontra
  // facendo tutto giusto — un invito già usato, una lega diventata pubblica —
  // e proprio per questo il messaggio generico qui era il più dannoso: non
  // dice cos'è successo né cosa fare dopo.
  if (text.contains('already_member')) {
    return 'Fai già parte di questa lega.';
  }
  if (text.contains('membership_banned')) {
    return 'Non puoi rientrare in questa lega: un admin ti ha rimosso.';
  }
  if (text.contains('invite_attempts_rate_limited')) {
    // join_league_by_code conta i tentativi (giusti o sbagliati) per
    // frenare chi prova a indovinare il codice a forza bruta: un
    // "riprova tra poco" qui direbbe la verità solo per caso, "aspetta
    // qualche minuto" è il messaggio corretto anche per chi ha solo
    // sbagliato a ricopiare il codice troppe volte di fila.
    return 'Troppi tentativi con questo codice: aspetta qualche minuto '
        'prima di riprovare.';
  }
  if (text.contains('public_league_not_found')) {
    return 'Questa lega non esiste più o non è più pubblica.';
  }
  if (text.contains('location_required')) {
    return 'Imposta la tua zona per entrare in questa lega: serve a '
        'verificare che tu sia nelle vicinanze.';
  }
  if (text.contains('league_too_far')) {
    // join_public_league appende la distanza reale ("league_too_far:83"):
    // "sei a 83 km, il limite è 50" spiega perché è stato rifiutato invece
    // di far sembrare un errore casuale. Se il numero non si trova (RPC
    // futura senza suffisso) il messaggio resta comunque corretto, solo
    // meno preciso.
    final km = RegExp(r'league_too_far:(\d+)').firstMatch(text)?.group(1);
    return km == null
        ? 'Questa lega è troppo lontana: puoi entrare solo se sei nel raggio consentito.'
        : 'Questa lega è troppo lontana: sei a circa $km km, il limite per entrare da solo è 50 km.';
  }
  if (text.contains('owner_cannot_leave')) {
    return 'Sei il proprietario: trasferisci prima la lega a un altro membro, poi potrai uscire.';
  }
  if (text.contains('member_not_found')) {
    return 'Questo giocatore non fa parte della lega.';
  }
  if (text.contains('cannot_remove_owner')) {
    return 'Il proprietario della lega non può essere rimosso.';
  }
  if (text.contains('cannot_change_owner_role')) {
    return 'Il ruolo del proprietario non si può cambiare: serve trasferire la lega.';
  }
  if (text.contains('already_owner')) {
    return 'Questo giocatore è già il proprietario della lega.';
  }

  // Report e blocco (20260821090000_report_and_block_tables.sql): niente
  // RPC dedicata, quindi niente `raise exception` — l'auto-blocco e
  // l'auto-segnalazione sono rifiutati da un CHECK constraint sulla
  // tabella, e il messaggio grezzo di Postgres arriva col nome del vincolo
  // dentro, stesso schema del caso "username" piu' in basso in questo file.
  if (text.contains('user_blocks_no_self_block')) {
    return 'Non puoi bloccare te stesso.';
  }
  if (text.contains('user_reports_no_self_report')) {
    return 'Non puoi segnalare te stesso.';
  }

  // Limiti di frequenza: qui il messaggio generico è particolarmente cattivo
  // perché invita a "riprovare tra poco" senza dire quanto, e l'utente riprova
  // subito continuando a fallire.
  if (text.contains('communication_rate_limited')) {
    return 'Hai pubblicato un avviso da poco: aspetta qualche minuto prima del prossimo.';
  }
  if (text.contains('reminder_rate_limited')) {
    return 'Hai già inviato un promemoria da poco: aspetta prima di inviarne un altro.';
  }
  if (text.contains('no_reminder_recipients')) {
    return 'Nessuno da avvisare: non ci sono giocatori a cui mandare il promemoria.';
  }
  if (text.contains('communication_not_found')) {
    return 'Questo avviso è già stato eliminato.';
  }

  // Dati rifiutati dal server. Ognuno indica il campo da correggere: senza,
  // l'utente rilegge un modulo intero senza sapere dove ha sbagliato.
  if (text.contains('invalid_max_members')) {
    return 'Il numero massimo di membri non è valido.';
  }
  if (text.contains('invalid_max_players')) {
    return 'Il numero massimo di giocatori non è valido.';
  }
  if (text.contains('invalid_coordinates')) {
    return 'Non siamo riusciti a individuare il luogo scelto: riprova a selezionarlo.';
  }
  if (text.contains('invalid_venue_phone')) {
    return 'Il telefono della struttura non è valido.';
  }
  if (text.contains('invalid_communication')) {
    return 'L’avviso deve avere un titolo e un testo.';
  }
  if (text.contains('invalid_reminder')) {
    return 'Il promemoria non è valido.';
  }
  if (text.contains('invalid_location')) return 'Indica dove si gioca.';
  if (text.contains('invalid_province')) return 'La provincia non è valida.';
  if (text.contains('invalid_country')) return 'Il paese non è valido.';
  if (text.contains('invalid_title')) return 'Il titolo non è valido.';
  if (text.contains('invalid_name')) return 'Il nome non è valido.';
  if (text.contains('invalid_slug')) {
    return 'Esiste già una lega con un nome molto simile: scegline un altro.';
  }
  if (text.contains('invalid_city')) return 'La città non è valida.';
  if (text.contains('invalid_cost')) return 'Il costo inserito non è valido.';
  if (text.contains('invalid_role')) return 'Questo ruolo non esiste.';
  if (text.contains('invalid_team')) return 'Questa squadra non esiste.';
  if (text.contains('invalid_action')) return 'Azione non riconosciuta.';
  if (text.contains('invalid_response')) return 'Risposta non riconosciuta.';

  // Volutamente in fondo: 'username' è una parola comune e prima intercettava
  // errori che non avevano nulla a che fare con la registrazione.
  if (text.contains('username')) return 'Questo username non è disponibile.';
  return 'Qualcosa non ha funzionato. Riprova tra poco.';
}
