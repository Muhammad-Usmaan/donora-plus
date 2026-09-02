import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../onboarding/providers/onboarding_provider.dart';

/// Splash screen — brand entry point.
///
/// Full-bleed Neutral-100 background with a centered Donora+ wordmark
/// (water-drop / heart hybrid logo placeholder) and the tagline
/// "Real donors, real time."
///
/// Auto-navigates via GoRouter after checking the Supabase auth session
/// (max 2 s). A small Primary-colored circular loader appears while waiting.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Guarantee the brand mark is visible for at least 1 second.
    await Future<void>.delayed(const Duration(seconds: 1));

    // Wait for the first Supabase auth-state emission (session restore).
    // Times out after 2 s — if no emission, treat as unauthenticated.
    User? user;
    try {
      final state = await ref
          .read(authStateProvider.future)
          .timeout(const Duration(seconds: 2));
      user = state.session?.user;
    } catch (_) {
      user = ref.read(authServiceProvider).currentUser;
    }

    if (!mounted) return;

    if (user != null) {
      // Check if user is suspended before allowing entry.
      try {
        final suspended = await ref
            .read(authServiceProvider)
            .checkSuspended(user.id);
        if (suspended) {
          await ref.read(authServiceProvider).signOut();
          if (!mounted) return;
          context.go(RoutePaths.auth);
          return;
        }
      } catch (_) {
        // If the check fails, allow entry — the periodic monitor
        // in HomeScreen will re-check shortly.
      }
      if (!mounted) return;
      context.go(RoutePaths.home);
    } else {
      final onboardingSeen = ref.read(onboardingSeenProvider);
      context.go(
        onboardingSeen ? RoutePaths.auth : RoutePaths.onboarding,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Brand logo ──────────────────────────────────────────
            Image.asset(
              'assets/images/logo/Donora+ Transparent.png',
              height: 96,
            ),
            const SizedBox(height: 24),

            // ── Wordmark ──────────────────────────────────────────────
            Text(
              'Donora+',
              style: context.textTheme.displayLarge?.copyWith(
                color: colors.primary,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // ── Tagline ──────────────────────────────────────────────
            Text(
              'Real donors, real time.',
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),

            // ── Loader ───────────────────────────────────────────────
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

