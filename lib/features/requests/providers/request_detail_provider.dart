import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase/supabase_client_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

/// A single blood request row from `blood_requests`.
class RequestDetail {
  const RequestDetail({
    required this.id,
    required this.requesterId,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.hospitalName,
    required this.city,
    required this.isUrgent,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.notes,
    this.allowPhoneContact = false,
  });

  final String id;
  final String requesterId;
  final String bloodGroup;
  final int unitsNeeded;
  final String hospitalName;
  final String city;
  final bool isUrgent;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? notes;
  final bool allowPhoneContact;

  bool get isActive => status == 'active';

  factory RequestDetail.fromMap(Map<String, dynamic> map) => RequestDetail(
        id: map['id'] as String? ?? '',
        requesterId: map['requester_id'] as String? ?? '',
        bloodGroup: map['blood_group'] as String? ?? '',
        unitsNeeded: map['units_needed'] as int? ?? 1,
        hospitalName: map['hospital_name'] as String? ?? '',
        city: map['city'] as String? ?? '',
        isUrgent: map['is_urgent'] as bool? ?? false,
        status: map['status'] as String? ?? 'active',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: DateTime.tryParse(map['expires_at'] as String? ?? '') ??
            DateTime.now().add(const Duration(hours: 72)),
        notes: map['notes'] as String?,
        allowPhoneContact: map['allow_phone_contact'] as bool? ?? false,
      );
}

/// A donor who responded to a blood request.
class RequestResponder {
  const RequestResponder({
    required this.donorId,
    required this.name,
    required this.bloodGroup,
    required this.isVerified,
    required this.isTopDonor,
    required this.donorClassification,
    required this.city,
    this.profilePhotoUrl,
    this.respondedAt,
    this.message,
  });

  final String donorId;
  final String name;
  final String bloodGroup;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;
  final String city;
  final String? profilePhotoUrl;
  final DateTime? respondedAt;
  final String? message;

  factory RequestResponder.fromMap(Map<String, dynamic> map) {
    // The response row may embed donor fields directly (via join) or
    // nest them under a 'donor' key depending on the query shape.
    final donor = map['donor'] as Map<String, dynamic>?;
    final profiles = map['profiles'] as Map<String, dynamic>?;
    final d = donor ?? profiles ?? map;

    return RequestResponder(
      donorId: d['id'] as String? ?? map['donor_id'] as String? ?? '',
      name: d['name'] as String? ?? 'Unknown',
      bloodGroup: d['blood_group'] as String? ?? '',
      isVerified: d['is_verified'] as bool? ?? false,
      isTopDonor: d['is_top_donor'] as bool? ?? false,
      donorClassification:
          d['donor_classification'] as String? ?? 'volunteer',
      city: d['city'] as String? ?? '',
      profilePhotoUrl: d['profile_photo_url'] as String?,
      respondedAt: map['responded_at'] != null
          ? DateTime.tryParse(map['responded_at'] as String)
          : null,
      message: map['message'] as String?,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches a single blood request by its ID.
final requestDetailProvider =
    FutureProvider.family<RequestDetail, String>((ref, requestId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('blood_requests')
      .select()
      .eq('id', requestId)
      .maybeSingle();

  if (data == null) throw Exception('Request not found');
  return RequestDetail.fromMap(data);
});

/// Fetches donors who responded to a given blood request.
///
/// Queries `request_responses` joined with `profiles`.
/// Returns an empty list if the table doesn't exist yet (graceful fallback).
final requestResponsesProvider =
    FutureProvider.family<List<RequestResponder>, String>(
        (ref, requestId) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final data = await client
        .from('request_responses')
        .select('*, profiles!donor_id(*)')
        .eq('request_id', requestId)
        .order('responded_at', ascending: false);

    return (data as List)
        .map((row) => RequestResponder.fromMap(row as Map<String, dynamic>))
        .toList();
  } on PostgrestException catch (e) {
    // If the table doesn't exist yet, return empty rather than crashing.
    if (e.code == '42P01' || e.message.contains('does not exist')) {
      return <RequestResponder>[];
    }
    rethrow;
  }
});

/// Action provider: closes a blood request by setting its status to 'closed'.
final closeRequestActionProvider = Provider<CloseRequestAction>((ref) {
  return CloseRequestAction(ref);
});

class CloseRequestAction {
  CloseRequestAction(this._ref);
  final Ref _ref;

  bool _isClosing = false;
  bool get isClosing => _isClosing;

  /// Sets the request status to 'closed'. Returns true on success.
  Future<bool> call(String requestId) async {
    if (_isClosing) return false;
    _isClosing = true;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('blood_requests')
          .update({'status': 'closed'}).eq('id', requestId);

      // Invalidate the cached request detail so the UI refreshes.
      _ref.invalidate(requestDetailProvider(requestId));
      return true;
    } catch (_) {
      return false;
    } finally {
      _isClosing = false;
    }
  }
}
