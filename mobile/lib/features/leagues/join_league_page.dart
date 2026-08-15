import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

class JoinLeaguePage extends StatefulWidget {
  const JoinLeaguePage({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<JoinLeaguePage> createState() => _JoinLeaguePageState();
}

class _JoinLeaguePageState extends State<JoinLeaguePage> {
  final _code = TextEditingController();
  JsonMap? _preview;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.initialCode?.isNotEmpty == true) {
      _initialized = true;
      _code.text = widget.initialCode!.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_code.text.trim().length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await AppScope.of(context).repository
          .getInvitePreview(_code.text);
      if (mounted) {
        setState(() {
          _preview = preview;
          if (preview == null) _error = 'Codice non valido o scaduto.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    // Riscontro tattile alla conferma: entrare in una lega è un cambio di
    // stato per l'utente (diventa membro), non un tap di navigazione qualsiasi.
    // `unawaited`: la vibrazione è un effetto collaterale sul motore aptico,
    // attenderla ritarderebbe la richiesta di rete senza alcun beneficio.
    unawaited(HapticFeedback.lightImpact());
    setState(() => _loading = true);
    try {
      final slug = await AppScope.of(context).repository.joinLeague(_code.text);
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
      appBar: AppBar(title: const Text('Unisciti a una lega')),
      body: SafeArea(
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai un codice invito?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 7),
              const Text(
                'Inseriscilo qui per vedere la lega prima di entrare.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Codice invito',
                  suffixIcon: IconButton(
                    tooltip: 'Cerca lega',
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_preview != null) ...[
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _preview!['name']?.toString() ?? 'Lega Kickly',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_preview!['city']}, ${_preview!['country']}',
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                _preview!['football_format'].toString(),
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${asInt(_preview!['member_count'])}/${asInt(_preview!['max_members'])} membri',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            // Mancava il controllo su _loading: durante la
                            // richiesta il bottone restava cliccabile e un
                            // doppio tap poteva partire come due join
                            // concorrenti sulla stessa lega.
                            onPressed:
                                _preview!['already_member'] == true || _loading
                                ? null
                                : _join,
                            child: Text(
                              _preview!['already_member'] == true
                                  ? 'Sei già membro'
                                  : 'Entra nella lega',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
