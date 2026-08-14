class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.googleServerClientId = '',
    this.googleIosClientId = '',
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      // Client ID "Web" da Google Cloud Console: determina l'audience
      // dell'ID token e va registrato anche come "Authorized Client ID" nel
      // provider Google di Supabase Dashboard. Vedi il README per i passi.
      googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
      // Client ID "iOS": serve solo su iOS per costruire il redirect nativo.
      // Su Android non serve, Play Services riconosce l'app da package name
      // e firma del certificato registrati nella console Google.
      googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String googleServerClientId;
  final String googleIosClientId;

  bool get hasSupabase {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        supabasePublishableKey.isNotEmpty;
  }

  /// Senza il Client ID Web non c'è audience per l'ID token: il pulsante
  /// Google resta nascosto invece di aprire un flusso che fallirebbe sempre,
  /// stesso pattern di [hasSupabase] per la demo locale.
  bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;

  static const authCallbackUrl = 'io.kickly.app://login-callback/';
}
