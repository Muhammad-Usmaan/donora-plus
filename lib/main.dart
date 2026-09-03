import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/notifications/providers/notification_settings_provider.dart';
import 'firebase_options.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications/fcm_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Diagnostic: log env config presence (masked) before any init. ──
  // In release, view with:  flutter logs  /  adb logcat | grep donora
  // These prints are stripped by tree-shaking in --obfuscate builds.
  final keyLen = EnvConfig.supabaseAnonKey.length;
  debugPrint('Supabase anon key: ${keyLen > 0 ? "${keyLen} chars" : "(empty)"}');
 

  try {
    // Firebase Core is only needed for FCM push notifications.
    // firebase_options.dart is derived from google-services.json /
    // GoogleService-Info.plist; re-run `flutterfire configure` to regenerate.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init skipped — FCM will be unavailable: $e');
    }

    // Initialize Supabase (must happen before runApp).
    // URL and anon key are injected via --dart-define at compile time.
    // In release builds these values are NOT available unless the build
    // command includes --dart-define-from-file=.env (or equivalent flags).
    // See build.sh / build.ps1 for the correct release build commands.
    if (!EnvConfig.isConfigured) {
      throw StateError(
        'Supabase configuration is incomplete. '
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via '
        '--dart-define or --dart-define-from-file=.env at build time. '
        'Example: flutter build apk --release --dart-define-from-file=.env',
      );
    }

    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    // Local preferences (notification settings, etc.).
    final prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const DonoraPlusApp(),
      ),
    );
  } catch (error, stack) {
    // Catch every startup failure and render a visible error screen
    // instead of letting the process die silently (release mode has
    // no red error overlay).  The app stays alive so the user sees
    // *something* and the developer sees the message in logs.
   
    debugPrint('$stack');

    runApp(_StartupErrorApp(error: error, stack: stack));
  }
}

/// Root widget wrapped in ProviderScope (Riverpod) for global state.
class DonoraPlusApp extends ConsumerWidget {
  const DonoraPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // FCM lifecycle: permission, token sync, foreground banners, deep links.
    // Watching here keeps the listeners alive for the entire session.
    ref.watch(fcmBootstrapProvider);

    // OS-level deep links (password-reset callback, etc.).
    DeepLinkHandler.start();

    return MaterialApp.router(
      title: 'Donora+',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

/// Fallback app shown when startup (Supabase / Firebase / etc.) fails.
/// Renders a minimal error screen so the app never crash-loops to a
/// blank/white screen in release mode.
class _StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;

  const _StartupErrorApp({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donora+',
      debugShowCheckedModeBanner: false,
      home: _StartupErrorScreen(error: error, stack: stack),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace stack;

  const _StartupErrorScreen({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    // Mask the anon key in the displayed message if it partially loaded.
    // In release builds, show a generic message to avoid leaking internals.
    final message = kReleaseMode
        ? 'An unexpected error occurred during startup.\n\n${error.toString()}'
        : error.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Startup Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    kReleaseMode
                        ? message
                        : '$message\n\nStack trace:\n$stack',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'If this is a release build, ensure you built with:\n'
                'flutter build apk --release --dart-define-from-file=.env',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
