import 'dart:async';
import 'dart:math' show sqrt, sin, cos, atan2, pi;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.isSuspended = false,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.lastDonationDate,
    this.profilePhotoUrl,
    this.totalDonations = 0,
    this.hemoglobinLevel,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final String activeRole;
  final bool isVerified;
  final bool isTopDonor;
  final bool isSuspended;
  final String donorClassification;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final DateTime? lastDonationDate;
  final String? profilePhotoUrl;
  final int totalDonations;
  final double? hemoglobinLevel;
  final double? latitude;
  final double? longitude;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    bloodGroup: map['blood_group'] as String? ?? '',
    city: map['city'] as String? ?? '',
    activeRole: map['active_role'] as String? ?? 'seeker',
    isVerified: map['is_verified'] as bool? ?? false,
    isTopDonor: map['is_top_donor'] as bool? ?? false,
    isSuspended: map['is_suspended'] as bool? ?? false,
    donorClassification: map['donor_classification'] as String? ?? 'volunteer',
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    dateOfBirth: map['date_of_birth'] != null
        ? DateTime.tryParse(map['date_of_birth'] as String)
        : null,
    lastDonationDate: map['last_donation_date'] != null
        ? DateTime.tryParse(map['last_donation_date'] as String)?.toUtc()
        : null,
    profilePhotoUrl: map['profile_photo_url'] as String?,
    totalDonations: map['total_donations'] as int? ?? 0,
    hemoglobinLevel: map['hemoglobin_level'] != null
        ? (map['hemoglobin_level'] as num).toDouble()
        : null,
    latitude: map['latitude'] != null
        ? (map['latitude'] as num).toDouble()
        : null,
    longitude: map['longitude'] != null
        ? (map['longitude'] as num).toDouble()
        : null,
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
/// Returns null when the input cannot be parsed.
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

// ── User profile provider (realtime with retry + REST fallback) ──────────────
//
// Architecture:
//   1. Immediate REST fetch to show data without waiting for Realtime.
//   2. Explicit Postgres Realtime channel for live updates (not .stream()).
//   3. Exponential-backoff retry (2 s → 4 s → 8 s → …) if the channel errors.
//   4. After [maxRetries] consecutive failures the REST data is kept and no
//      error state is surfaced — realtime is an enhancement, not a requirement.
//   5. The channel is torn down on provider disposal (logout / screen change)
//      so no orphaned subscriptions accumulate.

final userProfileProvider = StreamProvider<UserProfile>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final client = ref.watch(supabaseClientProvider);

  // ── Helper: fetch profile via REST ──────────────────────────────────────
  Future<UserProfile?> fetchProfileRest() async {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data != null) return UserProfile.fromMap(data);
    return null;
  }

  // ── 1. Auto-create profile row if it doesn't exist yet ──────────────────
  var data = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) {
    final meta = user.userMetadata ?? {};
    final rawPhone = meta['phone'] as String? ?? '';
    final normalizedPhone = normalizePhone(rawPhone);
    final profileRow = <String, dynamic>{
      'id': user.id,
      'name': meta['full_name'] as String? ?? '',
      'email': user.email ?? '',
      'phone': normalizedPhone,
      'active_role': meta['active_role'] as String? ?? 'seeker',
      'blood_group': meta['blood_group'] as String?,
      'city': meta['city'] as String?,
      'donor_classification': meta['donor_classification'] as String?,
      'date_of_birth': meta['date_of_birth'] as String?,
      'latitude': meta['latitude'] != null
          ? (meta['latitude'] as num).toDouble()
          : null,
      'longitude': meta['longitude'] != null
          ? (meta['longitude'] as num).toDouble()
          : null,
    };
    try {
      await client.from('profiles').upsert(profileRow);
    } catch (_) {}
    data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  // ── 2. Emit initial data from REST so the UI renders immediately ────────
  UserProfile? lastProfile;
  if (data != null) {
    lastProfile = UserProfile.fromMap(data);
    yield lastProfile;
  }

  // ── 3. Channel-based realtime with retry + exponential backoff ──────────
  const maxRetries = 5;
  const baseDelay = Duration(seconds: 2);

  final controller = StreamController<UserProfile>();
  RealtimeChannel? channel;
  Timer? retryTimer;
  int retryCount = 0;
  bool realtimeExhausted = false;

  void subscribeToRealtime() {
    if (controller.isClosed || realtimeExhausted) return;

    debugPrint(
      '[userProfileProvider] Subscribing to profiles realtime '
      '(attempt ${retryCount + 1}/$maxRetries)',
    );

    channel = client
        .channel('profiles:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) async {
            try {
              // Re-fetch via REST to get the full row (payload may be partial).
              final updated = await fetchProfileRest();
              if (updated != null && !controller.isClosed) {
                lastProfile = updated;
                controller.add(updated);
              }
            } catch (e) {
              debugPrint(
                '[userProfileProvider] Error in realtime callback: $e',
              );
            }
          },
        )
        .subscribe(
      (status, error) {
        debugPrint(
          '[userProfileProvider] Channel status: $status'
          '${error != null ? ', error: $error' : ''}',
        );

        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            // Connected — reset retry counter.
            retryCount = 0;
            debugPrint(
              '[userProfileProvider] Realtime subscribed for '
              'profiles id=${user.id}',
            );
          case RealtimeSubscribeStatus.channelError:
            // Channel errored — retry with exponential backoff.
            retryCount++;
            debugPrint(
              '[userProfileProvider] Channel error '
              '(retry $retryCount/$maxRetries): $error',
            );
            if (retryCount >= maxRetries) {
              realtimeExhausted = true;
              debugPrint(
                '[userProfileProvider] Realtime retries exhausted — '
                'falling back to REST-only mode. '
                'Last error: $error',
              );
              // Keep showing the last REST-fetched profile — do NOT
              // push an error state. Realtime is an enhancement.
              return;
            }
            final delay = baseDelay * (1 << (retryCount - 1)); // 2s,4s,8s…
            retryTimer = Timer(delay, () {
              if (!controller.isClosed) {
                // Remove the broken channel before retrying.
                if (channel != null) {
                  client.removeChannel(channel!);
                  channel = null;
                }
                subscribeToRealtime();
              }
            });
          case RealtimeSubscribeStatus.timedOut:
            debugPrint(
              '[userProfileProvider] Channel timed out — retrying…',
            );
            retryCount++;
            if (retryCount < maxRetries) {
              retryTimer = Timer(baseDelay, () {
                if (!controller.isClosed) {
                  if (channel != null) {
                    client.removeChannel(channel!);
                    channel = null;
                  }
                  subscribeToRealtime();
                }
              });
            }
          case RealtimeSubscribeStatus.closed:
            break;
        }
      },
    );
  }

  // Kick off the realtime subscription.
  subscribeToRealtime();

  // ── 4. Cleanup on disposal (logout / provider invalidation) ─────────────
  ref.onDispose(() {
    retryTimer?.cancel();
    if (channel != null) {
      client.removeChannel(channel!);
    }
    controller.close();
    debugPrint('[userProfileProvider] Disposed — channel removed');
  });

  // Forward realtime updates to the StreamProvider.
  yield* controller.stream;
});

