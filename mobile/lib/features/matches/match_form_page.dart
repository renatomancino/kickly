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
    if (!_formKey.currentState!.validate() ||
        _leagueId == null ||
        _place == null) {
      return;
    }
    // Piccolo riscontro tattile alla conferma di un form importante come
    // questo (crea o modifica una partita), non su ogni tap generico.
    HapticFeedback.lightImpact();
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
              return const PageFrame(
                child: EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Serve una lega',
                  body: 'Puoi creare partite solo nelle leghe in cui sei owner o admin.',
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
                      Text(
                        widget.matchId == null
                            ? 'Organizza il match'
                            : 'Aggiorna il match',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Tutti i membri riceveranno l’aggiornamento in Kickly.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 22),

                      // 1. Di cosa si tratta.
                      _FormSection(
                        eyebrow: 'La partita',
                        icon: Icons.sports_soccer,
                        children: [
                          // La tendina lega compare solo se c'e davvero una
                          // scelta da fare: con una lega sola era un campo
                          // inerte in cima al modulo.
                          if (managed.length > 1) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _leagueId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Lega',
                                prefixIcon: Icon(Icons.shield_outlined),
                              ),
                              items: managed
                                  .map(
                                    (league) => DropdownMenuItem(
                                      value: league.id,
                                      child: Text(
                                        league.name,
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
                      // testo, e il primo dato che un giocatore cerca.
                      _FormSection(
                        eyebrow: 'Quando',
                        icon: Icons.event,
                        children: [
                          InkWell(
                            onTap: _pickDateTime,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: .3),
                                ),
                              ),
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
                                          style: const TextStyle(
                                            color: AppTheme.muted,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          DateFormat('HH:mm').format(_startsAt),
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
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    color: AppTheme.primary,
                                  ),
                                ],
                              ),
                            ),
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
                              labelText: 'Telefono del campo',
                              helperText: 'Serve ai partecipanti per prenotare il campo.',
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
                              for (final value in const [
                                '5v5',
                                '7v7',
                                '8v8',
                                '10v10',
                                '11v11',
                              ])
                                _SelectableChip(
                                  label: value.replaceAll('v', ' vs '),
                                  selected: _format == value,
                                  onTap: () => _setFormat(value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: '$_maxPlayers',
                            key: ValueKey(_maxPlayers),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giocatori totali',
                              helperText: 'Precompilato dal formato, modificalo se serve.',
                              prefixIcon: Icon(Icons.person_add_alt_outlined),
                            ),
                            onChanged: (value) => setState(
                              () => _maxPlayers =
                                  int.tryParse(value) ?? _maxPlayers,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                              prefixText: '€ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_quotaPerPlayer != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(
                                    alpha: .35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.pie_chart_outline,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '€ ${_quotaPerPlayer!.toStringAsFixed(2)} a persona su $_maxPlayers giocatori',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
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
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(
                              color: AppTheme.danger.withValues(alpha: .4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.danger,
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  widget.matchId == null
                                      ? Icons.rocket_launch_outlined
                                      : Icons.save_outlined,
                                ),
                          label: Text(
                            widget.matchId == null
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Token del tema invece degli esadecimali scritti a mano: erano
          // uno il duplicato quasi esatto di AppTheme.surface, l'altro
          // proprio il valore di AppTheme.primary copiato a mano.
          color: bytes == null
              ? AppTheme.surface
              : Colors.black.withValues(alpha: .35),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              bytes == null ? 'Aggiungi' : 'Cambia',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
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
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
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

/// Pillola selezionabile, usata per il formato della partita.
class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.onPrimary : AppTheme.foreground,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Scelta della visibilita con le conseguenze scritte accanto.
///
/// In una tendina "Solo lega" e "Pubblica" sono due parole senza contesto: qui
/// si vede subito chi finira per vedere la partita.
class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        'league_only',
        'Solo lega',
        'La vedono i membri della lega',
        Icons.shield_outlined,
      ),
      (
        'public',
        'Pubblica',
        'Visibile anche ai giocatori vicini',
        Icons.public,
      ),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          if (option != options.first) const SizedBox(height: 9),
          GestureDetector(
            onTap: () => onChanged(option.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: value == option.$1
                    ? AppTheme.primary.withValues(alpha: .1)
                    : AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: value == option.$1
                      ? AppTheme.primary.withValues(alpha: .55)
                      : AppTheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    option.$4,
                    size: 19,
                    color: value == option.$1
                        ? AppTheme.primary
                        : AppTheme.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          option.$3,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    value == option.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 19,
                    color: value == option.$1
                        ? AppTheme.primary
                        : AppTheme.outlineSolid,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
