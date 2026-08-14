import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

enum AuthVariant { login, signup, forgot, updatePassword }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.variant});

  final AuthVariant variant;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.variant) {
    AuthVariant.login => 'Bentornato in campo',
    AuthVariant.signup => 'Crea il tuo profilo',
    AuthVariant.updatePassword => 'Scegli una nuova password',
    AuthVariant.forgot => 'Recupera l’accesso',
  };

  String get _description => switch (widget.variant) {
    AuthVariant.login =>
      'Accedi per vedere la prossima partita e le tue statistiche.',
    AuthVariant.signup => 'La tua prossima partita comincia da qui.',
    AuthVariant.updatePassword =>
      'Proteggi il tuo account con almeno 8 caratteri.',
    AuthVariant.forgot =>
      'Ti invieremo un link sicuro per scegliere una nuova password.',
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final scope = AppScope.of(context);
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      switch (widget.variant) {
        case AuthVariant.login:
          await scope.repository.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
          await scope.appState.refreshSession();
        case AuthVariant.signup:
          await scope.repository.signUp(
            email: _emailController.text,
            password: _passwordController.text,
          );
          if (scope.repository.currentUserId == null) {
            setState(
              () =>
                  _message = 'Controlla la tua email per confermare l’account.',
            );
          } else {
            await scope.appState.refreshSession();
          }
        case AuthVariant.forgot:
          await scope.repository.resetPassword(_emailController.text);
          setState(
            () => _message =
                'Se l’account esiste, riceverai un link di recupero.',
          );
        case AuthVariant.updatePassword:
          await scope.repository.updatePassword(_passwordController.text);
          if (mounted) context.go('/dashboard');
      }
    } catch (error) {
      setState(() => _message = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final needsPassword = widget.variant != AuthVariant.forgot;
    final needsEmail = widget.variant != AuthVariant.updatePassword;
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 90,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      KicklyMark(),
                      SizedBox(width: 12),
                      Text(
                        'KICKLY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),
                  const Text(
                    'YOUR GAME. YOUR STORY.',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (needsEmail)
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: needsPassword
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) =>
                                value != null && value.contains('@')
                                ? null
                                : 'Inserisci un’email valida.',
                          ),
                        if (needsPassword) ...[
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            autofillHints: widget.variant == AuthVariant.login
                                ? const [AutofillHints.password]
                                : const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : 'Usa almeno 8 caratteri.',
                          ),
                        ],
                        if (widget.variant == AuthVariant.signup ||
                            widget.variant == AuthVariant.updatePassword) ...[
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Conferma password',
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                            validator: (value) =>
                                value == _passwordController.text
                                ? null
                                : 'Le password non coincidono.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.variant == AuthVariant.login)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Password dimenticata?'),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                  if (_message != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(switch (widget.variant) {
                        AuthVariant.login => 'Accedi',
                        AuthVariant.signup => 'Crea account',
                        AuthVariant.updatePassword => 'Aggiorna password',
                        AuthVariant.forgot => 'Invia link',
                      }),
                    ),
                  ),
                  if (scope.repository.isDemo &&
                      widget.variant == AuthVariant.login) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => scope.appState.startDemo(),
                        icon: const Icon(Icons.sports_soccer),
                        label: const Text('Esplora la demo'),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Supabase non configurato: la demo non salva dati.',
                      style: TextStyle(color: AppTheme.mutedSoft, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 25),
                  Center(
                    child: switch (widget.variant) {
                      AuthVariant.login => TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('Non hai un account? Registrati'),
                      ),
                      AuthVariant.signup => TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Hai già un account? Accedi'),
                      ),
                      AuthVariant.forgot => TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Torna al login'),
                      ),
                      AuthVariant.updatePassword => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
