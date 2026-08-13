import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/kickly_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  final config = AppConfig.fromEnvironment();
  SupabaseClient? client;

  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    client = Supabase.instance.client;
  }

  final repository = KicklyRepository(client: client);
  final appState = AppState(repository: repository);
  await appState.initialize();

  runApp(KicklyApp(appState: appState, repository: repository, config: config));
}
