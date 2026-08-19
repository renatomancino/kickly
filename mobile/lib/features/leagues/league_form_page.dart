import 'dart:async';

import 'package:flutter/material.dart';
// `Uint8List` arriva già da qui: `dart:typed_data` diretto non serve più
// e l'analyzer lo segnala come import ridondante.
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/location/italian_location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Creazione di una lega.
///
/// Regola dell'accento seguita in tutta la pagina: il verde del marchio si
/// accende solo su **la scelta che hai fatto** (pillola formato, visibilità,
/// numero massimo di membri) e sul **bottone che la conferma**. Tutto il resto
/// — titolini di sezione, icone, segnaposto del logo — resta neutro. Prima il
/// verde compariva anche sul riquadro del logo e non risaltava più niente: se
/// tutto è acceso, l'occhio non ha più un punto dove atterrare.
class LeagueFormPage extends StatefulWidget {
  const LeagueFormPage({super.key});

  @override
  State<LeagueFormPage> createState() => _LeagueFormPageState();
}

class _LeagueFormPageState extends State<LeagueFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController(text: 'IT');
  // Non un TextEditingController: ItalianMunicipalityField gestisce il suo
  // campo internamente e riporta la selezione qui solo quando è un comune
  // reale con coordinate, mai testo libero — è quello che serve al gate di
  // distanza in join_public_league per avere un dato su cui calcolare.
  ItalianPlace? _place;
  String _format = '5v5';
  String _visibility = 'private';
  int _maxMembers = 20;
  bool _loading = false;
  String? _error;
  Uint8List? _logoBytes;
  String? _logoExtension;

  Future<void> _pickLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() => _error = 'Il logo deve pesare meno di 5 MB.');
      return;
    }
    setState(() {
      _logoBytes = bytes;
      _logoExtension = image.name.split('.').last;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _country.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // _place non è un TextFormField: il Form lo ignora, quindi senza questo
    // controllo esplicito il tap restava muto (nessun errore, nessun
    // caricamento) se non si sceglieva un comune dai suggerimenti. Stesso
    // problema e stessa soluzione già adottata in match_form_page.
    if (_place == null) {
      setState(
        () => _error =
            'Scegli la città dai suggerimenti: serve a chi è nelle '
            'vicinanze per trovare ed entrare nella lega.',
      );
      return;
    }
    // Riscontro tattile alla conferma di un form importante come la
    // creazione di una lega, non su ogni tap generico del modulo.
    // `unawaited`: è un effetto collaterale sul motore aptico, attenderlo
    // ritarderebbe l'invio del form senza alcun beneficio.
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final place = _place!;
      final slug = await AppScope.of(context).repository.createLeague(
        name: _name.text,
        slug: _slugify(_name.text),
        description: _description.text,
        city: place.city,
        country: _country.text,
        visibility: _visibility,
        footballFormat: _format,
        maxMembers: _maxMembers,
        province: place.province,
        latitude: place.latitude,
        longitude: place.longitude,
        logoBytes: _logoBytes,
        logoExtension: _logoExtension,
      );
      if (mounted) context.go('/leagues/$slug');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slugPreview = _slugify(_name.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova lega')),
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intestazione a tre livelli come in profile_editor_page:
                  // occhiello (dove sono), titolo (cosa sto per fare),
                  // sottotitolo (cosa succede dopo). Prima la pagina partiva
                  // dal titolo e la promessa "poi inviti i giocatori" era
                  // l'unica riga di contesto.
                  const _PageHeading(
                    eyebrow: 'NUOVA LEGA',
                    title: 'Crea il tuo campionato',
                    subtitle:
                        'Bastano nome, città e due regole di base: la lega è '
                        'attiva subito e potrai invitare i giocatori con un '
                        'codice appena finito.',
                  ),
                  const SizedBox(height: 22),

                  // Logo grande e centrato, come l'avatar della player card:
                  // è il ritratto della lega, non un'impostazione qualsiasi.
                  // Prima era una riga-elenco con la freccia a destra, che
                  // sembrava portare a un'altra schermata invece di aprire
                  // la galleria.
                  Center(
                    child: _LogoHero(bytes: _logoBytes, onTap: _pickLogo),
                  ),
                  const SizedBox(height: 10),
                  // "Facoltativo" in testa: la lega si crea benissimo senza
                  // logo, dirlo subito evita che sembri un passaggio obbligato.
                  const Center(
                    child: Text(
                      'Facoltativo · JPG, PNG o WebP, max 5 MB',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 1. Chi siete: i due campi che danno un'identità alla lega.
                  _FormSection(
                    eyebrow: 'Identità',
                    icon: Icons.shield_outlined,
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome della lega',
                          hintText: 'Es. Calcetto del giovedì',
                        ),
                        // Ricostruisce a ogni tasto solo per aggiornare
                        // l'anteprima dell'indirizzo qui sotto: è un campo
                        // corto, il costo è trascurabile e in cambio si vede
                        // in diretta il link che si sta generando.
                        onChanged: (_) => setState(() {}),
                        validator: (value) => (value?.trim().length ?? 0) >= 3
                            ? null
                            : 'Il nome deve avere almeno 3 caratteri.',
                      ),
                      // L'indirizzo della lega nasce dal nome (`_slugify`) e
                      // non è più modificabile dopo: mostrarlo mentre si
                      // scrive evita la sorpresa di trovarsi un link storto
                      // scoperto solo a lega creata.
                      if (slugPreview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _HelperLine(
                          icon: Icons.link,
                          text: 'Indirizzo: /leagues/$slugPreview',
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                          hintText: 'Opzionale: giorno fisso, livello, regole della casa',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Dove: serve a chi cerca partite vicine, quindi la
                  // conseguenza va detta invece di lasciare due campi muti.
                  _FormSection(
                    eyebrow: 'Dove giocate',
                    icon: Icons.location_on_outlined,
                    children: [
                      ItalianMunicipalityField(
                        initialCity: _place?.city,
                        initialProvince: _place?.province,
                        initialLatitude: _place?.latitude,
                        initialLongitude: _place?.longitude,
                        onSelected: (place) => setState(() => _place = place),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _country,
                        // Il campo vuole una sigla ISO: forzare le
                        // maiuscole dalla tastiera evita il "it" minuscolo
                        // che poi stona negli elenchi.
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Paese'),
                        validator: (value) => (value?.trim().length ?? 0) >= 2
                            ? null
                            : 'Sigla di 2 lettere.',
                      ),
                      const SizedBox(height: 10),
                      const _HelperLine(
                        icon: Icons.travel_explore_outlined,
                        text:
                            'La città con le coordinate esatte, scelta dai '
                            'suggerimenti, è quella che permette a chi è '
                            'nelle vicinanze di trovare la lega — se è '
                            'pubblica, anche di entrarci da solo.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Le regole: tutte scelte fra poche opzioni brevi, quindi
                  // pillole a vista invece di tre tendine. Una tendina nasconde
                  // le alternative dietro a un tap e non lascia confrontarle.
                  _FormSection(
                    eyebrow: 'Regole della lega',
                    icon: Icons.rule_outlined,
                    children: [
                      const _FieldLabel('Formato predefinito'),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in _formats)
                            _ChoicePill(
                              label: value.replaceAll('v', ' vs '),
                              selected: _format == value,
                              onTap: () => setState(() => _format = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const _HelperLine(
                        icon: Icons.info_outline,
                        text:
                            'È solo il valore proposto quando crei una partita: '
                            'ogni singolo match può usarne uno diverso.',
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Chi può entrare'),
                      const SizedBox(height: 9),
                      _VisibilityPicker(
                        value: _visibility,
                        onChanged: (value) =>
                            setState(() => _visibility = value),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Massimo membri'),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in _memberCaps)
                            _ChoicePill(
                              label: '$value',
                              selected: _maxMembers == value,
                              onTap: () => setState(() => _maxMembers = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const _HelperLine(
                        icon: Icons.info_outline,
                        text:
                            'Quante persone possono far parte della lega. '
                            'Raggiunto il tetto gli inviti smettono di '
                            'funzionare, ma puoi alzarlo quando vuoi dalle '
                            'impostazioni.',
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _FormErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      // Spinner piccolo e con colore esplicito invece di uno a
                      // dimensione piena: quello di default usa il verde del
                      // tema (ProgressIndicatorTheme), che su un bottone già
                      // verde risultava quasi invisibile.
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.onPrimary,
                              ),
                            )
                          : const Text('Crea lega'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formati ammessi, nello stesso ordine del form partita.
  static const _formats = ['5v5', '7v7', '8v8', '10v10', '11v11'];

  /// Tetti di membri proposti: gli stessi valori della vecchia tendina.
  static const _memberCaps = [10, 14, 20, 28, 40, 60];
}

// ---------------------------------------------------------------------------
// Pezzi di modulo condivisi con `league_settings_page.dart`.
//
// Sono duplicati lì invece di stare in `core/widgets/common.dart` perché in
// questa passata i file condivisi sono off-limits (ci lavorano altri in
// parallelo): meglio due copie private e nessun conflitto che un widget comune
// scritto a quattro mani. Se il linguaggio regge, il posto giusto dove
// unificarli è common.dart.
// ---------------------------------------------------------------------------

/// Intestazione della pagina: occhiello, titolo, sottotitolo.
class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 6),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: const TextStyle(color: AppTheme.muted, height: 1.45),
      ),
    ],
  );
}

/// Logo della lega in grande, con il badge fotocamera in basso a destra.
class _LogoHero extends StatelessWidget {
  const _LogoHero({required this.bytes, required this.onTap});

  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Raggio del tema, non un numero a caso: su un quadrato di 96 il radiusXl
    // dà lo stesso squircle di `LeagueLogo` (size * .28) usato negli elenchi,
    // così il logo qui e il logo lì hanno la stessa forma.
    final shape = BorderRadius.circular(AppTheme.radiusXl);
    return Semantics(
      button: true,
      label: bytes == null
          ? 'Aggiungi il logo della lega'
          : 'Sostituisci il logo della lega',
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: shape,
                border: Border.all(color: AppTheme.outlineSolid, width: 1.5),
                image: bytes == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(bytes!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: bytes == null
                  ? const Icon(
                      Icons.shield_outlined,
                      size: 34,
                      color: AppTheme.muted,
                    )
                  : null,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Badge neutro e non verde: il verde in questa pagina è
                  // riservato alle scelte e al bottone di conferma. Il bordo
                  // del colore dello sfondo lo stacca dal riquadro sotto,
                  // che è l'unica cosa che deve fare.
                  color: AppTheme.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.background, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: AppTheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blocco del modulo: un titolino con icona e un gruppo di campi dentro a una
/// card.
///
/// Prima il modulo era una colonna di campi tutti uguali uno sotto l'altro:
/// niente diceva cosa stava insieme a cosa, e per capire a che punto eri
/// dovevi leggere le etichette una per una.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.eyebrow,
    required this.icon,
    required this.children,
  });

  final String eyebrow;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icona e titolino in grigio: sono cartelli indicatori, non
                // contenuto. Accesi di verde (com'erano) facevano concorrenza
                // alle risposte dell'utente e al bottone finale.
                Icon(icon, size: 15, color: AppTheme.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Etichetta di un campo che non è un TextField, quindi non ha un labelText.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.muted,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Riga di aiuto sotto a un campo: dice la conseguenza della scelta.
///
/// Non è un `helperText` del TextField perché serve anche sotto ai selettori a
/// pillole, che un InputDecoration non ce l'hanno.
class _HelperLine extends StatelessWidget {
  const _HelperLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppTheme.mutedSoft),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.mutedSoft,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

/// Pillola selezionabile per le scelte fra poche opzioni brevi.
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material + InkWell invece di un GestureDetector su un Container: così il
    // tocco ha la sua onda, ritagliata sulla pillola dallo StadiumBorder, e i
    // lettori di schermo annunciano "selezionato" grazie a Semantics.
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.primary : AppTheme.surfaceHigh,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.onPrimary : AppTheme.foreground,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scelta della visibilità con le conseguenze scritte accanto.
///
/// In una tendina "Privata" e "Pubblica" sono due parole senza contesto: chi
/// crea la prima lega non ha modo di sapere che una lega pubblica finisce
/// nelle ricerche degli sconosciuti. Qui la conseguenza è scritta sotto ogni
/// opzione, prima di sceglierla.
class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    (
      'private',
      'Privata',
      'Si entra solo con il codice invito che generi tu',
      Icons.lock_outline,
    ),
    (
      'public',
      'Pubblica',
      'Chi è nel raggio di 50 km dalla città della lega può entrare da solo',
      Icons.public,
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final option in _options) ...[
        if (option != _options.first) const SizedBox(height: 9),
        _RadioOption(
          title: option.$2,
          description: option.$3,
          icon: option.$4,
          selected: value == option.$1,
          onTap: () => onChanged(option.$1),
        ),
      ],
    ],
  );
}

/// Opzione a scelta singola: icona, titolo, conseguenza, pallino a destra.
class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      side: BorderSide(
        color: selected
            ? AppTheme.primary.withValues(alpha: .55)
            : AppTheme.outline,
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: .1)
            : AppTheme.surfaceHigh,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? AppTheme.primary : AppTheme.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: selected ? AppTheme.primary : AppTheme.outlineSolid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Errore di invio del modulo, in un riquadro rosso appena sopra al bottone.
///
/// Prima era una riga di testo rosso persa fra i campi: un errore che arriva
/// dal server dopo il tap va messo dove l'occhio sta già guardando, cioè
/// attaccato al bottone che si è appena premuto.
class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.danger.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.danger.withValues(alpha: .4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppTheme.danger, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
