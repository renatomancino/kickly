import 'dart:typed_data';

import 'package:flutter/material.dart';
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
    if (time == null) return;
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
      setState(() => _error = friendlyError(error));
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
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La foto deve pesare meno di 8 MB.')),
        );
      }
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
              return const Center(child: CircularProgressIndicator());
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
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _leagueId,
                        decoration: const InputDecoration(labelText: 'Lega'),
                        items: managed
                            .map(
                              (league) => DropdownMenuItem(
                                value: league.id,
                                child: Text(league.name),
                              ),
                            )
                            .toList(),
                        onChanged: widget.matchId == null
                            ? (value) => setState(() => _leagueId = value)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Titolo'),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data e ora',
                            prefixIcon: Icon(Icons.event),
                          ),
                          child: Text(
                            DateFormat(
                              'EEEE d MMMM y · HH:mm',
                              'it_IT',
                            ).format(_startsAt),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Campo / centro sportivo',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo completo del campo',
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
                          helperText: 'Visibile ai partecipanti per prenotare il campo.',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isEmpty) {
                            return 'Numero del campo obbligatorio.';
                          }
                          return RegExp(r'^[0-9+() .-]{6,30}$').hasMatch(phone)
                              ? null
                              : 'Numero non valido.';
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _format,
                              decoration: const InputDecoration(
                                labelText: 'Formato',
                              ),
                              items:
                                  const ['5v5', '7v7', '8v8', '10v10', '11v11']
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) => _setFormat(value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: '$_maxPlayers',
                              key: ValueKey(_maxPlayers),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Giocatori',
                              ),
                              onChanged: (value) => setState(
                                () => _maxPlayers =
                                    int.tryParse(value) ?? _maxPlayers,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cost,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Costo totale €',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _visibility,
                              decoration: const InputDecoration(
                                labelText: 'Visibilità',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'league_only',
                                  child: Text('Solo lega'),
                                ),
                                DropdownMenuItem(
                                  value: 'public',
                                  child: Text('Pubblica'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _visibility = value!),
                            ),
                          ),
                        ],
                      ),
                      if (double.tryParse(_cost.text.replaceAll(',', '.')) !=
                          null) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC7FF3D)
                                .withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFC7FF3D)
                                  .withValues(alpha: .35),
                            ),
                          ),
                          child: Text(
                            'Quota: € ${(double.parse(_cost.text.replaceAll(',', '.')) / _maxPlayers).toStringAsFixed(2)} a persona',
                            style: const TextStyle(
                              color: Color(0xFFC7FF3D),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Foto della partita',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
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
                      if (_error != null) ...[
                        const SizedBox(height: 15),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const CircularProgressIndicator()
                              : const Text('Pubblica partita'),
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
        border: Border.all(color: Colors.white12),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: bytes == null
              ? const Color(0xFF171B18)
              : Colors.black.withValues(alpha: .35),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFC7FF3D)),
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
