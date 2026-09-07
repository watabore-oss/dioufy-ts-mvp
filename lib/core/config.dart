class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_URL',
      defaultValue: 'https://TON-PROJET.supabase.co',
    ),
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'TON_ANON_KEY',
      ),
    ),
  );

  static bool get hasSupabaseCredentials =>
      !supabaseUrl.contains('TON-PROJET') &&
      supabaseAnonKey != 'TON_ANON_KEY' &&
      supabaseAnonKey.isNotEmpty;
}
