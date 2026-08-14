import 'package:flutter/material.dart';
// `Uint8List` arriva già da qui: `dart:typed_data` diretto non serve più
// e l'analyzer lo segnala come import ridondante.
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class LeagueFormPage extends StatefulWidget {
  const LeagueFormPage({super.key});

  @override
  State<LeagueFormPage> createState() => _LeagueFormPageState();
}

class _LeagueFormPageState extends State<LeagueFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'IT');
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
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Riscontro tattile alla conferma di un form importante come la
    // creazione di una lega, non su ogni tap generico del modulo.
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slug = await AppScope.of(context).repository.createLeague(
        name: _name.text,
        slug: _slugify(_name.text),
        description: _description.text,
        city: _city.text,
        country: _country.text,
        visibility: _visibility,
        footballFormat: _format,
        maxMembers: _maxMembers,
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
                  Text(
                    'Crea il tuo campionato',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Imposta le regole base. Potrai invitare i giocatori subito dopo.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 25),
                  Card(
                    child: InkWell(
                      onTap: _pickLogo,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                // Token del tema invece di
                                // Theme.of(context).colorScheme.primary: sono
                                // lo stesso colore, ma qui si usa quello con
                                // cui il resto del file lavora.
                                color: AppTheme.primary.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(17),
                                image: _logoBytes == null
                                    ? null
                                    : DecorationImage(
                                        image: MemoryImage(_logoBytes!),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              child: _logoBytes == null
                                  ? const Icon(Icons.add_a_photo_outlined)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logo della lega',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
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
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome lega'),
                    validator: (value) => (value?.trim().length ?? 0) >= 3
                        ? null
                        : 'Usa almeno 3 caratteri.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          decoration: const InputDecoration(labelText: 'Città'),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _country,
                          decoration: const InputDecoration(
                            labelText: 'Codice paese',
                          ),
                          validator: _required,
                        ),
                      ),
                    ],
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
                          items: const ['5v5', '7v7', '8v8', '10v10', '11v11']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _format = value!),
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
                              value: 'private',
                              child: Text('Privata'),
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
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _maxMembers,
                    decoration: const InputDecoration(
                      labelText: 'Numero massimo membri',
                    ),
                    items: const [10, 14, 20, 28, 40, 60]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value giocatori'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _maxMembers = value!),
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

  static String? _required(String? value) =>
      (value?.trim().length ?? 0) >= 2 ? null : 'Campo obbligatorio.';
}
