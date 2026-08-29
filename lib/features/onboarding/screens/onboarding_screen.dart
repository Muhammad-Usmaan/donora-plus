import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/onboarding_provider.dart';

/// Three-slide horizontal onboarding flow.
///
/// Swipeable PageView with page-indicator dots (active = Primary,
/// inactive = Neutral-300). Slides 1–2 show a "Skip" button in the
/// top-right corner. Slide 3 shows a "Get Started" PrimaryButton.
///
/// Both "Skip" and "Get Started" persist the onboarding-seen flag via
/// [onboardingSeenProvider] and navigate to the Auth screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(RoutePaths.auth);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button (slides 1–2 only) ────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: _currentPage < 2
                    ? TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: context.textTheme.labelLarge?.copyWith(
                            color: colors.textMedium,
                          ),
                        ),
                      )
                    : const SizedBox(height: 48),
              ),
            ),

            // ── PageView ─────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                children: const [
                  _OnboardingSlide(
                    icon: Icons.location_on_outlined,
                    headline: 'Find blood in minutes, not hours',
                    body:
                        'Replace desperate social media appeals with a '
                        'direct connection to verified donors near you. '
                        'Post a request and get matched instantly.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.verified_user_outlined,
                    headline: 'Verified donors near you',
                    body:
                        'Every donor completes CNIC and selfie '
                        'verification. City-scoped matching ensures you '
                        'see only real, reachable donors in your area.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.favorite_border,
                    headline: 'Be someone\u2019s donor',
                    body:
                        'Join a community of lifesavers. Get notified '
                        'when someone nearby needs your blood type and '
                        'make a real difference — every donation counts.',
                  ),
                ],
              ),
            ),

            // ── Page indicator dots ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _PageIndicator(
                count: 3,
                current: _currentPage,
              ),
            ),

            // ── CTA (slide 3 only) ──────────────────────────────────
            if (_currentPage == 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: PrimaryButton(
                  label: 'Get Started',
                  onPressed: _completeOnboarding,
                ),
              ),

            // Bottom safe-area spacing for non-CTA slides.
            if (_currentPage != 2) const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// A single onboarding slide: illustration placeholder + headline + body.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.icon,
    required this.headline,
    required this.body,
  });

  final IconData icon;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // ── Illustration placeholder ──────────────────────────────
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: colors.primary,
            ),
          ),

          const Spacer(flex: 1),

          // ── Headline ──────────────────────────────────────────────
          Text(
            headline,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),

          // ── Body ──────────────────────────────────────────────────
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Row of animated page-indicator dots.
///
/// Active dot: Primary fill, 24 × 8 pill.
/// Inactive dots: Neutral-300 fill, 8 × 8 circle.
/// Transitions are animated with 200 ms ease-in-out.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
