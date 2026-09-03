/// Environment configuration loaded via --dart-define at compile time.
///
/// Values are baked into the binary at build time. They are NOT read from
/// disk at runtime, so the build command MUST supply them:
///
///   # Debug (VS Code launch.json handles this automatically)
///   flutter run --dart-define-from-file=.env
///
///   # Release (use the helper scripts: build.sh / build.ps1)
///   flutter build apk --release --dart-define-from-file=.env
///
/// If these values are empty in a release build the app will throw a
/// StateError at startup with a descriptive message — see main().
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

  /// Custom URL scheme used for deep links (password reset, etc.).
  ///
  /// Must match the scheme registered in:
  ///   • `AndroidManifest.xml` — `<intent-filter>` `<data android:scheme="...">`
  ///   • `Info.plist` — `CFBundleURLSchemes`
  ///   • Supabase dashboard — Authentication > URL Configuration > Redirect URLs
  static const String appUrlScheme = String.fromEnvironment(
    'https://donoraplus.vercel.app',
    defaultValue: 'donora-plus',
  );

  /// Base URL of the web frontend — used to build auth redirect URLs.
  /// Must exactly match the Site URL configured in the Supabase dashboard.
  static const String webBaseUrl = 'https://donoraplus.vercel.app';

  /// Redirect URL for email confirmation after signup.
  /// Must exactly match an entry in Supabase dashboard > Redirect URLs.
  static const String emailConfirmRedirectUrl =
      '$webBaseUrl/account-confirmed';

  /// Redirect URL for password-reset emails.
  /// Must exactly match an entry in Supabase dashboard > Redirect URLs.
  static const String passwordResetRedirectUrl =
      '$webBaseUrl/reset-password';

  /// Whether all required environment variables are present
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
