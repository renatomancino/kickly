import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

import '../../app.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

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
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare definitivamente la lega?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Questa azione non è reversibile. Digita “${league.summary.name}” per confermare.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: confirmation,
              decoration: InputDecoration(hintText: league.summary.name),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmation.text == league.summary.name,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (accepted != true || !mounted) return;
    await AppScope.of(context).repository.deleteLeague(league.summary.id);
    if (mounted) context.go('/leagues');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Impostazioni lega')),
    body: FutureBuilder<LeagueDetail?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final league = snapshot.data;
        if (league == null || !league.summary.canManage) {
          return const PageFrame(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Accesso negato',
              body: 'Le impostazioni sono riservate agli admin.',
            ),
          );
        }
        init(league);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Gestisci ${league.summary.name}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            const Text(
              'Le modifiche si riflettono immediatamente anche nella PWA.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 22),
            Form(
              key: formKey,
              child: Column(
                children: [
                  Card(
                    child: InkWell(
                      onTap: pickLogo,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: .12),
                                image: logoBytes == null
                                    ? null
                                    : DecorationImage(
                                        image: MemoryImage(logoBytes!),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              child: logoBytes == null
                                  ? const Icon(Icons.add_a_photo_outlined)
                                  : null,
                            ),
                            const SizedBox(width: 13),
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
                                  SizedBox(height: 3),
                                  Text(
                                    'Tocca per sostituire · max 5 MB',
                                    style: TextStyle(
                                      color: Colors.white54,
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome lega'),
                    validator: required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: city,
                          decoration: const InputDecoration(labelText: 'Città'),
                          validator: required,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: country,
                          decoration: const InputDecoration(labelText: 'Paese'),
                          validator: required,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: format,
                          decoration: const InputDecoration(
                            labelText: 'Formato',
                          ),
                          items: const ['5v5', '7v7', '8v8', '10v10', '11v11']
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => format = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: visibility,
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
                          onChanged: (v) => setState(() => visibility = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: maxMembers,
                    decoration: const InputDecoration(
                      labelText: 'Numero massimo membri',
                    ),
                    items: const [10, 14, 20, 28, 40, 60]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v giocatori'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => maxMembers = v!),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving ? null : () => save(league),
                      child: const Text('Salva modifiche'),
                    ),
                  ),
                ],
              ),
            ),
            if (league.summary.currentUserRole == 'owner') ...[
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => delete(league),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina lega'),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
  static String? required(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Campo obbligatorio' : null;

  Future<void> pickLogo() async {
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
          const SnackBar(content: Text('Il logo deve pesare meno di 5 MB.')),
        );
      }
      return;
    }
    setState(() {
      logoBytes = bytes;
      logoExtension = image.name.split('.').last;
    });
  }
}
