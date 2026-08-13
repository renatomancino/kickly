class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabase {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        supabasePublishableKey.isNotEmpty;
  }

  static const authCallbackUrl = 'io.kickly.app://login-callback/';
}
