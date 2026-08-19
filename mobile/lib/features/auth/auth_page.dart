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

/// Larghezza massima della colonna di accesso.
///
/// `PageFrame` si ferma a 760px, che per una dashboard piena di card va
/// benissimo: qui no. Un campo email largo 700px su tablet fa sembrare la
/// schermata un modulo web di vent'anni fa e obbliga l'occhio a rifare tutta
/// la riga per passare da un campo al successivo. Le schermate di
/// autenticazione restano su una colonna stretta e centrata, come nella PWA.
const _authColumnMaxWidth = 430.0;

/// Altezza minima dei pulsanti di accesso rapido (social) e della CTA.
///
/// Più generosa del default del tema (48/50) perché su questa schermata quei
/// pulsanti sono l'intera interazione: non ci sono liste o card a fare da
/// contorno, quindi possono permettersi di respirare.
const _primaryButtonHeight = 52.0;

/// Blu del marchio Google (#4285F4). NON è un token del tema, di proposito.
///
/// Le linee guida di Google per il pulsante "Continua con Google" impongono il
/// marchio nei colori esatti del brand: ridipingerlo con il verde Kickly
/// renderebbe il pulsante non conforme e, cosa che conta di più, irriconoscibile
/// nel mezzo secondo in cui l'utente lo cerca con lo sguardo.
const _googleBlue = Color(0xFF4285F4);

/// Bianco pieno del disco su cui poggia la "G", per la stessa ragione di
/// [_googleBlue]: il marchio Google va sempre su fondo chiaro, anche quando
/// l'interfaccia intorno è scura come la nostra.
const _googleMarkSurface = Color(0xFFFFFFFF);

/// Stile dell'occhiello sopra il titolo.
///
/// Ricalca volutamente quello di `SectionTitle` in core/widgets/common.dart:
/// è la stessa "voce" tipografica usata in tutta l'app per dire dove ci si
/// trova, e non c'è motivo perché qui suoni diversa.
const _eyebrowStyle = TextStyle(
  color: AppTheme.muted,
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.5,
);

enum AuthVariant { login, signup, forgot, updatePassword }

/// Esito di un'operazione, mostrato nel riquadro sopra la CTA.
///
/// Prima era una nuda `String?`: "Controlla la tua email per confermare
/// l'account" (una buona notizia, il flusso è andato a buon fine) veniva
/// disegnata identica a "Email o password non corrette" (un errore da
/// correggere subito). Portandosi dietro anche la *natura* del messaggio, il
/// riquadro può cambiare colore e icona e la differenza si coglie prima di
/// aver letto una parola.
class _AuthMessage {
  const _AuthMessage(this.text, {required this.isError});

