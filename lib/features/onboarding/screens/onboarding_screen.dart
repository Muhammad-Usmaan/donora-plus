import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/onboarding_provider.dart';

/// Three-slide onboarding with a circular photo hero on a brand-red
/// panel and a rounded content sheet.
///
/// Layout per slide:
/// - Top ~55%: primary-colored hero panel with a circular-masked photo
///   (≈78% of panel width) whose bottom edge dips slightly past the
///   seam into the content sheet for depth.
/// - Bottom ~45%: surface sheet with 28px rounded top corners holding
///   the left-aligned headline + subtext, page dots and a pill CTA
///   ("Continue" on slides 1–2, "Get Started" on the last).
///
/// Slides 1–2 expose a "Skip" text button (top-right). Both "Skip" and
/// "Get Started" persist the onboarding-seen flag via
/// [onboardingSeenProvider] and navigate to the Auth screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

// ── Shared layout constants ─────────────────────────────────────────────

/// Hero panel height as a fraction of the screen.
const double _heroFraction = 0.55;

/// Circle diameter as a fraction of the panel (screen) width.
const double _circleWidthFraction = 0.78;

/// How far the circle's bottom edge dips below the hero/sheet seam.
const double _seamDip = 28.0;

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  /// Slide content — swap images/copy here without touching layout.
  static const _slides = [
    _OnboardingSlideData(
      image: AssetImage(
        'assets/images/onboarding/akram-huseyn-fKC9eWRnlGY-unsplash.jpg',
      ),
      headline: 'Verified Donors, Every Time',
      body:
          'Every donor on Donora+ is checked and confirmed, so you can trust every match.',
    ),
    _OnboardingSlideData(
      image: AssetImage(
        'assets/images/onboarding/aman-chaturvedi-0ZZo5o00o80-unsplash.jpg',
      ),
      headline: 'One Donation, One Life Saved',
      body:
          'A single unit of blood can mean the difference between waiting and surviving.',
    ),
    _OnboardingSlideData(
      image: AssetImage(
        'assets/images/onboarding/tim-marshall-cAtzHUz7Z8g-unsplash.jpg',
      ),
      headline: 'A Network Built on People',
      body:
          'Real donors, ready to help — no waiting on a viral post to save a life.',
    ),
  ];

  bool get _isLastSlide => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(RoutePaths.auth);
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mq = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar sits on the brand-red hero panel → light icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.primary,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final panelHeight = constraints.maxHeight * _heroFraction;
            final circleDiameter = constraints.maxWidth * _circleWidthFraction;
            final circleBottom = panelHeight + _seamDip;
            final circleTop = (circleBottom - circleDiameter).clamp(
              0.0,
              panelHeight,
            );

            return Stack(
              children: [
                // ── Content sheet (overlaps the hero panel) ──────────
                Positioned(
                  top: panelHeight,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                  ),
                ),

                // ── Slides (image + copy swap per page) ───────────────
                PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: [
                    for (final slide in _slides)
                      _OnboardingSlide(
                        slide: slide,
                        panelHeight: panelHeight,
                        circleTop: circleTop,
                        circleDiameter: circleDiameter,
                        // Reserve room for the static dots + CTA footer.
                        footerHeight: mq.padding.bottom + 116,
                      ),
                  ],
                ),

                // ── Skip button (slides 1–2 only) ────────────────────
                Positioned(
                  top: mq.padding.top + 8,
                  right: 16,
                  child: _currentPage < _slides.length - 1
                      ? TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'Skip',
                            style: context.textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : const SizedBox(height: 48),
                ),

                // ── Page dots + CTA (static below swiping content) ───
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: mq.padding.bottom + 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageIndicator(
                        count: _slides.length,
                        current: _currentPage,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: _isLastSlide ? 'Get Started' : 'Continue',
                        radius: 16,
                        onPressed: _isLastSlide
                            ? _completeOnboarding
                            : _nextPage,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Per-slide content: image, headline and body copy.
class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.image,
    required this.headline,
    required this.body,
  });

  /// Circular hero photo — asset or network image, swappable per slide.
  final ImageProvider image;
  final String headline;
  final String body;
}

/// A single onboarding slide: circular photo at the hero/sheet seam
/// plus left-aligned headline and subtext on the sheet.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.slide,
    required this.panelHeight,
    required this.circleTop,
    required this.circleDiameter,
    required this.footerHeight,
  });

  final _OnboardingSlideData slide;
  final double panelHeight;
  final double circleTop;
  final double circleDiameter;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Circular hero photo, dipping past the seam ─────────────
        Positioned(
          top: circleTop,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: circleDiameter,
              height: circleDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(image: slide.image, fit: BoxFit.cover),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Headline + subtext (left-aligned, below the circle) ────
        Positioned(
          top: panelHeight + _seamDip + 20,
          left: 24,
          right: 24,
          bottom: footerHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  // Scales down gracefully on short screens.
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.headlineLarge?.copyWith(
                            fontSize: 27,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
