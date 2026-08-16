import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Porta il codice in maiuscolo mentre lo si digita o lo si incolla.
///
/// `textCapitalization` agisce solo sulla tastiera di sistema: un codice
/// incollato dalla chat resta minuscolo e il campo mostra qualcosa di diverso
/// da ciò che verrà davvero inviato (il repository fa `toUpperCase()` per
/// conto suo). Uniformare qui elimina quel disallineamento e fa capire a colpo
/// d'occhio che il codice è alfanumerico maiuscolo.
final _upperCaseFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final upper = newValue.text.toUpperCase();
  // Se la maiuscola cambia la lunghezza del testo (succede con qualche
  // carattere non ASCII: 'ß' diventa 'SS'), gli offset di selezione contenuti
  // in newValue non corrispondono più e il cursore finirebbe fuori posto: in
  // quel caso si lascia passare il valore intatto.
  if (upper.length != newValue.text.length) return newValue;
  return newValue.copyWith(text: upper);
});

class JoinLeaguePage extends StatefulWidget {
  const JoinLeaguePage({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<JoinLeaguePage> createState() => _JoinLeaguePageState();
}

class _JoinLeaguePageState extends State<JoinLeaguePage> {
  final _code = TextEditingController();
  JsonMap? _preview;
  bool _loading = false;
  String? _error;
  // Distingue "il codice non esiste" da tutti gli altri errori (rete assente,
  // sessione scaduta, ingresso rifiutato). Sono situazioni che l'utente
  // risolve in modi opposti — ricontrollare le lettere contro riprovare più
  // tardi — e prima arrivavano entrambe come la stessa riga di testo rosso.
  bool _notFound = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.initialCode?.isNotEmpty == true) {
      _initialized = true;
      _code.text = widget.initialCode!.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_code.text.trim().length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
      _notFound = false;
      _preview = null;
    });
    try {
      final preview = await AppScope.of(context).repository
          .getInvitePreview(_code.text);
      if (mounted) {
        setState(() {
          _preview = preview;
          if (preview == null) {
            _error = 'Codice non valido o scaduto.';
            _notFound = true;
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    // Riscontro tattile alla conferma: entrare in una lega è un cambio di
    // stato per l'utente (diventa membro), non un tap di navigazione qualsiasi.
    // `unawaited`: la vibrazione è un effetto collaterale sul motore aptico,
    // attenderla ritarderebbe la richiesta di rete senza alcun beneficio.
    unawaited(HapticFeedback.lightImpact());
    setState(() => _loading = true);
    try {
      final slug = await AppScope.of(context).repository.joinLeague(_code.text);
      if (mounted) context.go('/leagues/$slug');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Unisciti a una lega')),
      body: SafeArea(
        // La pagina è cresciuta (campo + avvisi + scheda della lega) e la
        // tastiera ne copre metà: senza scorrimento, su un telefono piccolo
        // con il codice inserito il contenuto andava semplicemente in
        // overflow. Lo scroll sta fuori da PageFrame così anche il padding
        // laterale scorre insieme al contenuto.
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVITO',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hai un codice invito?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 7),
                const Text(
                  'Inseriscilo qui sotto: prima di entrare vedi di che lega si '
                  'tratta, dove si gioca e quanti posti restano.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 25),
                _codeField(),
                // L'errore di ricerca sta sotto al campo, dove l'utente ha
                // appena guardato. Gli errori di *ingresso* invece finiscono
                // dentro la scheda, a ridosso del pulsante che li ha
                // provocati (v. _LeaguePreview): con la scheda aperta questo
                // punto è già scorso via e un messaggio qui passerebbe
                // inosservato.
                if (_error != null && preview == null) ...[
                  const SizedBox(height: 16),
                  _Notice(
                    icon: _notFound ? Icons.search_off : Icons.error_outline,
                    title: _notFound ? 'Codice non valido o scaduto' : _error!,
                    body: _notFound
                        ? 'Ricontrolla lettere e numeri: si scrive tutto '
                              'attaccato, senza spazi. Se ancora non funziona, '
                              'chiedi a un admin della lega un invito nuovo.'
                        : null,
                  ),
                ],
                // Scheletro invece della rotellina nuda che c'era prima: mostra
                // già la forma di quello che sta arrivando, quindi l'attesa
                // sembra più corta e la pagina non "salta" quando il contenuto
                // compare. Solo in ricerca: durante l'ingresso la scheda è già
                // a schermo ed è il pulsante a segnalare l'attesa.
                if (_loading && preview == null) ...[
                  const SizedBox(height: 22),
                  const CardSkeleton(height: 58, lines: 2),
                ],
                if (preview != null) ...[
                  const SizedBox(height: 22),
                  _LeaguePreview(
                    preview: preview,
                    loading: _loading,
                    error: _error,
                    onJoin: _join,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeField() {
    // ValueListenableBuilder e non un listener con setState: serve solo a
    // riabilitare il pulsante di ricerca man mano che si scrive, e questo lo
    // fa ricostruendo il campo e nient'altro.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _code,
      builder: (context, value, _) {
        // Stessa soglia del controllo dentro _search(): prima il pulsante era
        // sempre attivo e sotto i 4 caratteri il tap non faceva assolutamente
        // nulla, il che si legge come "l'app è rotta" e non come "manca
        // qualcosa". Meglio un pulsante spento, che dice la stessa cosa
        // onestamente.
        final ready = value.text.trim().length >= 4;
        return TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          // I codici non sono parole: il suggerimento della tastiera
          // proporrebbe correzioni assurde su sequenze come K7QWM2XR4T.
          enableSuggestions: false,
          inputFormatters: [_upperCaseFormatter],
          decoration: InputDecoration(
            labelText: 'Codice invito',
            hintText: 'K7QWM2XR4T',
            // Il codice generato dal database è di 10 caratteri presi da un
            // alfabeto senza I, O, 0 e 1 proprio per non confondersi: dirlo
            // qui evita il tentativo alla cieca.
            helperText: 'Dieci caratteri fra lettere e numeri, senza spazi.',
            helperMaxLines: 2,
            prefixIcon: const Icon(
              Icons.confirmation_number_outlined,
              color: AppTheme.muted,
            ),
            suffixIcon: IconButton(
              tooltip: 'Cerca la lega',
              onPressed: (_loading || !ready) ? null : _search,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
          onSubmitted: (_) => _search(),
        );
      },
    );
  }
}

/// Anteprima della lega, il primo contatto con quel gruppo.
///
/// Prima era un nome, una riga di città e due `Chip` di Material: dava le
/// informazioni ma non l'impressione di stare per entrare da qualche parte.
/// Qui si aggiungono le tre cose che rispondono a "è quella giusta?" — il
/// logo (l'unico elemento riconoscibile a colpo d'occhio da chi la lega la
/// conosce già), la posizione e soprattutto quanto è piena — e si passa alle
/// `InfoPill` del design system al posto dei `Chip`.
///
/// L'accento verde di questa vista è tutto e solo sul pulsante in fondo:
/// è l'unica azione che cambia lo stato dell'utente. Per questo la barra dei
/// membri qui sotto è volutamente grigia, e non del primario come farebbe di
/// default il tema.
class _LeaguePreview extends StatelessWidget {
  const _LeaguePreview({
    required this.preview,
    required this.loading,
    required this.error,
    required this.onJoin,
  });

  final JsonMap preview;
  final bool loading;
  final String? error;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context) {
    // La riga della RPC ha le stesse chiavi di quelle usate altrove per le
    // leghe, quindi si riusa il modello invece di rileggere le chiavi a mano:
    // così arrivano gratis i valori di ripiego (nome, formato, capienza) e si
    // può passare la lega a `LeagueLogo`, esattamente come nell'elenco leghe.
    final league = LeagueSummary.fromRpc(preview);
    final alreadyMember = preview['already_member'] == true;
    final full = league.memberCount >= league.maxMembers;
    // City o country possono arrivare vuote: concatenarle a occhi chiusi
    // produceva stringhe monche come ", Italia".
    final place = [
      league.city,
      league.country,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Allineati in alto: con un nome su due righe, il logo centrato
              // resterebbe sospeso a metà con un vuoto sopra, slegato dal
              // titolo a cui appartiene.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LeagueLogo(league: league, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        league.name,
                        // Nome scritto da un utente: senza limite, una lega
                        // dal nome chilometrico sfonda la scheda.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                                place,
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Wrap e non Row: con il testo di sistema ingrandito le pillole
            // vanno a capo invece di sfondare la scheda.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                InfoPill(
                  label: league.footballFormat.replaceAll('v', ' vs '),
                  icon: Icons.sports_soccer,
                ),
                InfoPill(
                  label: league.memberCountLabel,
                  icon: Icons.group_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CapacityBar(league: league, full: full),
            if (alreadyMember) ...[
              const SizedBox(height: 16),
              const _Notice(
                icon: Icons.check_circle_outline,
                title: 'Fai già parte di questa lega',
                accent: AppTheme.muted,
              ),
            ],
            // Errore di ingresso: sta qui, appiccicato al pulsante che l'ha
            // generato, e non in cima alla pagina dove nessuno guarderebbe
            // dopo aver premuto "Entra".
            if (error != null) ...[
              const SizedBox(height: 16),
              _Notice(icon: Icons.error_outline, title: error!),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Il controllo su `loading` evita che un doppio tap parta
                // come due ingressi concorrenti sulla stessa lega. Se si è
                // già membri il pulsante non è più un vicolo cieco spento:
                // porta dentro la lega, che è l'unica cosa sensata da fare
                // da qui. `go` e non `push` perché la lega non è un
                // approfondimento di questa pagina: è la destinazione, e
                // tornare indietro all'invito non avrebbe senso.
                onPressed: loading
                    ? null
                    : (alreadyMember
                          ? () => context.go('/leagues/${league.slug}')
                          : onJoin),
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            alreadyMember ? Icons.arrow_forward : Icons.login,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              alreadyMember
                                  ? 'Vai alla lega'
                                  : 'Entra nella lega',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra della capienza: quanti membri su quanti massimi.
///
/// È il dato che risponde alla domanda pratica "faccio in tempo a entrare?", e
/// prima non c'era: la lega al completo era indistinguibile da una mezza
/// vuota, e l'utente lo scopriva solo dopo aver premuto "Entra" e aver preso
/// un errore. Riprende la forma già usata dalle card partita (barra sottile +
/// riga di riepilogo sotto), così si legge senza doverla imparare.
class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.league, required this.full});

  final LeagueSummary league;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final free = league.maxMembers - league.memberCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: league.maxMembers == 0
                ? 0
                // clamp: un conteggio momentaneamente superiore al massimo
                // (capienza abbassata a posteriori) darebbe un valore > 1, che
                // LinearProgressIndicator rifiuta.
                : (league.memberCount / league.maxMembers).clamp(0.0, 1.0),
            backgroundColor: AppTheme.surfaceHigh,
            // Grigia di proposito, benché il tema la colori di primario: il
            // verde in questa schermata è riservato al pulsante di ingresso.
            // Rosso solo quando è piena, perché lì il colore non è decorazione
            // ma l'informazione stessa.
            valueColor: AlwaysStoppedAnimation(
              full ? AppTheme.danger : AppTheme.muted,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          full
              ? 'Al completo · ${league.memberCount}/${league.maxMembers} membri'
              : '${league.memberCount}/${league.maxMembers} membri · '
                    '$free ${free == 1 ? 'posto libero' : 'posti liberi'}',
          style: TextStyle(
            color: full ? AppTheme.danger : AppTheme.mutedSoft,
            fontSize: 12,
            fontWeight: full ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Riquadro di avviso: un'icona, una riga forte e (facoltativo) una spiegazione.
///
/// Serve a rendere gli stati distinguibili fra loro invece di appiattirli tutti
/// sulla stessa riga di testo rosso: il colore di [accent] separa i problemi
/// (rosso) dalle constatazioni neutre come "sei già membro" (grigio), che un
/// rosso farebbe scambiare per un errore.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    this.body,
    this.accent = AppTheme.danger,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