  final String text;
  final bool isError;
}

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
  _AuthMessage? _message;

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

  // --- Copy differenziato per variante ------------------------------------
  //
  // Le quattro varianti condividono la stessa classe ma non lo stesso
  // momento: chi torna a fare login e chi arriva da un link di recupero non
  // hanno né lo stesso obiettivo né lo stesso stato d'animo. Prima cambiava
  // solo l'etichetta del bottone e tutte e quattro si aprivano con lo stesso
  // claim del marchio, che davanti a "ho perso la password" suona fuori posto.

  /// Occhiello sopra il titolo: l'unica riga che dice *in che punto del
  /// percorso* si trova chi legge.
  ///
  /// Login e registrazione sono la porta d'ingresso e si prendono il claim del
  /// marchio; recupero e nuova password sono invece due passaggi di un flusso
  /// cominciato altrove (un'email), quindi lì l'occhiello orienta invece di
  /// vendere — e "ULTIMO PASSAGGIO" dice anche che manca poco.
  String get _eyebrow => switch (widget.variant) {
    AuthVariant.login || AuthVariant.signup => 'YOUR GAME. YOUR STORY.',
    AuthVariant.forgot => 'PASSWORD DIMENTICATA',
    AuthVariant.updatePassword => 'ULTIMO PASSAGGIO',
  };

  String get _title => switch (widget.variant) {
    AuthVariant.login => 'Bentornato in campo',
    AuthVariant.signup => 'Crea il tuo profilo',
    AuthVariant.updatePassword => 'Scegli una nuova password',
    AuthVariant.forgot => 'Recupera l’accesso',
  };

  String get _description => switch (widget.variant) {
    AuthVariant.login =>
      'Accedi per vedere la prossima partita e le tue statistiche.',
    // Dice quanto costa iscriversi, non quanto è bello Kickly: davanti a un
    // modulo la domanda muta è sempre "quanto ci metto?".
    AuthVariant.signup => 'Bastano email e password: la player card la costruisci dopo, in due minuti.',
    AuthVariant.updatePassword =>
      'Proteggi il tuo account con almeno 8 caratteri.',
    AuthVariant.forgot =>
      'Ti invieremo un link sicuro per scegliere una nuova password.',
  };

  String get _submitLabel => switch (widget.variant) {
    AuthVariant.login => 'Accedi',
    AuthVariant.signup => 'Crea account',
    AuthVariant.updatePassword => 'Aggiorna password',
    AuthVariant.forgot => 'Invia link',
  };

  /// L'icona della CTA racconta cosa succede al tocco: si entra (freccia), si
  /// spedisce un'email (aereo), si conferma e si chiude (spunta). Con la
  /// freccia ovunque, "Invia link" prometteva una schermata successiva che
  /// invece non arriva mai.
  IconData get _submitIcon => switch (widget.variant) {
    AuthVariant.login || AuthVariant.signup => Icons.arrow_forward,
    AuthVariant.forgot => Icons.send_outlined,
    AuthVariant.updatePassword => Icons.check_rounded,
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
                () => _message = const _AuthMessage(
                  'Controlla la tua email per confermare l’account.',
                  isError: false,
                ),
              );
            }
          } else {
            await scope.appState.refreshSession();
          }
        case AuthVariant.forgot:
          await scope.repository.resetPassword(_emailController.text);
          if (mounted) {
            setState(
              () => _message = const _AuthMessage(
                'Se l’account esiste, riceverai un link di recupero.',
                isError: false,
              ),
            );
          }
        case AuthVariant.updatePassword:
          await scope.repository.updatePassword(_passwordController.text);
          if (mounted) context.go('/dashboard');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = _AuthMessage(friendlyError(error), isError: true),
        );
      }
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
        setState(
          () => _message = _AuthMessage(friendlyError(error), isError: true),
        );
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled && mounted) {
        setState(
          () => _message = _AuthMessage(friendlyError(error), isError: true),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = _AuthMessage(friendlyError(error), isError: true),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final needsPassword = widget.variant != AuthVariant.forgot;
    final needsEmail = widget.variant != AuthVariant.updatePassword;
    final needsConfirm =
        widget.variant == AuthVariant.signup ||
        widget.variant == AuthVariant.updatePassword;
    // I login social hanno senso solo dove si entra o ci si iscrive: in
    // recupero/nuova password l'utente ha già imboccato la strada email, e
    // offrirgli lì "Continua con Google" lo manderebbe fuori dal flusso.
    final showSocial =
        (widget.variant == AuthVariant.login ||
            widget.variant == AuthVariant.signup) &&
        (scope.config.hasGoogleSignIn || _showAppleButton);

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          // LayoutBuilder + minHeight: prima l'altezza minima era
          // `MediaQuery.height - 90`, un 90 preso a occhio che non teneva
          // conto né della SafeArea né del padding di PageFrame. Su un
          // telefono con notch la colonna risultava più alta dello spazio
          // reale, quindi il "centrato verticalmente" era centrato rispetto a
          // una scatola che non esiste. Qui la misura è quella davvero
          // disponibile: con spazio avanzato il blocco sta al centro esatto,
          // e con il testo di sistema ingrandito la pagina scorre invece di
          // traboccare.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // Center fa due lavori insieme: centra in verticale quando lo
                // spazio avanza e tiene la colonna stretta al centro sui
                // tablet, dove altrimenti si incollerebbe al bordo sinistro.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _authColumnMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BrandLockup(),
                        const SizedBox(height: 44),
                        Text(_eyebrow, style: _eyebrowStyle),
                        const SizedBox(height: 8),
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _description,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // I provider social stanno sopra al form, come nel
                        // pattern Figma di riferimento: sono la strada più
                        // corta, e chi ce l'ha non deve scavalcare due campi
                        // per accorgersene. La condizione di visibilità è
                        // quella di sempre, cambia solo l'ordine.
                        if (showSocial) ...[
                          if (scope.config.hasGoogleSignIn)
                            _GoogleButton(
                              onPressed: _loading
                                  ? null
                                  : () => _signInWithProvider(
                                      scope.repository.signInWithGoogle,
                                    ),
                            ),
                          if (_showAppleButton) ...[
                            if (scope.config.hasGoogleSignIn)
                              const SizedBox(height: 12),
                            _AppleButton(
                              onPressed: _loading
                                  ? null
                                  : () => _signInWithProvider(
                                      scope.repository.signInWithApple,
                                    ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          const _OrDivider(),
                          const SizedBox(height: 24),
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
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  textInputAction: needsConfirm
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  autofillHints:
                                      widget.variant == AuthVariant.login
                                      ? const [AutofillHints.password]
                                      : const [AutofillHints.newPassword],
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      // Bottone di sola icona: senza tooltip
                                      // un lettore di schermo annuncia solo
                                      // "pulsante", e a occhio l'occhio
                                      // sbarrato è ambiguo (sto nascondendo o
                                      // sto mostrando?).
                                      tooltip: _obscure
                                          ? 'Mostra la password'
                                          : 'Nascondi la password',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.length ?? 0) >= 8
                                      ? null
                                      : 'Usa almeno 8 caratteri.',
                                ),
                              ],
                              if (needsConfirm) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmController,
                                  // Segue lo stesso interruttore del campo
                                  // sopra invece di restare sempre coperto:
                                  // se la password è in chiaro e la conferma
                                  // no, l'errore "le password non coincidono"
                                  // resta impossibile da risolvere a occhio,
                                  // che è esattamente il lavoro per cui
                                  // l'interruttore esiste.
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
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
                              // Grigio e non verde: è una via d'uscita per chi
                              // è in difficoltà, non l'azione che vogliamo
                              // suggerire. Il verde in questa schermata è
                              // prenotato dalla CTA lì sotto.
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.muted,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => context.go('/forgot-password'),
                              child: const Text('Password dimenticata?'),
                            ),
                          )
                        else
                          const SizedBox(height: 22),
                        if (_message != null) ...[
                          _MessageBanner(message: _message!),
                          const SizedBox(height: 14),
                        ],
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              _primaryButtonHeight,
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    // Colore esplicito: da disabilitato il
                                    // bottone perde il fondo verde e la
                                    // rotellina resta l'unico segnale che sta
                                    // succedendo qualcosa, quindi non deve
                                    // dipendere da un default del tema che
                                    // domani potrebbe cambiare.
                                    color: AppTheme.primary,
                                  ),
                                )
                              : Icon(_submitIcon),
                          label: Text(_submitLabel),
                        ),
                        if (scope.repository.isDemo &&
                            widget.variant == AuthVariant.login) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () => scope.appState.startDemo(),
                            icon: const Icon(Icons.sports_soccer),
                            label: const Text('Esplora la demo'),
                          ),
                          const SizedBox(height: 9),
                          const SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Supabase non configurato: la demo non salva dati.',
                              style: TextStyle(
                                color: AppTheme.mutedSoft,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Center(
                          child: switch (widget.variant) {
                            AuthVariant.login => _SwitchLink(
                              question: 'Non hai un account?',
                              action: 'Registrati',
                              onTap: () => context.go('/signup'),
                            ),
                            AuthVariant.signup => _SwitchLink(
                              question: 'Hai già un account?',
                              action: 'Accedi',
                              onTap: () => context.go('/login'),
                            ),
                            AuthVariant.forgot => _SwitchLink(
                              action: 'Torna al login',
                              onTap: () => context.go('/login'),
                            ),
                            // Nessuna via di fuga: si arriva qui da un link di
                            // recupero e l'unica cosa sensata è finire.
                            AuthVariant.updatePassword =>
                              const SizedBox.shrink(),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marchio in testa alla schermata: quadrato verde + logotipo.
///
/// È l'unica cosa che l'utente vede prima di decidere se fidarsi, e vale
/// doppio nella variante "nuova password", dove si atterra da un link ricevuto
/// per email: riconoscere il marchio è il modo più rapido per capire di non
/// essere finiti su una pagina di phishing.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) => const Row(
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
  );
}

/// Pulsante "Continua con Google".
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    // `minimumSize` e non un `SizedBox(height:)`: l'altezza fissa è una
    // scatola tight, quindi con il testo di sistema ingrandito l'etichetta
    // sfonderebbe il pulsante. Il minimo dà lo stesso bersaglio generoso ma
    // lascia crescere il bottone quando serve.
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(_primaryButtonHeight),
    ),
    icon: const _GoogleMark(),
    label: const Text('Continua con Google'),
  );
}

