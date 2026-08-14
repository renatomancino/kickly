import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

class ItalianPlace {
  const ItalianPlace({
    required this.city,
    required this.province,
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final String city;
  final String province;
  final double latitude;
  final double longitude;
  final String displayName;
}

class ItalianLocationService {
  const ItalianLocationService();

  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  Future<List<ItalianPlace>> searchMunicipalities(String query) async {
    final cleaned = query.trim();
    if (cleaned.length < 2) return const [];
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'q': '$cleaned, Italia',
        'format': 'jsonv2',
        'addressdetails': '1',
        'countrycodes': 'it',
        'limit': '8',
        'accept-language': 'it',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw StateError('Ricerca località temporaneamente non disponibile.');
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    final seen = <String>{};
    return rows
        .map((raw) => _fromNominatim(Map<String, dynamic>.from(raw as Map)))
        .whereType<ItalianPlace>()
        .where((place) => seen.add('${place.city}|${place.province}'))
        .toList();
  }

  Future<ItalianPlace?> geocodeVenue({
    required String address,
    required ItalianPlace municipality,
  }) async {
    if (address.trim().isEmpty) return municipality;
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'q':
            '${address.trim()}, ${municipality.city}, ${municipality.province}, Italia',
        'format': 'jsonv2',
        'addressdetails': '1',
        'countrycodes': 'it',
        'limit': '1',
        'accept-language': 'it',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return municipality;
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return municipality;
    final row = Map<String, dynamic>.from(rows.first as Map);
    return ItalianPlace(
      city: municipality.city,
      province: municipality.province,
      latitude:
          double.tryParse(row['lat']?.toString() ?? '') ??
          municipality.latitude,
      longitude:
          double.tryParse(row['lon']?.toString() ?? '') ??
          municipality.longitude,
      displayName: row['display_name']?.toString() ?? municipality.displayName,
    );
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Accept-Language': 'it-IT,it;q=0.9',
    if (!kIsWeb) 'User-Agent': 'Kickly/1.0 (mobile location search)',
  };

  ItalianPlace? _fromNominatim(Map<String, dynamic> row) {
    final address = row['address'] is Map
        ? Map<String, dynamic>.from(row['address'] as Map)
        : const <String, dynamic>{};
    if (address['country_code']?.toString().toLowerCase() != 'it') return null;
    final city = _firstText([
      address['city'],
      address['town'],
      address['village'],
      address['municipality'],
      row['name'],
    ]);
    final province = _firstText([
      address['province'],
      address['county'],
      address['state_district'],
    ]);
    final latitude = double.tryParse(row['lat']?.toString() ?? '');
    final longitude = double.tryParse(row['lon']?.toString() ?? '');
    if (city == null ||
        province == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    if (latitude < 35 || latitude > 48 || longitude < 6 || longitude > 19) {
      return null;
    }
    return ItalianPlace(
      city: city,
      province: province,
      latitude: latitude,
      longitude: longitude,
      displayName: row['display_name']?.toString() ?? '$city, $province',
    );
  }

  String? _firstText(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}

class ItalianMunicipalityField extends StatefulWidget {
  const ItalianMunicipalityField({
    super.key,
    required this.onSelected,
    this.initialCity,
    this.initialProvince,
    this.initialLatitude,
    this.initialLongitude,
    this.enabled = true,
  });

  final String? initialCity;
  final String? initialProvince;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<ItalianPlace?> onSelected;
  final bool enabled;

  @override
  State<ItalianMunicipalityField> createState() =>
      _ItalianMunicipalityFieldState();
}

class _ItalianMunicipalityFieldState extends State<ItalianMunicipalityField> {
  final _controller = TextEditingController();
  final _service = const ItalianLocationService();
  List<ItalianPlace> _results = const [];
  ItalianPlace? _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialCity ?? '';
    if (widget.initialCity?.isNotEmpty == true &&
        widget.initialProvince?.isNotEmpty == true &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _selected = ItalianPlace(
        city: widget.initialCity!,
        province: widget.initialProvince!,
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
        displayName: '${widget.initialCity}, ${widget.initialProvince}, Italia',
      );
    }
  }

  @override
  void didUpdateWidget(covariant ItalianMunicipalityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text.isEmpty && widget.initialCity?.isNotEmpty == true) {
      _controller.text = widget.initialCity!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    var changed = false;
    if (_selected != null && value != _selected!.city) {
      _selected = null;
      widget.onSelected(null);
      changed = true;
    }
    if (_results.isNotEmpty) {
      _results = const [];
      changed = true;
    }
    if (value.trim().length < 2 || changed) {
      setState(() {
        _error = null;
      });
    }
  }

  Future<void> _search() async {
    final value = _controller.text;
    if (value.trim().length < 2) {
      setState(() => _error = 'Scrivi almeno 2 caratteri.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.searchMunicipalities(value);
      if (mounted) {
        setState(() {
          _results = results;
          if (results.isEmpty) _error = 'Nessun comune italiano trovato.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossibile cercare ora. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final province = _selected?.province ?? widget.initialProvince;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onFieldSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Comune',
            hintText: 'Inizia a scrivere, es. Milano',
            prefixIcon: const Icon(Icons.location_city_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _selected == null
                ? IconButton(
                    tooltip: 'Cerca comune',
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                  )
                : const Icon(Icons.verified, color: Color(0xFFC7FF3D)),
          ),
          validator: (_) => _selected == null
              ? 'Seleziona un comune dai risultati verificati.'
              : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_results.isNotEmpty && _selected == null)
          Container(
            margin: const EdgeInsets.only(top: 7),
            constraints: const BoxConstraints(maxHeight: 230),
            // Material e non solo DecoratedBox: le ListTile dipingono sfondo e
            // onda del tocco sul Material antenato più vicino, quindi con un
            // semplice contenitore colorato il tocco risultava invisibile
            // (Flutter lo segnalava con un'assertion a runtime).
            child: Material(
              color: AppTheme.surface,
              clipBehavior: Clip.antiAlias,
              // Solo `shape`: Material va in assertion se riceve anche
              // `borderRadius`, perché sarebbero due definizioni della stessa
              // cosa.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.outline),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.outline),
                itemBuilder: (context, index) {
                  final place = _results[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppTheme.primary,
                    ),
                    title: Text(place.city),
                    subtitle: Text('${place.province} · Italia'),
                    onTap: () {
                      _controller.text = place.city;
                      _selected = place;
                      widget.onSelected(place);
                      setState(() => _results = const []);
                    },
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Provincia',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          child: Text(
            province?.isNotEmpty == true ? province! : 'Automatica dal comune',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Località italiane verificate tramite OpenStreetMap.',
          style: TextStyle(color: AppTheme.mutedSoft, fontSize: 10),
        ),
      ],
    );
  }
}
