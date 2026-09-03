import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Full public-facing donor profile.
///
/// Privacy note: CNIC images and raw verification documents are admin-only
/// and NEVER included in this model. Phone/email are part of the
/// RLS-readable profiles row and only back the masked contact line and
/// Call Now action on the seeker-facing profile screen.
class DonorProfile {
  const DonorProfile({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.city,
    required this.isVerified,
    required this.isTopDonor,
    required this.donorClassification,
    required this.activeRole,
    this.profilePhotoUrl,
    this.bio,
    this.totalDonations,
    this.lastDonationDate,
    this.showLastDonationDate = false,
    this.phone,
    this.email,
    this.hemoglobinLevel,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;

  /// Current app mode: 'donor' or 'seeker'.
  final String activeRole;
  final String? profilePhotoUrl;
  final String? bio;
  final int? totalDonations;
  final DateTime? lastDonationDate;

  /// Whether the donor has opted to make last donation date public.
  final bool showLastDonationDate;

  /// Raw contact fields. Phone backs the masked contact line and the
  /// Call Now action; email is shown when no phone is on file.
  final String? phone;
  final String? email;

  /// Self-reported hemoglobin level (g/dL). Null when the donor hasn't
  /// filled it in — the seeker-facing view should hide the line entirely.
  final double? hemoglobinLevel;

  final double? latitude;
  final double? longitude;

  /// Whether this donor can plausibly donate right now: they must be in
  /// donor mode, and — when their last donation date is public — at least
  /// 90 days must have passed since it.
  bool get isAvailableToDonate {
    if (activeRole != 'donor') return false;
    if (!showLastDonationDate) return true;
    final last = lastDonationDate;
    if (last == null) return true;
    // UTC-only math to stay consistent with the Supabase admin panel.
    final nowUtc = DateTime.now().toUtc();
    final lastUtc = last.toUtc();
    final daysSince = DateTime.utc(
          nowUtc.year, nowUtc.month, nowUtc.day,
        ).difference(
          DateTime.utc(lastUtc.year, lastUtc.month, lastUtc.day),
        ).inDays;
    return daysSince >= 90;
  }

  factory DonorProfile.fromMap(Map<String, dynamic> map) => DonorProfile(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown',
        bloodGroup: map['blood_group'] as String? ?? '',
        city: map['city'] as String? ?? '',
        isVerified: map['is_verified'] as bool? ?? false,
        isTopDonor: map['is_top_donor'] as bool? ?? false,
        donorClassification:
            map['donor_classification'] as String? ?? 'volunteer',
        activeRole: map['active_role'] as String? ?? 'donor',
        profilePhotoUrl: map['profile_photo_url'] as String?,
        bio: map['bio'] as String?,
        totalDonations: map['total_donations'] as int?,
        lastDonationDate: map['last_donation_date'] != null
            ? DateTime.tryParse(map['last_donation_date'] as String)?.toUtc()
            : null,
        showLastDonationDate:
            map['show_last_donation_date'] as bool? ?? false,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        hemoglobinLevel: map['hemoglobin_level'] != null
            ? (map['hemoglobin_level'] as num).toDouble()
            : null,
        latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
        longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches a donor's public profile by ID.
final donorDetailProvider =
    FutureProvider.family<DonorProfile, String>((ref, donorId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('profiles_public')
      .select()
      .eq('id', donorId)
      .maybeSingle();

  if (data == null) throw Exception('Donor not found');
  return DonorProfile.fromMap(data);
});

/// Checks whether this donor has an active response to any of the viewer's
/// active requests. Returns the request ID if found, or null otherwise.
///
/// Used to conditionally show the "View Response" button on the donor
/// detail screen. Returns null if the `request_responses` table doesn't
/// exist yet (graceful fallback).
final donorResponseToViewerProvider =
    FutureProvider.family<String?, String>((ref, donorId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);

  try {
    // 1. Get the viewer's active request IDs.
    final myRequests = await client
        .from('blood_requests')
        .select('id')
        .eq('requester_id', user.id)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

    if ((myRequests as List).isEmpty) return null;

    final requestIds = myRequests.map((r) => r['id'] as String).toList();

    // 2. Check if this donor responded to any of those requests.
    final responses = await client
        .from('request_responses')
        .select('request_id')
        .eq('donor_id', donorId)
        .inFilter('request_id', requestIds)
        .limit(1);

    if ((responses as List).isEmpty) return null;
    return responses.first['request_id'] as String?;
  } on PostgrestException catch (e) {
    // Table doesn't exist yet — graceful fallback.
    if (e.code == '42P01' || e.message.contains('does not exist')) {
      return null;
    }
    return null;
  } catch (_) {
    return null;
  }
});

/// Number of blood requests this donor has responded to.
///
/// request_responses is RLS-restricted (donors see only their own rows,
/// seekers only responses to their own requests), so the count comes from
/// the `donor_response_count` SECURITY DEFINER aggregate. Falls back to 0
/// when the function is unavailable (e.g. migration not yet applied).
final donorResponseCountProvider =
    FutureProvider.family<int, String>((ref, donorId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await client.rpc(
      'donor_response_count',
      params: {'p_donor_id': donorId},
    );
    return (result as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});