/// Pulsante "Continua con Apple".
///
/// Il widget arriva dal pacchetto e porta con sé le regole di Apple: fondo
/// bianco pieno (obbligatorio su interfacce scure come la nostra) e tipografia
/// propria. È il motivo per cui è l'elemento più chiaro della pagina pur non
/// essendo l'azione principale: non possiamo spegnerlo senza uscire dalle
/// linee guida.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    // L'altezza si impone da fuori invece di passarla al widget: il pacchetto
    // calcola il corpo del testo come il 43% dell'altezza, quindi `height: 52`
    // porterebbe l'etichetta a 22px, il doppio di "Continua con Google" a
    // fianco. Così il bersaglio è allineato agli altri pulsanti ma la
    // tipografia resta quella dei 44px di Apple.
    height: _primaryButtonHeight,
    child: SignInWithAppleButton(
      // `onPressed` è nullable anche nel pacchetto: passare null durante il
      // caricamento è ciò che disabilita il pulsante, quindi guai a metterci
      // una callback vuota di comodo — sembrerebbe attivo e non lo è.
      onPressed: onPressed,
      // Apple chiede che l'etichetta sia nella lingua dell'interfaccia: il
      // default del pacchetto è "Sign in with Apple", che in mezzo a una
      // schermata italiana stonava ed era anche fuori linea guida.
      text: 'Continua con Apple',
      style: SignInWithAppleButtonStyle.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
  );
}

