import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  String _position = 'midfielder';
  String _skill = 'amateur';
  XFile? _avatar;
  bool _loading = false;
  String? _error;

  static const positions = {
    'goalkeeper': 'Portiere',
    'defender': 'Difensore',
    'midfielder': 'Centrocampista',
    'forward': 'Attaccante',
  };
  static const levels = {
    'beginner': 'Principiante',
    'amateur': 'Amatoriale',
    'intermediate': 'Intermedio',
    'advanced': 'Avanzato',
  };

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image != null) setState(() => _avatar = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final bytes = await _avatar?.readAsBytes();
      final extension = _avatar?.name.split('.').last;
      await scope.repository.saveProfile(
        username: _username.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        primaryPosition: _position,
        skillLevel: _skill,
        avatarBytes: bytes,
        avatarExtension: extension,
      );
      await scope.appState.completeOnboarding();
      if (mounted) context.go('/dashboard');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Il tuo profilo')),
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ULTIMO PASSAGGIO',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Presentati alla squadra',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Questi dati alimentano formazioni, classifiche e la tua player card.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 27),
                  Center(
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(60),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppTheme.surfaceHigh,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _avatar == null
                                  ? Icons.add_a_photo_outlined
                                  : Icons.check,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _avatar == null ? 'Avatar' : 'Pronto',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Nome'),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Cognome',
                          ),
                          validator: _required,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _username,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                    ),
                    validator: (value) =>
                        RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(value ?? '')
                        ? null
                        : '3–24 caratteri: lettere, numeri o underscore.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _position,
                    decoration: const InputDecoration(
                      labelText: 'Ruolo principale',
                    ),
                    items: positions.entries
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _position = value!),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _skill,
                    decoration: const InputDecoration(labelText: 'Livello'),
                    items: levels.entries
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _skill = value!),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entra in Kickly'),
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

  static String? _required(String? value) =>
      (value?.trim().length ?? 0) >= 2 ? null : 'Inserisci almeno 2 caratteri.';
}
