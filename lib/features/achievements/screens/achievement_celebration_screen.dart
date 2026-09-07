import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/extensions.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/widgets/profile_dialogs.dart';
import '../providers/achievement_providers.dart';

/// Full-screen celebratory view shown when a donor earns an achievement.
///
/// Background art is selected based on [Achievement.donationType]:
///   - whole_blood → blood-themed image (dark crimson)
///   - platelets   → platelet-themed image (dark teal)
///
/// A dark-to-transparent gradient overlay is applied in code for text
/// legibility regardless of the source image.
///
/// Text content is dynamic per [Achievement.achievementType]:
///   - 'milestone'    → "Milestone Unlocked!" + count
///   - 'goal_reached' → "You're a Hero" + goal value
class AchievementCelebrationScreen extends ConsumerStatefulWidget {
  const AchievementCelebrationScreen({super.key, required this.achievementId});

  final String achievementId;

  @override
  ConsumerState<AchievementCelebrationScreen> createState() =>
      _AchievementCelebrationScreenState();
}

class _AchievementCelebrationScreenState
    extends ConsumerState<AchievementCelebrationScreen> {
  @override
  void initState() {
    super.initState();
    // Mark as viewed when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAchievementViewedProvider)(widget.achievementId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final achievementAsync = ref.watch(
      achievementProvider(widget.achievementId),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: achievementAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => const _ErrorBody(),
        data: (achievement) {
          if (achievement == null) return const _ErrorBody();
          return _CelebrationBody(
            achievement: achievement,
            onDismiss: () => _handleDismiss(context, achievement),
            onShare: () => _shareAchievement(context, achievement),
          );
        },
      ),
    );
  }

  void _shareAchievement(BuildContext context, Achievement achievement) {
    final String text;
    if (achievement.isMilestone) {
      text = 'I just hit ${achievement.milestoneCount} donations on Donora+! '
          'Every donation saves a life. 💉';
    } else {
      text = 'I reached my goal of ${achievement.goalValue} donations on '
          'Donora+! 🩸';
    }
    Share.share(text);
  }

  /// Handles dismissal: pops the screen, then shows the goal-edit sheet
  /// if this was a goal_reached achievement (not milestone).
  void _handleDismiss(BuildContext context, Achievement achievement) {
    Navigator.of(context).pop();

    // Only prompt for a new goal after goal_reached, not milestones.
    if (achievement.isGoalReached && context.mounted) {
      // Fetch the latest profile to get the current goal.
      ref.read(userProfileProvider.future).then((profile) {
        if (context.mounted) {
          showGoalEditSheet(
            context,
            ref: ref,
            currentGoal: profile.donationGoal,
            headerText: 'Ready for your next goal?',
          );
        }
      });
    }
  }
}

// ── Celebration body ──────────────────────────────────────────────────────────

class _CelebrationBody extends StatelessWidget {
  const _CelebrationBody({
    required this.achievement,
    required this.onDismiss,
    required this.onShare,
  });

  final Achievement achievement;
  final VoidCallback onDismiss;
  final VoidCallback onShare;

  /// Selects background image based on donation_type.
  /// Exactly 2 images total — text differentiates achievements of the
  /// same type, not unique art per tier.
  String get _backgroundAsset {
    // Handle both DB values ('whole_blood') and RPC values ('blood')
    if (achievement.donationType == 'platelets' ||
        achievement.donationType == 'platelet') {
      return 'assets/images/achievements/achievement_platelet.jpg';
    }
    return 'assets/images/achievements/achievement_blood.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere to dismiss.
      onTap: onDismiss,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // ── Layer 1: Full-screen cover image ────────────────────────
            Positioned.fill(
              child: Image.asset(
                _backgroundAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black87),
              ),
            ),

            // ── Layer 2: Dark-to-transparent gradient overlay ───────────
            // Darkest at bottom (where text sits), fading upward.
            // Applied in code so it works with any source image.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [
                      0.0, // transparent at top
                      0.45, // still mostly transparent by ~45%
                      0.75, // darkening toward bottom
                      1.0, // darkest at very bottom
                    ],
                    colors: const [
                      Colors.black54,
                      Colors.black26,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
            ),

            // ── Layer 3: Share button (top-right) ───────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

            // ── Layer 4: Content ────────────────────────────────────────
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Badge icon
                      _buildBadgeIcon(context),
                      const SizedBox(height: 24),

                      // Headline
                      Text(
                        _headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Body text
                      Text(
                        _bodyText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),

                      const Spacer(flex: 4),

                      // Tap-to-continue hint
                      Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(BuildContext context) {
    final colors = context.colors;

    if (achievement.isMilestone) {
      // Trophy / star icon for milestones
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.warning.withValues(alpha: 0.2),
          border: Border.all(
            color: colors.warning.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.emoji_events_rounded,
          size: 48,
          color: colors.warning,
        ),
      );
    } else {
      // Heart icon for goal completion
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primary.withValues(alpha: 0.2),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.favorite_rounded,
          size: 48,
          color: colors.primary,
        ),
      );
    }
  }

  // ── Dynamic text per achievement_type ────────────────────────────────────

  String get _headline {
    if (achievement.isMilestone) {
      return 'Milestone Unlocked!';
    }
    // goal_reached
    return "You're a Hero";
  }

  String get _bodyText {
    if (achievement.isMilestone) {
      final count = achievement.milestoneCount ?? 0;
      return 'You\'ve completed $count donations. '
          'Every one saved a life.';
    }
    // goal_reached
    final goal = achievement.goalValue ?? 0;
    return 'You\'ve reached your goal of $goal donations. '
        'Your commitment to helping others is incredible.';
  }
}

// ── Error fallback ────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'Could not load this achievement.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