/// Separatore "oppure" fra i login rapidi e il form email/password.
///
/// L'etichetta è maiuscola e spaziata come gli occhielli del resto dell'app:
/// così legge come un'insegna che separa due strade, non come una parola
/// dimenticata in mezzo a una riga.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: AppTheme.outline)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('OPPURE', style: _eyebrowStyle),
      ),
      Expanded(child: Divider(color: AppTheme.outline)),
    ],
  );
}

/// Riquadro di esito sopra la CTA.
///
/// Due letture diverse a colpo d'occhio: l'errore prende il rosso semantico del
/// tema (`danger`, che non è l'accento del marchio e quindi non compete con la
/// CTA), la conferma resta sulla superficie neutra con la sola icona accesa —
/// "è andata, ora guarda la posta" non deve gridare quanto un errore.
class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final _AuthMessage message;

  @override
  Widget build(BuildContext context) {
    final isError = message.isError;
    return Semantics(
      // liveRegion: il riquadro compare *dopo* il tocco, quindi con TalkBack o
      // VoiceOver attivi nessuno lo leggerebbe senza tornare indietro a
      // cercarlo — ed è l'unica spiegazione del perché non si è entrati.
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? AppTheme.danger.withValues(alpha: .12)
              : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isError
                ? AppTheme.danger.withValues(alpha: .45)
                : AppTheme.outline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.mark_email_read_outlined,
              size: 18,
              color: isError ? AppTheme.danger : AppTheme.primary,
            ),
            const SizedBox(width: 10),
            // Expanded: il messaggio arriva da `friendlyError` e può essere
            // lungo una frase intera, quindi deve andare a capo invece di
            // spingere fuori la riga.
            Expanded(
              child: Text(
                message.text,
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga finale che porta all'altra variante (login <-> registrazione).
///
/// Prima era un unico TextButton verde con dentro tutta la frase. Due problemi:
/// la domanda sembrava cliccabile quanto la risposta, e soprattutto un secondo
/// blocco verde a due dita dalla CTA le rubava l'occhio. Qui la domanda è testo
/// normale e solo il verbo è il bersaglio, in bianco pieno: resta evidente che
/// si tocca, senza accendere una seconda cosa nella stessa vista.
class _SwitchLink extends StatelessWidget {
  const _SwitchLink({required this.action, required this.onTap, this.question});

  final String action;
  final VoidCallback onTap;
  final String? question;

  @override
  Widget build(BuildContext context) => Wrap(
    // Wrap e non Row: a 320px con il testo di sistema ingrandito
    // "Non hai un account? Registrati" non ci sta su una riga sola, e una Row
    // rigida qui darebbe la barra gialla e nera dell'overflow.
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (question != null)
        Text(
          question!,
          style: const TextStyle(color: AppTheme.muted, fontSize: 13.5),
        ),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.foreground,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(action),
      ),
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
      color: _googleMarkSurface,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: _googleBlue,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}
