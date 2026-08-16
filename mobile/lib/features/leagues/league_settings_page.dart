import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Impostazioni di una lega (solo owner e admin).
///
/// Stessa regola dell'accento del form di creazione: il verde si accende sulla
/// scelta fatta (formato, visibilità, tetto membri) e sul bottone che salva.
/// L'eliminazione, che è l'altra azione forte della pagina, non compete con il
/// verde: vive in una zona rossa tutta sua in fondo, staccata dal salvataggio.
class LeagueSettingsPage extends StatefulWidget {
  const LeagueSettingsPage({super.key, required this.slug});
  final String slug;
  @override
  State<LeagueSettingsPage> createState() => _LeagueSettingsPageState();
}

class _LeagueSettingsPageState extends State<LeagueSettingsPage> {
  Future<LeagueDetail?>? future;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(),
      description = TextEditingController(),
      city = TextEditingController(),
      country = TextEditingController();
  String format = '5v5', visibility = 'private';
  int maxMembers = 20;
  bool initialized = false, saving = false;
  Uint8List? logoBytes;
  String? logoExtension;

  /// Formati e tetti di membri: stessi valori e stesso ordine del form di
  /// creazione, così un admin ritrova le opzioni dove le aveva lasciate.
  static const _formats = ['5v5', '7v7', '8v8', '10v10', '11v11'];
  static const _memberCaps = [10, 14, 20, 28, 40, 60];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).repository.getLeague(widget.slug);
  }

  void init(LeagueDetail league) {
    if (initialized) return;
    final s = league.summary;
    name.text = s.name;
    description.text = s.description ?? '';
    city.text = s.city;
    country.text = s.country;
    format = s.footballFormat;
    visibility = s.visibility;
    maxMembers = s.maxMembers;
    initialized = true;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    city.dispose();
    country.dispose();
    super.dispose();
  }

  Future<void> save(LeagueDetail league) async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await AppScope.of(context).repository.updateLeague(
        id: league.summary.id,
        name: name.text,
        description: description.text,
        city: city.text,
        country: country.text,
        visibility: visibility,
        footballFormat: format,
        maxMembers: maxMembers,
        logoBytes: logoBytes,
        logoExtension: logoExtension,
      );
      if (mounted) context.go('/leagues/${widget.slug}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete(LeagueDetail league) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _DeleteLeagueDialog(expectedName: league.summary.name),
    );
    if (accepted != true || !mounted) return;
    // Stesso flag `saving` di save(): eliminare o salvare non possono mai
    // essere in corso insieme, quindi condividerlo disabilita anche
    // "Salva modifiche" mentre la cancellazione è in volo, invece di
    // lasciare due azioni concorrenti sulla stessa lega.
    setState(() => saving = true);
    try {
      await AppScope.of(context).repository.deleteLeague(league.summary.id);
      if (mounted) context.go('/leagues');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Impostazioni lega')),
    body: FutureBuilder<LeagueDetail?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListSkeleton(items: 2);
        }
        // Prima il ramo errore, poi "accesso negato": senza questo, un
        // fallimento di rete cadeva nello stesso `league == null` di un
        // admin senza permessi, mostrando "Accesso negato" a un owner
        // legittimo semplicemente perché la richiesta non era arrivata.
        if (snapshot.hasError) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Impostazioni non disponibili',
              body: friendlyError(snapshot.error ?? 'Errore'),
              action: FilledButton(
                onPressed: () => setState(
                  () =>
                      future = AppScope.of(context).repository
                          .getLeague(widget.slug),
                ),
                child: const Text('Riprova'),
              ),
            ),
          );
        }
        final league = snapshot.data;
        if (league == null || !league.summary.canManage) {
          return PageFrame(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Accesso negato',
              body:
                  'Le impostazioni sono riservate a chi gestisce la lega. '
                  'Puoi comunque vedere calendario, classifica e membri dalla '
                  'pagina della lega.',
              // Uno stato vuoto senza uscita è un vicolo cieco: da qui il
              // gesto naturale è tornare alla lega, non premere "indietro"
              // finché non succede qualcosa.
              action: OutlinedButton.icon(
                onPressed: () => context.go('/leagues/${widget.slug}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Torna alla lega'),
              ),
            ),
          );
        }
        init(league);
        final summary = league.summary;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Occhiello + titolo + sottotitolo: il titolo contiene il nome
            // della lega, che è testo scritto dagli utenti, quindi va
            // troncato invece di sfondare l'intestazione.
            const Text(
              'IMPOSTAZIONI LEGA',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gestisci ${summary.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            const Text(
              'Le modifiche valgono subito per tutti i membri, anche nella PWA.',
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            Form(
              key: formKey,
              child: Column(
                children: [
                  // Logo grande e centrato come nella creazione. Novità: se la
                  // lega ha già un logo adesso si vede — prima il riquadro
                  // mostrava il segnaposto vuoto finché non ne sceglievi uno
                  // nuovo, e sembrava che il logo fosse sparito.
                  Center(
                    child: _LogoHero(
                      bytes: logoBytes,
                      current: summary,
                      onTap: pickLogo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    logoBytes == null
                        ? 'Tocca per cambiare logo · max 5 MB'
                        : 'Nuovo logo pronto: salva per applicarlo',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 1. Identità della lega.
                  _FormSection(
                    eyebrow: 'Identità',
                    icon: Icons.shield_outlined,
                    children: [
                      TextFormField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome della lega',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) >= 3
                            ? null
                            : 'Il nome deve avere almeno 3 caratteri.',
                      ),
                      const SizedBox(height: 8),
                      // L'indirizzo nasce dal nome alla creazione e non
                      // cambia più: dirlo qui evita che un admin rinomini la
                      // lega aspettandosi che cambi anche il link condiviso.
                      _HelperLine(
                        icon: Icons.link,
                        text:
                            'L\'indirizzo /leagues/${widget.slug} resta questo '
                            'anche se cambi nome: i link già condivisi '
                            'continuano a funzionare.',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: description,
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

                  // 2. Dove si gioca.
                  _FormSection(
                    eyebrow: 'Dove giocate',
                    icon: Icons.location_on_outlined,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: city,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Città',
                              ),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) >= 2
                                  ? null
                                  : 'Indica la città.',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: country,
                              decoration: const InputDecoration(
                                labelText: 'Paese',
                              ),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) >= 2
                                  ? null
                                  : 'Campo obbligatorio.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _HelperLine(
                        icon: Icons.travel_explore_outlined,
                        text:
                            'È la zona con cui la lega compare a chi cerca '
                            'partite vicine.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Le regole: scelte fra poche opzioni brevi, quindi
                  // pillole a vista invece di tendine. Qui conta ancora di
                  // più che in creazione: da amministratore vuoi vedere com'è
                  // impostata la lega senza dover aprire tre menu.
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
                              selected: format == value,
                              onTap: () => setState(() => format = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const _HelperLine(
                        icon: Icons.info_outline,
                        text:
                            'Vale per le prossime partite: quelle già in '
                            'calendario mantengono il formato con cui sono '
                            'state create.',
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Chi può entrare'),
                      const SizedBox(height: 9),
                      _VisibilityPicker(
                        value: visibility,
                        onChanged: (value) =>
                            setState(() => visibility = value),
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
                              selected: maxMembers == value,
                              onTap: () => setState(() => maxMembers = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      // Il conteggio attuale accanto al tetto: senza, un admin
                      // sceglie un numero al buio e scopre solo al salvataggio
                      // che è sotto ai membri già dentro.
                      _HelperLine(
                        icon: Icons.groups_outlined,
                        text:
                            'Oggi la lega ha ${summary.memberCountLabel}. '
                            'Sotto questo numero gli inviti smettono di '
                            'funzionare, ma nessuno viene mai espulso.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving ? null : () => save(league),
                      // Spinner esplicito: prima il bottone si limitava a
                      // spegnersi durante il salvataggio, e su una rete lenta
                      // non si capiva se il tap fosse stato registrato.
                      // Colore onPrimary perché quello di default è il verde
                      // del tema, invisibile su un bottone già verde.
                      child: saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.onPrimary,
                              ),
                            )
                          : const Text('Salva modifiche'),
                    ),
                  ),
                ],
              ),
            ),
            // L'eliminazione è definitiva e la può fare solo il proprietario:
            // sta in una card rossa staccata, con l'aria di un'altra zona
            // della pagina. Prima era un bottone in fila subito sotto a
            // "Salva modifiche", cioè a un pollice di distanza dall'azione
            // che si preme di solito.
            if (summary.currentUserRole == 'owner') ...[
              const SizedBox(height: 28),
              _DangerZone(
                onDelete: saving ? null : () => delete(league),
                memberCountLabel: summary.memberCountLabel,
              ),
            ],
          ],
        );
      },
    ),
  );

  Future<void> pickLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il logo deve pesare meno di 5 MB.')),
      );
      return;
    }
    setState(() {
      logoBytes = bytes;
      logoExtension = image.name.split('.').last;
    });
  }
}

