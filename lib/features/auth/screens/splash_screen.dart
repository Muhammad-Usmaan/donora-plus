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
            // ── Logo placeholder ──────────────────────────────────────
            const _LogoPlaceholder(),
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

/// Stylized water-drop / heart hybrid logo.
///
/// Shape: two rounded lobes on top (heart), tapering to a point at the
/// bottom (water drop). Rendered entirely with cubic Bézier curves so it
/// scales crisply at any size.
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _LogoPainter(
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Outer shape: water-drop / heart hybrid ──────────────────────
    final path = Path()
      ..moveTo(w * 0.50, h * 0.94)
      // Left side curving up to the left lobe
      ..cubicTo(w * 0.02, h * 0.60, w * 0.00, h * 0.22, w * 0.22, h * 0.10)
      // Left lobe into the centre dip
      ..cubicTo(w * 0.36, h * 0.02, w * 0.47, h * 0.14, w * 0.50, h * 0.22)
      // Centre dip into the right lobe
      ..cubicTo(w * 0.53, h * 0.14, w * 0.64, h * 0.02, w * 0.78, h * 0.10)
      // Right lobe curving down to the bottom point
      ..cubicTo(w * 1.00, h * 0.22, w * 0.98, h * 0.60, w * 0.50, h * 0.94)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    // ── Inner cut-out: small white heart/drop for depth ─────────────
    final inner = Path()
      ..moveTo(w * 0.50, h * 0.72)
      ..cubicTo(w * 0.30, h * 0.50, w * 0.28, h * 0.36, w * 0.38, h * 0.30)
      ..cubicTo(w * 0.44, h * 0.26, w * 0.48, h * 0.33, w * 0.50, h * 0.37)
      ..cubicTo(w * 0.52, h * 0.33, w * 0.56, h * 0.26, w * 0.62, h * 0.30)
      ..cubicTo(w * 0.72, h * 0.36, w * 0.70, h * 0.50, w * 0.50, h * 0.72)
      ..close();

    canvas.drawPath(inner, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
