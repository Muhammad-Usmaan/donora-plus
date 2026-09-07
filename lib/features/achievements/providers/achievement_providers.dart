import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// A single donor achievement (milestone or goal completion).
class Achievement {
  const Achievement({
    required this.id,
    required this.donorId,
    required this.achievementType,
    required this.donationType,
    required this.goalValue,
    required this.milestoneCount,
    required this.achievedAt,
    required this.viewed,
  });

  final String id;
  final String donorId;

  /// 'goal_reached' or 'milestone'.
  final String achievementType;

  /// 'whole_blood' or 'platelets' — the donation type that triggered this.
  final String? donationType;

  /// The donor's goal value at time of achievement (goal_reached only).
  final int? goalValue;

  /// The milestone tier (milestone only): 1, 5, 10, or 25.
  final int? milestoneCount;

  final DateTime achievedAt;
  final bool viewed;

  bool get isMilestone => achievementType == 'milestone';
  bool get isGoalReached => achievementType == 'goal_reached';

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id: map['id'] as String? ?? '',
        donorId: map['donor_id'] as String? ?? '',
        achievementType: map['achievement_type'] as String? ?? '',
        donationType: map['donation_type'] as String?,
        goalValue: map['goal_value'] as int?,
        milestoneCount: map['milestone_count'] as int?,
        achievedAt:
            DateTime.tryParse(map['achieved_at'] as String? ?? '') ??
                DateTime.now(),
        viewed: map['viewed'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches a single achievement by ID (owner only — RLS enforced).
final achievementProvider = FutureProvider.family<Achievement?, String>(
  (ref, achievementId) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final client = ref.watch(supabaseClientProvider);
    final response = await client
        .from('achievements')
        .select()
        .eq('id', achievementId)
        .eq('donor_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return Achievement.fromMap(response);
  },
);

/// Fetches all achievements for the current user, newest first.
final achievementsListProvider = FutureProvider<List<Achievement>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('achievements')
      .select()
      .eq('donor_id', user.id)
      .order('achieved_at', ascending: false);

  return response.map((e) => Achievement.fromMap(e)).toList();
});

/// Marks an achievement as viewed.
final markAchievementViewedProvider = Provider<void Function(String)>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (String achievementId) async {
    await client
        .from('achievements')
        .update({'viewed': true})
        .eq('id', achievementId);
  };
});
