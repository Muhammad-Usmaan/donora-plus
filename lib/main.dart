import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Core is only needed for FCM push notifications.
  // If google-services.json / GoogleService-Info.plist hasn't been
  // configured yet, skip Firebase init — the rest of the app works fine.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped — FCM will be unavailable: $e');
  }

  // Initialize Supabase (must happen before runApp).
  // URL and anon key are injected via --dart-define at compile time.
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: DonoraPlusApp(),
    ),
  );
}

/// Root widget wrapped in ProviderScope (Riverpod) for global state.
class DonoraPlusApp extends ConsumerWidget {
  const DonoraPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Donora+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