// ---------------------------------------------------------------------------
// Pezzi di modulo condivisi con `league_form_page.dart`.
//
// Sono duplicati lì invece di stare in `core/widgets/common.dart` perché in
// questa passata i file condivisi sono off-limits (ci lavorano altri in
// parallelo): meglio due copie private e nessun conflitto che un widget comune
// scritto a quattro mani. Se il linguaggio regge, il posto giusto dove
// unificarli è common.dart.
// ---------------------------------------------------------------------------

/// Logo della lega in grande, con il badge fotocamera in basso a destra.
class _LogoHero extends StatelessWidget {
  const _LogoHero({
    required this.bytes,
    required this.current,
    required this.onTap,
  });

  /// Logo appena scelto dalla galleria, non ancora salvato.
  final Uint8List? bytes;

  /// Lega da cui prendere il logo attuale, quando non ce n'è uno nuovo.
  final LeagueSummary current;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `LeagueLogo` usa un raggio pari a size * .28: su 96 px fa 26.9, cioè
    // radiusXl a meno di un pixel. Usare il token per il riquadro del logo
    // appena scelto evita che i due stati abbiano due forme diverse.
    final shape = BorderRadius.circular(AppTheme.radiusXl);
    return Semantics(
      button: true,
      label: 'Cambia il logo della lega',
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (bytes == null)
              LeagueLogo(league: current, size: 96)
            else
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: AppTheme.outlineSolid, width: 1.5),
                  image: DecorationImage(
                    image: MemoryImage(bytes!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Badge neutro e non verde: il verde qui è riservato alle
                  // scelte e al bottone che salva.
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
                // contenuto, e non devono competere con le scelte accese.
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
      'Compare nelle ricerche: chiunque può chiedere di entrare',
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

/// Zona rossa in fondo alla pagina, con la sola azione irreversibile.
///
/// Non è un bottone in più nella pila delle impostazioni: card a sé, bordo
/// rosso e testo che dice cosa si perde. Serve proprio a rompere il ritmo
/// della pagina, così l'eliminazione non si preme per inerzia dopo aver
/// salvato.
class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete, required this.memberCountLabel});

