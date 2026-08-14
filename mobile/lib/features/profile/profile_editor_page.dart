import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

import '../../app.dart';
import '../../core/location/italian_location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _birthDate = TextEditingController();
  ItalianPlace? _place;
  String _primary = 'midfielder';
  String? _secondary;
  String _foot = 'right';
  String _skill = 'amateur';
  bool _public = true;
  bool _saving = false;
  Uint8List? _avatarBytes;
  String? _avatarExtension;
  Future<UserProfile?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getCurrentProfile().then((p) {
      if (p != null) {
        _firstName.text = p.firstName ?? '';
        _lastName.text = p.lastName ?? '';
        _username.text = p.username.startsWith('player_') ? '' : p.username;
        _birthDate.text = p.birthDate ?? '';
        if (p.city?.isNotEmpty == true &&
            p.province?.isNotEmpty == true &&
            p.latitude != null &&
            p.longitude != null) {
          _place = ItalianPlace(
            city: p.city!,
            province: p.province!,
            latitude: p.latitude!,
            longitude: p.longitude!,
            displayName: '${p.city}, ${p.province}, Italia',
          );
        }
        _primary = p.primaryPosition ?? 'midfielder';
        _secondary = p.secondaryPosition;
        _foot = p.preferredFoot ?? 'right';
        _skill = p.skillLevel ?? 'amateur';
        _public = p.profilePublic;
      }
      return p;
    });
  }

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _username, _birthDate]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AppScope.of(context).repository.saveProfile(
        username: _username.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        primaryPosition: _primary,
        skillLevel: _skill,
        birthDate: _birthDate.text,
        city: _place?.city,
        province: _place?.province,
        latitude: _place?.latitude,
        longitude: _place?.longitude,
        secondaryPosition: _secondary,
        preferredFoot: _foot,
        profilePublic: _public,
        avatarBytes: _avatarBytes,
        avatarExtension: _avatarExtension,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
        if (widget.onboarding) {
          await AppScope.of(context).appState.completeOnboarding();
          if (mounted) context.go('/dashboard');
        } else {
          context.pop();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.onboarding
        ? null
        : AppBar(title: const Text('Modifica profilo')),
    // In onboarding non c'è AppBar, quindi senza SafeArea il titolo finiva
    // sotto la status bar e il notch.
    body: SafeArea(
      bottom: false,
      child: FutureBuilder<UserProfile?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton(items: 2);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'LA TUA PLAYER CARD',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.onboarding ? 'Completa il profilo' : 'Profilo giocatore',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 7),
              const Text(
                'Le stesse informazioni mostrate nella PWA, aggiornate anche nelle leghe e nelle formazioni.',
                style: TextStyle(color: AppTheme.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              Card(
                child: InkWell(
                  onTap: _pickAvatar,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: _avatarBytes == null
                              ? null
                              : MemoryImage(_avatarBytes!),
                          child: _avatarBytes == null
                              ? const Icon(Icons.camera_alt_outlined)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto profilo',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'JPG, PNG o WebP · max 5 MB',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field(_firstName, 'Nome')),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_lastName, 'Cognome')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _field(_username, 'Username', prefix: const Text('@')),
                    const SizedBox(height: 14),
                    _field(
                      _birthDate,
                      'Data di nascita',
                      hint: 'AAAA-MM-GG',
                      optional: true,
                    ),
                    const SizedBox(height: 14),
                    ItalianMunicipalityField(
                      key: ValueKey(
                        '${snapshot.data?.city}|${snapshot.data?.province}',
                      ),
                      initialCity: snapshot.data?.city,
                      initialProvince: snapshot.data?.province,
                      initialLatitude: snapshot.data?.latitude,
                      initialLongitude: snapshot.data?.longitude,
                      onSelected: (place) => _place = place,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _select(
                            'Ruolo principale',
                            _primary,
                            _roles,
                            (v) => setState(() => _primary = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _select(
                            'Ruolo secondario',
                            _secondary ?? 'none',
                            {'none': 'Nessuno', ..._roles},
                            (v) => setState(
                              () => _secondary = v == 'none' ? null : v,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _select('Piede preferito', _foot, const {
                            'right': 'Destro',
                            'left': 'Sinistro',
                            'both': 'Entrambi',
                          }, (v) => setState(() => _foot = v!)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _select('Livello', _skill, const {
                            'beginner': 'Principiante',
                            'amateur': 'Amatore',
                            'competitive': 'Competitivo',
                          }, (v) => setState(() => _skill = v!)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: SwitchListTile(
                        value: _public,
                        onChanged: (v) => setState(() => _public = v),
                        title: const Text(
                          'Profilo pubblico',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Mostra player card e statistiche nelle aree pubbliche.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.onboarding
                                    ? 'Entra in Kickly'
                                    : 'Salva modifiche',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    Widget? prefix,
    String? hint,
    bool optional = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: prefix == null ? null : Center(widthFactor: 1, child: prefix),
      hintText: hint,
    ),
    validator: optional
        ? null
        : (v) => (v?.trim().length ?? 0) < 2 ? 'Almeno 2 caratteri' : null,
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    // Senza isExpanded il menu si dimensiona sulla voce più lunga e ignora la
    // colonna che lo contiene: in metà schermo "Centrocampista" sfondava il
    // campo con l'indicatore di overflow giallo e nero.
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
  static const _roles = {
    'goalkeeper': 'Portiere',
    'defender': 'Difensore',
    'midfielder': 'Centrocampista',
    'forward': 'Attaccante',
  };

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La foto deve pesare meno di 5 MB.')),
        );
      }
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _avatarExtension = image.name.split('.').last;
    });
  }
}
