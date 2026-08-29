import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Profile model ─────────────────────────────────────────────────────────────

/// Lightweight representation of the user's profile row in Supabase.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.city,
    required this.activeRole,
    required this.isVerified,
    required this.isTopDonor,
    required this.donorClassification,
    this.phone,
    this.email,
    this.lastDonationDate,
    this.profilePhotoUrl,
    this.totalDonations = 0,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final String activeRole;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;
  final String? phone;
  final String? email;
  final DateTime? lastDonationDate;
  final String? profilePhotoUrl;
  final int totalDonations;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        bloodGroup: map['blood_group'] as String? ?? '',
        city: map['city'] as String? ?? '',
        activeRole: map['active_role'] as String? ?? 'seeker',
        isVerified: map['is_verified'] as bool? ?? false,
        isTopDonor: map['is_top_donor'] as bool? ?? false,
        donorClassification:
            map['donor_classification'] as String? ?? 'volunteer',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        lastDonationDate: map['last_donation_date'] != null
            ? DateTime.tryParse(map['last_donation_date'] as String)
            : null,
        profilePhotoUrl: map['profile_photo_url'] as String?,
        totalDonations: map['total_donations'] as int? ?? 0,
      );
}

// ── Phone normalisation ───────────────────────────────────────────────────

/// Normalises Pakistani phone numbers to the +92XXXXXXXXXX format
/// required by the `profiles.phone` CHECK constraint.
///
/// Accepted inputs:
///   "03001234567"    → "+923001234567"
///   "+923001234567"  → "+923001234567"  (already correct)
///   "00923001234567" → "+923001234567"
///   "923001234567"   → "+923001234567"
///
/// Returns null when the input cannot be parsed so the DB row is still
/// created (phone column allows NULL).
String? normalizePhone(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 11 && digits.startsWith('0')) {
    // Local format: 03001234567
    return '+92${digits.substring(1)}';
  }
  if (digits.length == 12 && digits.startsWith('92')) {
    return '+$digits';
  }
  if (digits.length == 13 && digits.startsWith('0092')) {
    return '+${digits.substring(2)}';
  }
  if (digits.length == 12 && !digits.startsWith('0')) {
    // Already 92XXXXXXXXX without the +
    return '+$digits';
  }
  // Unrecognised format — return null to satisfy the DB constraint.
  return null;
}

// ── User profile provider ─────────────────────────────────────────────────────

/// Fetches the current user's profile row from Supabase.
/// If the row doesn't exist yet (e.g. email-confirmed signup that skipped
/// the profile upsert), it auto-creates one from the auth user metadata.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not signed in');

  final client = ref.watch(supabaseClientProvider);
  var data = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  // Auto-create profile row if it doesn't exist yet.
  if (data == null) {
    final meta = user.userMetadata ?? {};
    final rawPhone = meta['phone'] as String? ?? '';
    final profileRow = {
      'id': user.id,
      'name': meta['full_name'] as String? ?? '',
      'email': user.email ?? '',
      'phone': normalizePhone(rawPhone),
      'active_role': meta['active_role'] as String? ?? 'seeker',
    };
    await client.from('profiles').upsert(profileRow);
    data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  if (data == null) throw Exception('Profile not found');
  return UserProfile.fromMap(data);
});

// ── Nearby verified donors ────────────────────────────────────────────────────

/// Returns up to 10 verified donors for the seeker view.
/// (City-based filtering will be added once geolocation is wired up.)
final nearbyDonorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .select()
      .eq('is_verified', true)
      .eq('active_role', 'donor')
      .limit(10);
});

// ── Seeker's active requests (realtime stream) ──────────────────────────────

/// Realtime stream of active blood requests created by the current user.
/// Updates automatically when new requests are created or existing ones change.
final activeRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final client = ref.watch(supabaseClientProvider);
  return client
      .from('blood_requests')
      .stream(primaryKey: ['id'])
      .eq('requester_id', user.id)
      .eq('status', 'active')
      .order('created_at', ascending: false);
});

// ── Response counts ──────────────────────────────────────────────────────────

/// Number of donors who responded to a given request.
///
/// Used by the home request card ("{N} donors responded"). Per-request
/// count — RLS already scopes responses to the requester or the donor.
final requestResponseCountProvider =
    FutureProvider.family<int, String>((ref, requestId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('request_responses')
      .select('id')
      .eq('request_id', requestId);
  return data.length;
});

// ── Urgent requests (realtime stream for donor view) ──────────────────────────

/// Realtime stream of active + urgent blood requests for the donor view.
final urgentRequestsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('blood_requests')
      .stream(primaryKey: ['id'])
      .eq('status', 'active')
      .eq('is_urgent', true)
      .order('created_at', ascending: false)
      .limit(20);
});

// ── Cooldown status ──────────────────────────────────────────────────────────

/// Computed cooldown status derived from the user's last donation date.
/// Uses the 90-day server-enforced cooldown (never editable client-side).
final cooldownProvider = Provider<CooldownStatus>((ref) {
  final profileAsync = ref.watch(userProfileProvider);

  return profileAsync.whenOrNull(
        data: (profile) {
          if (profile.lastDonationDate == null) {
            return const CooldownStatus(eligible: true);
          }
          final daysSince =
              DateTime.now().difference(profile.lastDonationDate!).inDays;
          final remaining = AppConstants.donationCooldownDays - daysSince;
          return CooldownStatus(
            eligible: remaining <= 0,
            daysRemaining: remaining > 0 ? remaining : 0,
            cooldownDays: AppConstants.donationCooldownDays,
          );
        },
      ) ??
      const CooldownStatus(eligible: true);
});

class CooldownStatus {
  const CooldownStatus({
    this.eligible = true,
    this.daysRemaining = 0,
    this.cooldownDays = 90,
  });

  final bool eligible;
  final int daysRemaining;
  final int cooldownDays;
}
