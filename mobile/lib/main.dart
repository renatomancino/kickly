import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/secure_session_storage.dart';
import 'data/kickly_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  // Prima di runApp: se l'app è stata aperta toccando una notifica, il link di
  // destinazione dev'essere già disponibile quando il router fa il primo
  // redirect, altrimenti l'utente atterra sulla dashboard e il tap si perde.
  await NotificationService.instance.initialize();

  final config = AppConfig.fromEnvironment();
  SupabaseClient? client;

  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // Access e refresh token in Keychain/Keystore invece che in
        // SharedPreferences in chiaro. La chiave replica il formato che
        // supabase_flutter userebbe di default, per restare coerente se in
        // futuro si volesse fare l'inverso.
        localStorage: SecureSessionStorage(
          persistSessionKey:
              'sb-${Uri.parse(config.supabaseUrl).host.split('.').first}-auth-token',
        ),
      ),
    );
    client = Supabase.instance.client;
  }

  // GoogleSignIn.instance.initialize() va chiamato esattamente una volta,
  // prima di qualunque altro metodo sull'istanza: farlo qui invece che al
  // primo tap sul pulsante evita una race fra due tocchi ravvicinati e tiene
  // l'inizializzazione lontana dal percorso critico della UI.
  if (config.hasGoogleSignIn) {
    await GoogleSignIn.instance.initialize(
      serverClientId: config.googleServerClientId,
      clientId: config.googleIosClientId.isEmpty
          ? null
          : config.googleIosClientId,
    );
  }

  final repository = KicklyRepository(client: client);
  final appState = AppState(repository: repository);
  await appState.initialize();

  runApp(KicklyApp(appState: appState, repository: repository, config: config));
}