  final VoidCallback? onDelete;
  final String memberCountLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.danger.withValues(alpha: .07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppTheme.danger.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 15,
                  color: AppTheme.danger,
                ),
                const SizedBox(width: 8),
                Text(
                  'ZONA PERICOLOSA',
                  style: TextStyle(
                    color: AppTheme.danger.withValues(alpha: .9),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Eliminando la lega spariscono anche partite, formazioni e '
              'statistiche di $memberCountLabel. Non si torna indietro.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(
                    color: AppTheme.danger.withValues(alpha: .5),
                  ),
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina lega'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget dedicato (non un TextEditingController locale distrutto subito
// dopo l'await di showDialog) cosi il controller vive quanto l'Element del
// dialog: evita il crash "TextEditingController was used after being
// disposed" che puo' scattare durante l'animazione di chiusura.
class _DeleteLeagueDialog extends StatefulWidget {
  const _DeleteLeagueDialog({required this.expectedName});
  final String expectedName;
  @override
  State<_DeleteLeagueDialog> createState() => _DeleteLeagueDialogState();
}

class _DeleteLeagueDialogState extends State<_DeleteLeagueDialog> {
  final _confirmation = TextEditingController();

  /// Vero solo quando il nome digitato combacia.
  ///
  /// Prima il bottone "Elimina" era sempre attivo e, con il nome sbagliato,
  /// chiudeva il dialogo senza fare niente e senza dire perché: sembrava che
  /// l'eliminazione fosse fallita in silenzio. Ora la conferma è visibilmente
  /// spenta finché non hai scritto il nome giusto.
  bool get _matches => _confirmation.text.trim() == widget.expectedName.trim();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.warning_amber_outlined, color: AppTheme.danger),
    title: const Text('Eliminare la lega?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Partite, formazioni e statistiche vengono cancellate insieme alla '
          'lega e non sono recuperabili.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 14),
        Text(
          // Nome scritto dagli utenti: su due righe al massimo, altrimenti
          // una lega dal nome lunghissimo allunga il dialogo a dismisura.
          'Per confermare, digita “${widget.expectedName}”.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmation,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.expectedName,
            // Spunta verde appena il nome combacia: è il solo momento in cui
            // il verde compare in questo dialogo, e dice "ora puoi".
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
