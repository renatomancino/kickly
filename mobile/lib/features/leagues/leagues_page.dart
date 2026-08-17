import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Pillola del ruolo, l'unica accesa nella card di una lega.
///
/// Delle tre informazioni in fondo alla card (ruolo, formato, membri) il ruolo
/// è l'unica che dice cosa PUOI FARE lì dentro, non com'è fatta la lega: se sei
/// owner o admin hai i comandi di gestione, se sei membro no. Accendendo di
/// verde solo questa quando gestisci, l'elenco si legge a colpo d'occhio —
/// "queste sono le mie" — senza doverne leggere il testo. Le altre due restano
/// neutre di proposito: se si accendesse tutto, non risalterebbe più niente.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.league});

  final LeagueSummary league;

  @override
  Widget build(BuildContext context) {
    if (!league.canManage) {
      return InfoPill(label: league.roleLabel, icon: Icons.person_outline);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            league.roleLabel,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class LeaguesPage extends StatefulWidget {
  const LeaguesPage({super.key});

  @override
  State<LeaguesPage> createState() => _LeaguesPageState();
}

class _LeaguesPageState extends State<LeaguesPage> {
  Future<List<LeagueSummary>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getLeagues();
  }

  Future<void> _refresh() async {
    final next = AppScope.of(context).repository.getLeagues();
    // Blocco, non arrow-expression: `() => _future = next` come closure
    // farebbe ritornare a setState() il valore dell'assegnamento, cioè la
    // Future stessa. setState() se ne accorge in debug e lancia *dopo* aver
    // già assegnato il campo ma *prima* di schedulare il rebuild, quindi il
    // resto della funzione (l'`await next` sotto) non gira più: la pagina
    // restava agganciata alla vecchia Future finché qualcos'altro non la
    // ricostruiva per altri motivi.
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le tue leghe',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Squadre, calendario e rivalità.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                // Il tooltip di default di PopupMenuButton è un generico
                // "Show menu", che a un lettore di schermo non dice nulla di
                // cosa succede premendo: qui il pulsante è l'unico modo per
                // entrare in una lega nuova, quindi va nominato.
                tooltip: 'Crea una lega o usa un invito',
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.primary,
                ),
                onSelected: (value) => context.push(value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: '/leagues/new',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Crea lega'),
                    ),
                  ),
                  PopupMenuItem(
                    value: '/leagues/join',
                    child: ListTile(
                      leading: Icon(Icons.login),
                      title: Text('Usa invito'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<LeagueSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // Column e non ListSkeleton: siamo già dentro una ListView.
                return const Column(
                  children: [
                    CardSkeleton(height: 70, lines: 2),
                    SizedBox(height: 12),
                    CardSkeleton(height: 70, lines: 2),
                  ],
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Leghe non disponibili',
                  body: friendlyError(snapshot.error!),
                  action: FilledButton(
                    onPressed: _refresh,
                    child: const Text('Riprova'),
                  ),
                );
              }
              final leagues = snapshot.data ?? const [];
              if (leagues.isEmpty) {
                return EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Crea il tuo spogliatoio',
                  body: 'Avvia una lega o inserisci il codice ricevuto da un admin.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/leagues/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crea una lega'),
                  ),
                );
              }
              return Column(
                children: leagues
                    .map(
                      (league) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            onTap: () =>
                                context.push('/leagues/${league.slug}'),
                            // Il raggio arriva dal token del tema invece che
                            // da un 20 scritto a mano: con un valore diverso
                            // da quello della Card, l'onda del tocco usciva
                            // dagli angoli arrotondati che la contengono.
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                // Allineato in alto e non centrato: con tre
                                // pillole la riga va spesso a capo, e con
                                // l'allineamento centrato il logo restava
                                // sospeso a meta' altezza con un vuoto sopra,
                                // slegato dal nome della lega. In alto invece
                                // logo e titolo partono dalla stessa riga, e
                                // la card regge sia una che due righe di
                                // pillole senza cambiare equilibrio.
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LeagueLogo(league: league, size: 58),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          league.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 13,
                                              color: AppTheme.mutedSoft,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                '${league.city}, ${league.country}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.mutedSoft,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 9),
                                        // Wrap e non Row: con tre pillole e il
                                        // testo di sistema ingrandito, su
                                        // schermi stretti vanno a capo invece
                                        // di sfondare la card.
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _RolePill(league: league),
                                            InfoPill(
                                              label: league.footballFormat
                                                  .replaceAll('v', ' vs '),
                                              icon: Icons.sports_soccer,
                                            ),
                                            InfoPill(
                                              label: league.memberCountLabel,
                                              icon: Icons.group_outlined,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Spinta in giu' di quel tanto che basta a
                                  // stare sulla riga del titolo: allineata in
                                  // alto a filo sembrerebbe appesa al bordo
                                  // della card invece che riferita alla lega.
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: AppTheme.muted,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
