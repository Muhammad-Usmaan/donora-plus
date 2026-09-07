import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../home/providers/home_providers.dart';
import '../providers/achievement_providers.dart';

/// Achievements list sub-page for the donor profile.
///
/// Shows all earned achievements (milestones + goal completions) in
/// reverse-chronological order. Tapping an achievement opens the full
/// celebration screen for that specific achievement.
///
/// Empty state shows motivational copy based on whether the donor has
/// set a donation goal.
class AchievementsListScreen extends ConsumerWidget {
  const AchievementsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final achievementsAsync = ref.watch(achievementsListProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Achievements'),
        centerTitle: false,
      ),
      body: achievementsAsync.when(
        data: (achievements) {
          if (achievements.isEmpty) {
            return _EmptyState(profileAsync: profileAsync);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AchievementCard(achievement: achievement),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: colors.textMedium),
                const SizedBox(height: 12),
                Text(
                  'Could not load achievements',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(achievementsListProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Achievement card ──────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      onTap: () => context.pushNamed(
        RouteNames.achievementCelebration,
        pathParameters: {'id': achievement.id},
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: achievement.isMilestone
                  ? const Color(0xFFFFF8E1)
                  : colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              achievement.isMilestone
                  ? Icons.emoji_events_rounded
                  : Icons.favorite_rounded,
              size: 22,
              color: achievement.isMilestone
                  ? colors.warning
                  : colors.primary,
            ),
          ),
          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headline,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Unread dot (if not yet viewed)
          if (!achievement.viewed)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),

          // Chevron
          Icon(
            Icons.chevron_right,
            size: 20,
            color: colors.textMedium,
          ),
        ],
      ),
    );
  }

  String get _headline {
    if (achievement.isMilestone) {
      return '${achievement.milestoneCount ?? 0} Donations';
    }
    return 'Goal of ${achievement.goalValue ?? 0} Reached';
  }

  String get _subtitle {
    if (achievement.isMilestone) {
      return 'Milestone unlocked · ${Formatters.relativeDate(achievement.achievedAt)}';
    }
    return 'Goal complete · ${Formatters.relativeDate(achievement.achievedAt)}';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.profileAsync});

  final AsyncValue<UserProfile> profileAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = profileAsync.valueOrNull;
    final hasGoal = profile?.donationGoal != null;
    final donationGoal = profile?.donationGoal;
    final totalDonations = profile?.totalDonations ?? 0;

    String headline;
    String body;

    if (hasGoal && donationGoal != null) {
      final remaining = donationGoal - totalDonations;
      if (remaining > 0) {
        headline = 'Almost There!';
        body = 'You\'re $remaining donation${remaining == 1 ? '' : 's'} away '
            'from your goal of $donationGoal. Keep going!';
      } else {
        headline = 'No Achievements Yet';
        body = 'Your achievements will appear here as you donate.';
      }
    } else {
      headline = 'Start Earning Achievements';
      body = 'Set a donation goal in Donation Overview to start earning '
          'achievements. Every milestone counts!';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 36,
                color: colors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              headline,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
