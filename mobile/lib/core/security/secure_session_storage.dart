import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persiste la sessione Supabase (access token, refresh token) in Keychain su
/// iOS e in un file cifrato con Android Keystore su Android, invece che in
/// `SharedPreferences`/`NSUserDefaults` in chiaro.
///
/// `supabase_flutter` di default usa `SharedPreferencesLocalStorage`: comodo,
/// ma su Android è un XML leggibile da chiunque ottenga accesso alla sandbox
/// dell'app (root, backup non cifrato, un secondo profilo con lo stesso
/// dispositivo compromesso), e su iOS finisce in un plist che sopravvive ai
/// backup iCloud/iTunes senza la protezione aggiuntiva del Keychain. Il
/// refresh token è una credenziale a lunga durata: vale la stessa cura di una
/// password, non quella di una preferenza UI.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required this.persistSessionKey});

  final String persistSessionKey;

  static const _storage = FlutterSecureStorage(
    // Il default di AndroidOptions() cifra già con AES-GCM e avvolge la
    // chiave con RSA via Android Keystore: la chiave non lascia mai
    // l'hardware sicuro del telefono. Non serve alcun parametro esplicito.
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      // Il Keychain resta leggibile solo dopo il primo sblocco e non
      // migra su un dispositivo diverso via backup: se il telefono viene
      // clonato, il token di sessione non lo segue.
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);
}
