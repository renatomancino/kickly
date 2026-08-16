import 'dart:async';

import 'package:flutter/material.dart';
// `Uint8List` arriva già da qui: `dart:typed_data` diretto non serve più
// e l'analyzer lo segnala come import ridondante.
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/location/italian_location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

/// Creazione e modifica di una partita.
///
/// Regola dell'accento seguita in tutta la pagina: il verde del marchio si
/// accende solo su **la scelta che hai fatto** (formato, visibilità) e sul
/// **bottone che pubblica**. Prima era acceso anche su tutti e sei i titolini
/// di sezione, sul riquadro della data, sulla quota a persona e sulle due
/// caselle foto: con dieci punti verdi in una schermata sola non risaltava più
/// niente, e il bottone che chiude il lavoro spariva in mezzo agli altri.
/// Dove serviva enfasi senza colore si usa il corpo del testo (l'ora della
/// partita è la cosa più grande della pagina, non la più verde).
class MatchFormPage extends StatefulWidget {
  const MatchFormPage({super.key, this.initialLeagueId, this.matchId});

  final String? initialLeagueId;
  final String? matchId;

  @override
  State<MatchFormPage> createState() => _MatchFormPageState();
}

class _MatchFormPageState extends State<MatchFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController(text: 'Partita settimanale');
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  final _cost = TextEditingController();
  final _venuePhone = TextEditingController();
  final _locationService = const ItalianLocationService();
  ItalianPlace? _place;
  Uint8List? _coverBytes;
  String? _coverExtension;
  Uint8List? _venueBytes;
  String? _venueExtension;
  Future<List<LeagueSummary>>? _leaguesFuture;
  String? _leagueId;
  String _format = '5v5';
  String _visibility = 'league_only';
  int _maxPlayers = 10;
  DateTime _startsAt = DateTime.now().add(const Duration(days: 2, hours: 2));
  bool _loading = false;
  bool _initialized = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leaguesFuture ??= _load();
  }

  Future<List<LeagueSummary>> _load() async {
    final repository = AppScope.of(context).repository;
    final leagues = await repository.getLeagues();
    if (widget.matchId != null && !_initialized) {
      final match = await repository.getMatch(widget.matchId!);
      if (match != null) {
        _leagueId = match.summary.leagueId;
        _title.text = match.summary.title;
        _description.text = match.description ?? '';
        _location.text = match.summary.locationName;
        _address.text = match.address ?? '';
        if (match.summary.province != null &&
            match.latitude != null &&
            match.longitude != null) {
          _place = ItalianPlace(
            city: match.summary.city,
            province: match.summary.province!,
            latitude: match.latitude!,
            longitude: match.longitude!,
            displayName:
                '${match.summary.city}, ${match.summary.province}, Italia',
          );
        }
        _cost.text = match.costTotal?.toString() ?? '';
        _venuePhone.text = match.venuePhone ?? '';
        _format = match.summary.footballFormat;
        _visibility = match.summary.visibility;
        _maxPlayers = match.summary.maxPlayers;
        _startsAt = match.summary.startsAt;
      }
    }
    _initialized = true;
    return leagues;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _address.dispose();
    _cost.dispose();
    _venuePhone.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: _startsAt.isBefore(now)
          ? _startsAt.subtract(const Duration(days: 1))
          : now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Comune e lega non sono TextFormField, quindi il Form non li valida e
    // prima il tap sul bottone finiva in un `return` muto: nessun errore,
    // nessun caricamento, apparentemente nulla di rotto. Stesso blocco di
    // prima, ma adesso dice cosa manca nel riquadro sopra al bottone.
    if (_place == null || _leagueId == null) {
      setState(
        () => _error = _place == null
            ? 'Scegli il comune del campo: serve per mostrare la partita a chi è in zona.'
            : 'Scegli la lega in cui creare la partita.',
      );
      return;
    }
    // Piccolo riscontro tattile alla conferma di un form importante come
    // questo (crea o modifica una partita), non su ogni tap generico.
    // `unawaited`: è un effetto collaterale sul motore aptico, attenderlo
    // ritarderebbe geocoding e salvataggio senza alcun beneficio.
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = AppScope.of(context).repository;
      final venuePlace =
          await _locationService.geocodeVenue(
            address: _address.text,
            municipality: _place!,
          ) ??
          _place!;
      String matchId;
      if (widget.matchId != null) {
        await repository.updateMatch(
          matchId: widget.matchId!,
          title: _title.text,
          description: _description.text,
          startsAt: _startsAt,
          locationName: _location.text,
          address: _address.text,
          city: _place!.city,
          province: _place!.province,
          latitude: venuePlace.latitude,
          longitude: venuePlace.longitude,
          venuePhone: _venuePhone.text,
          footballFormat: _format,
          maxPlayers: _maxPlayers,
          costTotal: double.tryParse(_cost.text.replaceAll(',', '.')),
          visibility: _visibility,
        );
        matchId = widget.matchId!;
      } else {
        matchId = await repository.createMatch(
          leagueId: _leagueId!,
          title: _title.text,
          description: _description.text,
          startsAt: _startsAt,
          locationName: _location.text,
          address: _address.text,
          city: _place!.city,
          province: _place!.province,
          latitude: venuePlace.latitude,
          longitude: venuePlace.longitude,
          venuePhone: _venuePhone.text,
          footballFormat: _format,
          maxPlayers: _maxPlayers,
          costTotal: double.tryParse(_cost.text.replaceAll(',', '.')),
          visibility: _visibility,
        );
      }
      final coverUrl = _coverBytes == null
          ? null
          : await repository.uploadMatchImage(
              matchId: matchId,
              bytes: _coverBytes!,
              extension: _coverExtension!,
              kind: 'cover',
            );
      final venueUrl = _venueBytes == null
          ? null
          : await repository.uploadMatchImage(
              matchId: matchId,
              bytes: _venueBytes!,
              extension: _venueExtension!,
              kind: 'venue',
            );
      if (coverUrl != null || venueUrl != null) {
        await repository.setMatchMedia(
          matchId,
          coverImageUrl: coverUrl,
          venueImageUrl: venueUrl,
        );
      }
      if (mounted) context.go('/matches/$matchId');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFormat(String value) {
    const size = {'5v5': 10, '7v7': 14, '8v8': 16, '10v10': 20, '11v11': 22};
    setState(() {
      _format = value;
      _maxPlayers = size[value] ?? 10;
    });
  }

  Future<void> _pickImage({required bool venue}) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 86,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La foto deve pesare meno di 8 MB.')),
      );
      return;
    }
    final extension = image.name.split('.').last;
    setState(() {
      if (venue) {
        _venueBytes = bytes;
        _venueExtension = extension;
      } else {
        _coverBytes = bytes;
        _coverExtension = extension;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.matchId == null ? 'Nuova partita' : 'Modifica partita',
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<LeagueSummary>>(
          future: _leaguesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ListSkeleton(items: 3);
            }
            if (snapshot.hasError) {
              return PageFrame(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Dati non disponibili',
                  body: friendlyError(snapshot.error!),
                ),
              );
            }
            final managed = (snapshot.data ?? const [])
                .where((league) => league.canManage)
                .toList();
            if (managed.isEmpty) {
              // Stato vuoto con una via d'uscita: dire soltanto "serve una
              // lega" lascia l'utente in un vicolo cieco, mentre da qui il
              // passo successivo è sempre lo stesso — crearne una.
              return PageFrame(
                child: EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Prima serve una lega',
                  body:
                      'Le partite si organizzano dentro una lega, e puoi farlo '
                      'solo dove sei proprietario o admin. Creane una: ci '
                      'vuole un minuto e gli inviti partono subito.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/leagues/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crea una lega'),
                  ),
                ),
              );
            }
            _leagueId ??=
                managed.any((league) => league.id == widget.initialLeagueId)
                ? widget.initialLeagueId
                : managed.first.id;
            final selectedLeague = managed
                .where((league) => league.id == _leagueId)
                .first;
            if (_format == '5v5' && selectedLeague.footballFormat != '5v5') {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _setFormat(selectedLeague.footballFormat),
              );
            }
            return PageFrame(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Occhiello + titolo + sottotitolo, come negli altri
                      // moduli dell'app: l'occhiello dice dove sei, il titolo
                      // cosa stai per fare, il sottotitolo cosa succede dopo
                      // aver confermato.
                      Text(
                        widget.matchId == null
                            ? 'NUOVA PARTITA'
                            : 'MODIFICA PARTITA',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.matchId == null
                            ? 'Organizza il match'
                            : 'Aggiorna il match',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.matchId == null
                            ? 'Data, campo e formato: appena pubblichi, i membri '
                                  'della lega la vedono e possono dare la '
                                  'disponibilità.'
                            : 'Le modifiche arrivano subito a chi si è già '
                                  'iscritto, in app e nella PWA.',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 1. Di cosa si tratta.
                      _FormSection(
                        eyebrow: 'La partita',
                        icon: Icons.sports_soccer,
                        children: [
                          // La tendina lega compare solo se c'e davvero una
                          // scelta da fare: con una lega sola era un campo
                          // inerte in cima al modulo. Al suo posto però resta
                          // scritto dove finirà la partita, altrimenti con
                          // più leghe in giro non si sa in quale si sta
                          // pubblicando.
                          if (managed.length > 1) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _leagueId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Lega',
                                prefixIcon: const Icon(Icons.shield_outlined),
                                // In modifica la tendina è spenta di
                                // proposito (una partita non trasloca da una
                                // lega all'altra): senza una riga che lo
                                // dica, sembra solo un campo rotto.
                                helperText: widget.matchId == null ? null : 'Una partita non si può spostare in un\'altra lega.',
                              ),
                              items: managed
                                  .map(
                                    (league) => DropdownMenuItem(
                                      value: league.id,
                                      child: Text(
                                        league.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: widget.matchId == null
                                  ? (value) => setState(() => _leagueId = value)
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            _HelperLine(
                              icon: Icons.shield_outlined,
                              text: 'Nella lega ${selectedLeague.name}',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _title,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Titolo',
                              hintText: 'Es. Partita del giovedì',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _description,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Descrizione',
                              hintText: 'Opzionale: ritrovo, spogliatoi, note',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. Quando: la data merita piu peso di una riga di
                      // testo, e il primo dato che un giocatore cerca. Il peso
                      // però glielo dà il corpo del testo (l'ora è la cosa più
                      // grande della pagina), non il colore: il riquadro era
                      // verde su verde e si prendeva l'accento che serve al
                      // bottone di pubblicazione.
                      _FormSection(
                        eyebrow: 'Quando',
                        icon: Icons.event,
                        children: [
                          Material(
                            color: AppTheme.surfaceHigh,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              side: const BorderSide(color: AppTheme.outline),
                            ),
                            child: InkWell(
                              onTap: _pickDateTime,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'EEEE d MMMM y',
                                              'it_IT',
                                            ).format(_startsAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            DateFormat('HH:mm')
                                                .format(_startsAt),
                                            style: const TextStyle(
                                              fontSize: 26,
                                              height: 1.1,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Il riquadro è tutto cliccabile, ma
                                    // l'icona resta l'unico segnale esplicito
                                    // che di qui si apre il calendario.
                                    const Icon(
                                      Icons.edit_calendar_outlined,
                                      color: AppTheme.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          // Avviso solo quando serve davvero: capita in
                          // modifica, riaprendo una partita già giocata, e
                          // salvare senza accorgersene la rimetterebbe in
                          // calendario con una data nel passato.
                          if (_startsAt.isBefore(DateTime.now()))
                            const _HelperLine(
                              icon: Icons.history,
                              text:
                                  'Questa data è già passata: la partita non '
                                  'comparirà fra quelle in programma.',
                            )
                          else
                            const _HelperLine(
                              icon: Icons.touch_app_outlined,
                              text: 'Tocca per cambiare giorno e orario.',
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Dove.
                      _FormSection(
                        eyebrow: 'Dove si gioca',
                        icon: Icons.location_on_outlined,
                        children: [
                          TextFormField(
                            controller: _location,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Campo / centro sportivo',
                              prefixIcon: Icon(Icons.stadium_outlined),
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _address,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Indirizzo completo del campo',
                              prefixIcon: Icon(Icons.signpost_outlined),
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 14),
                          ItalianMunicipalityField(
                            key: ValueKey(
                              '${_place?.city}|${_place?.province}|${widget.matchId}',
                            ),
                            initialCity: _place?.city,
                            initialProvince: _place?.province,
                            initialLatitude: _place?.latitude,
                            initialLongitude: _place?.longitude,
                            onSelected: (place) => _place = place,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _venuePhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefono della struttura',
                              // Il campo è obbligatorio (lo dice il
                              // validatore): meglio scriverlo prima, invece
                              // di far scoprire il vincolo con un errore
                              // rosso dopo il tap su "Pubblica".
                              helperText:
                                  'Obbligatorio: serve ai partecipanti per '
                                  'confermare o disdire il campo.',
                              // Due righe di aiuto stanno larghe quanto il
                              // campo invece di essere troncate a una sola.
                              helperMaxLines: 2,
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) {
                                return 'Numero del campo obbligatorio.';
                              }
                              return RegExp(r'^[0-9+() .-]{6,30}$')
                                      .hasMatch(phone)
                                  ? null
                                  : 'Numero non valido.';
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Come si gioca: il formato come scelta a vista
                      // invece che dentro a una tendina, sono cinque opzioni
                      // e ci stanno tutte.
                      _FormSection(
                        eyebrow: 'Come si gioca',
                        icon: Icons.groups_outlined,
                        children: [
                          const _FieldLabel('Formato'),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in _formats)
                                _ChoicePill(
                                  label: value.replaceAll('v', ' vs '),
                                  selected: _format == value,
                                  onTap: () => _setFormat(value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          // Cambiare formato riscrive i giocatori totali qui
                          // sotto (`_setFormat`): è un effetto collaterale
                          // che sorprende chi aveva appena messo il suo
                          // numero, quindi va annunciato prima.
                          const _HelperLine(
                            icon: Icons.info_outline,
                            text:
                                'Scegliendo il formato ricalcoliamo i giocatori '
                                'totali qui sotto: se ti serve un altro numero, '
                                'correggilo dopo.',
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            initialValue: '$_maxPlayers',
                            key: ValueKey(_maxPlayers),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giocatori totali',
                              helperText:
                                  'Raggiunto questo numero le adesioni finiscono '
                                  'in lista d\'attesa.',
                              helperMaxLines: 2,
                              prefixIcon: Icon(Icons.person_add_alt_outlined),
                            ),
                            onChanged: (value) => setState(
                              () => _maxPlayers =
                                  int.tryParse(value) ?? _maxPlayers,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _FieldLabel('Chi la può vedere'),
                          const SizedBox(height: 9),
                          _VisibilityPicker(
                            value: _visibility,
                            onChanged: (value) =>
                                setState(() => _visibility = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Soldi.
                      _FormSection(
                        eyebrow: 'Quanto costa',
                        icon: Icons.payments_outlined,
                        children: [
                          TextFormField(
                            controller: _cost,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Costo totale del campo',
                              hintText: 'Opzionale',
                              helperText:
                                  'Lascialo vuoto se il campo è già pagato: '
                                  'nessuno vedrà una quota da versare.',
                              helperMaxLines: 2,
                              prefixText: '€ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_quotaPerPlayer != null) ...[
                            const SizedBox(height: 12),
                            // Riquadro neutro, non verde: è un calcolo fatto
                            // da noi, non una scelta dell'utente né l'azione
                            // finale. Il numero risalta perché è grosso e
                            // bianco su grigio, senza rubare l'accento.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHigh,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                border: Border.all(color: AppTheme.outline),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.pie_chart_outline,
                                    size: 18,
                                    color: AppTheme.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                '€ ${_quotaPerPlayer!.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' a testa, dividendo su $_maxPlayers giocatori',
                                            style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 6. Immagini.
                      _FormSection(
                        eyebrow: 'Foto',
                        icon: Icons.photo_library_outlined,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _MediaPicker(
                                  label: 'Copertina',
                                  bytes: _coverBytes,
                                  icon: Icons.photo_camera_back_outlined,
                                  onTap: () => _pickImage(venue: false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MediaPicker(
                                  label: 'Foto campo',
                                  bytes: _venueBytes,
                                  icon: Icons.stadium_outlined,
                                  onTap: () => _pickImage(venue: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Le due caselle sembrano uguali ma finiscono in due
                          // posti diversi: senza questa riga si carica la foto
                          // del campo aspettandosi di vederla nell'elenco.
                          const _HelperLine(
                            icon: Icons.info_outline,
                            text:
                                'Facoltative. La copertina è l\'immagine grande '
                                'nell\'elenco partite, la foto campo aiuta a '
                                'riconoscere la struttura all\'arrivo.',
                          ),
                        ],
                      ),

                      // L'errore sta appena sopra al bottone, cioè dove
                      // l'occhio è già puntato dopo il tap che l'ha causato.
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _FormErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  // Colore esplicito: lo spinner di default
                                  // prende il verde del tema
                                  // (ProgressIndicatorTheme) e su un bottone
                                  // già verde era quasi invisibile.
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  widget.matchId == null
                                      ? Icons.rocket_launch_outlined
                                      : Icons.save_outlined,
                                ),
                          // L'etichetta cambia durante l'attesa: "Pubblica
                          // partita" mentre la richiesta è in volo lascia il
                          // dubbio di non aver premuto davvero.
                          label: Text(
                            _loading
                                ? 'Un attimo…'
                                : widget.matchId == null
                                ? 'Pubblica partita'
                                : 'Salva modifiche',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Quota a testa, o null se il costo non è un numero valido.
  ///
  /// Accetta sia la virgola sia il punto come separatore decimale, perché su
  /// tastiera italiana viene naturale scrivere "110,50".
  double? get _quotaPerPlayer {
    final total = double.tryParse(_cost.text.replaceAll(',', '.'));
    if (total == null || _maxPlayers <= 0) return null;
    return total / _maxPlayers;
  }

  static String? _required(String? value) =>
      (value?.trim().length ?? 0) >= 2 ? null : 'Campo obbligatorio.';

  /// Formati ammessi, negli stessi valori e ordine dei form di lega.
  static const _formats = ['5v5', '7v7', '8v8', '10v10', '11v11'];
}

class _MediaPicker extends StatelessWidget {
  const _MediaPicker({
    required this.label,
    required this.bytes,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Uint8List? bytes;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Raggio del design system al posto del 16 scritto a mano: la casella
    // foto è grande quanto una card, quindi prende lo stesso radiusLg.
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    final chosen = bytes != null;
    return Semantics(
      button: true,
      label: chosen ? 'Sostituisci $label' : 'Aggiungi $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppTheme.outline),
            image: chosen
                ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
                : null,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              // Token del tema invece degli esadecimali scritti a mano: erano
              // uno il duplicato quasi esatto di AppTheme.surface, l'altro
              // proprio il valore di AppTheme.primary copiato a mano. Sopra
              // alla foto serve un velo scuro perché il testo resti leggibile
              // anche su un'immagine chiara: è il nero dello sfondo dell'app,
              // non un `Colors.black` fuori palette.
              color: chosen
                  ? AppTheme.background.withValues(alpha: .55)
                  : AppTheme.surface,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icona neutra: queste due caselle sono facoltative e non
                // devono accendersi come se fossero il passo importante.
                // Piena invece che outline quando la foto c'è già, come da
                // regola generale attivo/inattivo.
                Icon(
                  chosen ? Icons.check_circle : icon,
                  color: chosen ? AppTheme.foreground : AppTheme.muted,
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  chosen ? 'Cambia' : 'Aggiungi',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocco del modulo: un titolino con icona e un gruppo di campi dentro a una
/// card.
///
/// Prima il modulo era una colonna di dodici campi identici uno sotto l'altro:
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
                // contenuto. Accesi di verde su sei sezioni facevano a gara
                // fra loro, con le risposte dell'utente e con il bottone.
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

/// Etichetta di un campo che non e un TextField, quindi non ha un labelText.
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
/// pillole e al riquadro della data, che un InputDecoration non ce l'hanno.
class _HelperLine extends StatelessWidget {
  const _HelperLine({required this.icon, required this.text, this.maxLines});

  final IconData icon;
  final String text;

  /// Da valorizzare quando il testo contiene roba scritta dagli utenti (il
  /// nome di una lega): lì un valore lunghissimo va troncato, mentre le
  /// spiegazioni che scriviamo noi possono andare a capo quanto serve.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppTheme.mutedSoft),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
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

/// Pillola selezionabile, usata per il formato della partita.
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
    // lettori di schermo annunciano "selezionato" grazie a Semantics. Il fade
    // di 150 ms dell'AnimatedContainer si perde, ma era un ritorno molto più
    // debole dell'onda che ora parte da sotto il dito.
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

/// Errore di invio del modulo, in un riquadro rosso appena sopra al bottone.
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
            style: const TextStyle(
              color: AppTheme.danger,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Scelta della visibilita con le conseguenze scritte accanto.
///
/// In una tendina "Solo lega" e "Pubblica" sono due parole senza contesto: qui
/// si vede subito chi finira per vedere la partita.
class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    (
      'league_only',
      'Solo lega',
      'La vedono e possono iscriversi solo i membri della lega',
      Icons.shield_outlined,
    ),
    (
      'public',
      'Pubblica',
      'Compare anche ai giocatori della zona che non sono in lega',
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
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: .1)
            : AppTheme.surfaceHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(
            color: selected
                ? AppTheme.primary.withValues(alpha: .55)
                : AppTheme.outline,
          ),
        ),
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