// ── Nearby verified donors ────────────────────────────────────────────────────

/// Returns up to 10 verified donors for the seeker view, excluding the current user.
final nearbyDonorsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);

  var query = client
      .from('profiles_public')
      .select()
      .eq('is_verified', true)
      .eq('active_role', 'donor');

  if (user != null) {
    query = query.neq('id', user.id);
  }

  return query.limit(10);
});

// ── Seeker's active requests (realtime stream) ──────────────────────────────

/// Realtime stream of active blood requests created by the current user.
/// Updates automatically when new requests are created or existing ones change.
///
/// Client-side expiry filter: the DB status may lag behind `expires_at` when
/// the scheduled expiry job hasn't run yet, so we filter out requests whose
/// `expires_at` has already passed to keep the "Active" section accurate.
final activeRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final client = ref.watch(supabaseClientProvider);
  return client
      .from('blood_requests')
      .stream(primaryKey: ['id'])
      .eq('requester_id', user.id)
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .map((requests) {
    final now = DateTime.now().toUtc();
    return requests.where((r) {
      final expiresAt = DateTime.tryParse(r['expires_at'] as String? ?? '');
      return expiresAt == null || expiresAt.isAfter(now);
    }).toList();
  });
});

// ── In-progress donations (seeker view) ─────────────────────────────────────

