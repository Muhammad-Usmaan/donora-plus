import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Full public-facing donor profile.
///
/// Privacy note: CNIC images and raw verification documents are admin-only
/// and NEVER included in this model. Only fields approved for public display
/// are exposed.
class DonorProfile {
  const DonorProfile({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.city,
    required this.isVerified,
    required this.isTopDonor,
    required this.donorClassification,
    this.profilePhotoUrl,
    this.bio,
    this.totalDonations,
    this.lastDonationDate,
    this.showLastDonationDate = false,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;
  final String? profilePhotoUrl;
  final String? bio;
  final int? totalDonations;
  final DateTime? lastDonationDate;

  /// Whether the donor has opted to make last donation date public.
  final bool showLastDonationDate;

  factory DonorProfile.fromMap(Map<String, dynamic> map) => DonorProfile(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown',
        bloodGroup: map['blood_group'] as String? ?? '',
        city: map['city'] as String? ?? '',
        isVerified: map['is_verified'] as bool? ?? false,
        isTopDonor: map['is_top_donor'] as bool? ?? false,
        donorClassification:
            map['donor_classification'] as String? ?? 'volunteer',
        profilePhotoUrl: map['profile_photo_url'] as String?,
        bio: map['bio'] as String?,
        totalDonations: map['total_donations'] as int?,
        lastDonationDate: map['last_donation_date'] != null
            ? DateTime.tryParse(map['last_donation_date'] as String)
            : null,
        showLastDonationDate:
            map['show_last_donation_date'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches a donor's public profile by ID.
final donorDetailProvider =
    FutureProvider.family<DonorProfile, String>((ref, donorId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('profiles')
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
        .eq('status', 'active');

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
