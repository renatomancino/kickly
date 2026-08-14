import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Nonce per il flusso "Sign in with Apple", nella forma che Apple e Supabase
/// si aspettano.
///
/// Apple firma l'ID token includendo l'hash SHA-256 del nonce che gli viene
/// passato, non il nonce in chiaro. Il client deve quindi generare un nonce
/// casuale, mandarne l'hash ad Apple nella richiesta di autorizzazione, e poi
/// passare il nonce **in chiaro** a `signInWithIdToken`: è Supabase a
/// ricalcolare l'hash e confrontarlo con quello dentro il token, per
/// verificare che l'ID token sia stato emesso per *questa* richiesta e non
/// rigiocato da un'altra.
///
/// Non esiste un equivalente di `supabase.auth.generateRawNonce()` in questa
/// versione di gotrue: il nonce va generato a mano con un generatore
/// crittograficamente sicuro, come documentato nella guida ufficiale Supabase
/// per Sign in with Apple su Flutter.
class OAuthNonce {
  const OAuthNonce._({required this.raw, required this.hashed});

  /// Genera una coppia nonce/hash pronta per la richiesta ad Apple.
  ///
  /// [raw] va passato a `signInWithIdToken`, [hashed] va passato come `nonce`
  /// nella richiesta `SignInWithApple.getAppleIDCredential`.
  factory OAuthNonce.generate({int length = 32}) {
    // Random.secure() usa il CSPRNG del sistema operativo (non un PRNG
    // seedato in modo prevedibile): è la stessa garanzia richiesta per un
    // token di sessione, non quella di un normale Random() per la UI.
    final random = Random.secure();
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final raw = List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
    final hashed = sha256.convert(utf8.encode(raw)).toString();
    return OAuthNonce._(raw: raw, hashed: hashed);
  }

  /// Da passare a `signInWithIdToken(nonce: ...)`.
  final String raw;

  /// Da passare ad Apple come `nonce` della richiesta di autorizzazione.
  final String hashed;
}