/// Realtime stream of the seeker's accepted blood requests where a donor
/// has been matched but the donation hasn't been confirmed yet.
///
/// Each map is enriched with the matched donor's profile (name, blood_group,
/// profile_photo_url) resolved via `fulfilled_by_donor_id`.
final inProgressDonationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final client = ref.watch(supabaseClientProvider);

  // ── Fetch helper ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchInProgress() async {
    final rows = await client
        .from('blood_requests')
        .select('*')
        .eq('requester_id', user.id)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return list;

    // Resolve matched-donor profiles in a separate query.
    final donorIds = list
        .map((r) => r['fulfilled_by_donor_id'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (donorIds.isNotEmpty) {
      final profileRows = await client
          .from('profiles_public')
          .select('id, name, blood_group, profile_photo_url')
          .inFilter('id', donorIds);

      final profileMap = {
        for (final p in (profileRows as List).cast<Map<String, dynamic>>())
          p['id'] as String: p,
      };

      for (final r in list) {
        final donorId = r['fulfilled_by_donor_id'] as String?;
        if (donorId != null) {
          r['matched_donor'] = profileMap[donorId];
        }
      }
    }

    return list;
  }

  // ── Stream controller ───────────────────────────────────────────────────
  final controller = StreamController<List<Map<String, dynamic>>>();

  fetchInProgress().then((data) {
    if (!controller.isClosed) controller.add(data);
  }).catchError((Object e, StackTrace st) {
    if (!controller.isClosed) controller.addError(e, st);
  });

  final channel = client
      .channel('in_progress_donations')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'blood_requests',
        callback: (_) async {
          try {
            final data = await fetchInProgress();
            if (!controller.isClosed) controller.add(data);
          } catch (e, st) {
            if (!controller.isClosed) controller.addError(e, st);
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── Response counts ──────────────────────────────────────────────────────────

/// Number of donors who responded to a given request.
///
/// Used by the home request card ("{N} donors responded"). Per-request
/// count — RLS already scopes responses to the requester or the donor.
final requestResponseCountProvider = FutureProvider.family<int, String>((
  ref,
  requestId,
) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('request_responses')
      .select('id')
      .eq('request_id', requestId);
  return data.length;
});

// ── Haversine distance helper (metres) ────────────────────────────────────────

double _haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0; // Earth radius in metres
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ── Urgent requests (channel-based realtime stream for donor view) ─────────────
//
// Uses an initial REST fetch + Postgres Realtime channel instead of .stream().
// The .stream() API requires an .eq() row filter to work reliably with RLS —
// a table-wide subscription silently returns no rows in some SDK versions.
// The channel approach works universally: it fetches fresh data on every
// INSERT / UPDATE / DELETE event on blood_requests.
//
// Visibility: ALL active requests (both urgent and planned) are included.
// Own requests are excluded so the donor doesn't see their own (edge case when
// a user has both roles).
// Sorting: by distance from the donor's profile location when available;
// fallback to newest-first.

final urgentRequestsStreamProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    final user = ref.watch(currentUserProvider);
    // Donor's lat/lng for proximity sort (may be null).
    final profileAsync = ref.watch(userProfileProvider);
    final donorLat = profileAsync.valueOrNull?.latitude;
    final donorLng = profileAsync.valueOrNull?.longitude;

    // ── Fetch helper ────────────────────────────────────────────────────────
    Future<List<Map<String, dynamic>>> fetchRequests() async {
      // 1. Fetch active blood requests (no join — avoids multi-FK ambiguity).
      final rows = await client
          .from('blood_requests')
          .select('*')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          // Exclude the current user's own requests.
          .where((r) => user == null || r['requester_id'] != user.id)
          .toList();

      // 2. Fetch requester profiles in a separate query for dynamic names.
      final requesterIds = list
          .map((r) => r['requester_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (requesterIds.isNotEmpty) {
        final profileRows = await client
            .from('profiles_public')
            .select('id, name, profile_photo_url, is_verified')
            .inFilter('id', requesterIds);

        final profileMap = {
          for (final p in (profileRows as List).cast<Map<String, dynamic>>())
            p['id'] as String: p,
        };

        // 3. Merge requester profile into each request map.
        for (final r in list) {
          final requesterId = r['requester_id'] as String?;
          if (requesterId != null) {
            r['requester_profiles'] = profileMap[requesterId];
          }
        }
      }

      // Sort by proximity when the donor's location is known.
      if (donorLat != null && donorLng != null) {
        list.sort((a, b) {
          final aLat = (a['latitude'] as num?)?.toDouble();
          final aLng = (a['longitude'] as num?)?.toDouble();
          final bLat = (b['latitude'] as num?)?.toDouble();
          final bLng = (b['longitude'] as num?)?.toDouble();

          // Requests without coordinates go to the end.
          if (aLat == null || aLng == null) return 1;
          if (bLat == null || bLng == null) return -1;

          final distA = _haversineMetres(donorLat, donorLng, aLat, aLng);
          final distB = _haversineMetres(donorLat, donorLng, bLat, bLng);
          return distA.compareTo(distB);
        });
      }

      return list;
    }

    // ── Stream controller ───────────────────────────────────────────────────
    final controller = StreamController<List<Map<String, dynamic>>>();

    // Emit initial data immediately via REST.
    fetchRequests().then((data) {
      if (!controller.isClosed) controller.add(data);
    }).catchError((Object e, StackTrace st) {
      if (!controller.isClosed) controller.addError(e, st);
    });

    // Subscribe to Postgres Realtime for live updates.
    final channel = client
        .channel('blood_requests_donor_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blood_requests',
          callback: (_) async {
            try {
              final data = await fetchRequests();
              if (!controller.isClosed) controller.add(data);
            } catch (e, st) {
              if (!controller.isClosed) controller.addError(e, st);
            }
          },
        )
        .subscribe();

    ref.onDispose(() {
      client.removeChannel(channel);
      controller.close();
    });

    return controller.stream;
  },
);

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
          // UTC-only math to stay consistent with the Supabase admin panel.
          final nowUtc = DateTime.now().toUtc();
          final lastUtc = profile.lastDonationDate!.toUtc();
          final daysSince = DateTime.utc(
                nowUtc.year, nowUtc.month, nowUtc.day,
              ).difference(
                DateTime.utc(lastUtc.year, lastUtc.month, lastUtc.day),
              ).inDays;
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
