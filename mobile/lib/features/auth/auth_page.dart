import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  /// Sign in with Apple è nativo su iOS, dove le linee guida App Store lo
  /// rendono di fatto obbligatorio non appena si offre un altro login
  /// social. Il pacchetto supporterebbe anche un flusso web su Android, ma
  /// Kickly non compila un target macOS/web: qui basta la piattaforma.
  bool get _showAppleButton => !kIsWeb && Platform.isIOS;

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
            if (mounted) {
              setState(
                () => _message =
                    'Controlla la tua email per confermare l’account.',
              );
            }
          } else {
            await scope.appState.refreshSession();
          }
        case AuthVariant.forgot:
          await scope.repository.resetPassword(_emailController.text);
          if (mounted) {
            setState(
              () => _message =
                  'Se l’account esiste, riceverai un link di recupero.',
            );
          }
        case AuthVariant.updatePassword:
          await scope.repository.updatePassword(_passwordController.text);
          if (mounted) context.go('/dashboard');
      }
    } catch (error) {
      if (mounted) setState(() => _message = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Esegue un accesso social (Google o Apple) condividendo lo stesso stato
  /// di caricamento/errore del form email+password, così i due percorsi non
  /// possono mai risultare attivi insieme.
  Future<void> _signInWithProvider(Future<void> Function() action) async {
    final scope = AppScope.of(context);
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await action();
      await scope.appState.refreshSession();
    } on GoogleSignInException catch (error) {
      // L'utente ha chiuso il selettore account: non è un errore da
      // mostrare, è la scelta di non accedere.
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _message = friendlyError(error));
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled && mounted) {
        setState(() => _message = friendlyError(error));
      }
    } catch (error) {
      if (mounted) setState(() => _message = friendlyError(error));
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
                  // Il pattern Figma di riferimento (login multi-social, es.
                  // schermate "X"/"LinkedIn") mette i provider social subito
                  // in evidenza come blocco pieno di bottoni impilati, e
                  // relega il form email/password a un secondo blocco sotto
                  // un divisore "oppure". La condizione di visibilità resta
                  // identica a prima (solo login/signup, solo se almeno un
                  // provider è configurato): cambia solo l'ORDINE con cui i
                  // blocchi compaiono, non il comportamento sottostante.
                  if ((widget.variant == AuthVariant.login ||
                          widget.variant == AuthVariant.signup) &&
                      (scope.config.hasGoogleSignIn || _showAppleButton)) ...[
                    if (scope.config.hasGoogleSignIn)
                      SizedBox(
                        width: double.infinity,
                        // Altezza leggermente maggiore del default del tema
                        // (48): nel pattern Figma i bottoni social sono il
                        // primo elemento toccato dall'utente, quindi meritano
                        // un target più "generoso" rispetto ai controlli
                        // secondari.
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _signInWithProvider(
                                  scope.repository.signInWithGoogle,
                                ),
                          icon: const _GoogleMark(),
                          label: const Text('Continua con Google'),
                        ),
                      ),
                    if (_showAppleButton) ...[
                      if (scope.config.hasGoogleSignIn)
                        // Spaziatura più ampia del solito (14 invece di 10)
                        // fra i bottoni social impilati, com'è nel pattern
                        // Figma preso a riferimento.
                        const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: SignInWithAppleButton(
                          onPressed: _loading
                              ? null
                              : () => _signInWithProvider(
                                  scope.repository.signInWithApple,
                                ),
                          style: SignInWithAppleButtonStyle.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const _OrDivider(),
                    const SizedBox(height: 22),
                  ],
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
                        style: const TextStyle(color: AppTheme.foreground),
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

/// Separatore "oppure" fra il form email/password e i login social.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppTheme.outline)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'oppure',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppTheme.outline)),
    ],
  );
}

/// "G" di Google in un cerchio bianco, come icona del pulsante di accesso.
///
/// Non è il logomark ufficiale a quattro colori (per quello servirebbe
/// l'asset esatto di Google), ma una resa volutamente semplice: un cerchio
/// bianco con la lettera nel blu del brand è una convenzione diffusa e
/// riconoscibile quando l'asset ufficiale non è incluso nel progetto.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4), // Google Blue.
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}
