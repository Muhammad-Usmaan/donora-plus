/// Environment configuration loaded via --dart-define at compile time.
///
/// Usage:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
///
/// SECURITY: The Supabase SERVICE ROLE KEY must NEVER be referenced here
/// or anywhere else in the Flutter codebase. It should only exist in
/// server-side functions or edge functions.
class EnvConfig {
  const EnvConfig._();

  /// Supabase project URL (e.g. https://xxxxx.supabase.co)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anonymous/public key (safe to embed in client apps)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Alibaba Cloud / Qwen API key for the chatbot service
  static const String qwenApiKey = String.fromEnvironment(
    'QWEN_API_KEY',
    defaultValue: '',
  );

  /// Whether all required environment variables are present
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
