import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/request_reasons.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

/// A single blood request row from `blood_requests`.
class RequestDetail {
  const RequestDetail({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhone,
    this.requesterPhotoUrl,
    this.requesterIsVerified = false,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.hospitalName,
    required this.city,
    required this.isUrgent,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.fulfilledByDonorId,
    this.notes,
    this.allowPhoneContact = false,
    this.reason = RequestReason.other,
    this.reasonNote,
    this.latitude,
    this.longitude,
    this.plannedDate,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterPhone;
  final String? requesterPhotoUrl;
  final bool requesterIsVerified;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final String hospitalName;
  final String city;
  final bool isUrgent;
  final String status;
  final String? fulfilledByDonorId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? notes;
  final bool allowPhoneContact;
  final double? latitude;
  final double? longitude;

  /// Why blood is needed — shown as a pill on the detail screen.
  final RequestReason reason;

  /// Free-text note shown when [reason] is [RequestReason.other].
  final String? reasonNote;

  /// When the donation is actually needed (non-urgent / pre-planned only).
  final DateTime? plannedDate;

  bool get isActive => status == 'active' && !isExpired;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAccepted => status == 'accepted';
  bool get isFulfilled => status == 'fulfilled';

  factory RequestDetail.fromMap(Map<String, dynamic> map) {
    final profiles =
        map['requester'] as Map<String, dynamic>? ??
        map['profiles'] as Map<String, dynamic>? ??
        {};

    return RequestDetail(
      id: map['id'] as String? ?? '',
      requesterId: map['requester_id'] as String? ?? '',
      requesterName: profiles['name'] as String? ?? 'Requester',
      requesterPhone: profiles['phone'] as String?,
      requesterPhotoUrl: profiles['profile_photo_url'] as String?,
      requesterIsVerified: profiles['is_verified'] as bool? ?? false,
      patientName: map['patient_name'] as String? ?? 'Patient',
      bloodGroup: map['blood_group'] as String? ?? '',
      unitsNeeded: map['units_needed'] as int? ?? 1,
      hospitalName: map['hospital_name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      isUrgent: map['is_urgent'] as bool? ?? false,
      status: map['status'] as String? ?? 'active',
      fulfilledByDonorId: map['fulfilled_by_donor_id'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(map['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 72)),
      notes: map['notes'] as String?,
      allowPhoneContact: map['allow_phone_contact'] as bool? ?? false,
      reason: RequestReason.fromValue(map['reason'] as String?),
      reasonNote: map['reason_note'] as String?,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      plannedDate: map['planned_date'] != null
          ? DateTime.tryParse(map['planned_date'] as String)
          : null,
    );
  }
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
    final donor = map['donor'] as Map<String, dynamic>?;
    final profiles = map['profiles'] as Map<String, dynamic>?;
    final d = donor ?? profiles ?? map;

    return RequestResponder(
      donorId: d['id'] as String? ?? map['donor_id'] as String? ?? '',
      name: d['name'] as String? ?? 'Unknown',
      bloodGroup: d['blood_group'] as String? ?? '',
      isVerified: d['is_verified'] as bool? ?? false,
      isTopDonor: d['is_top_donor'] as bool? ?? false,
      donorClassification: d['donor_classification'] as String? ?? 'volunteer',
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

/// Fetches a single blood request by its ID enriched with requester profile.
final requestDetailProvider = FutureProvider.family<RequestDetail, String>((
  ref,
  requestId,
) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('blood_requests')
      .select(
        '*, requester:profiles!requester_id(id, name, phone, profile_photo_url, is_verified)',
      )
      .eq('id', requestId)
      .maybeSingle();

  if (data == null) throw Exception('Request not found');
  return RequestDetail.fromMap(data);
});

/// Checks if the current authenticated donor has an in-flight accepted request commitment.
final donorHasActiveCommitmentProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final client = ref.watch(supabaseClientProvider);
  try {
    final res = await client.rpc(
      'donor_has_active_commitment',
      params: {'p_donor_id': user.id},
    );
    return res == true;
  } catch (_) {
    return false;
  }
});

/// Action provider: responds to a blood request via secure RPC.
final respondToRequestActionProvider = Provider<RespondToRequestAction>((ref) {
  return RespondToRequestAction(ref);
});

class RespondToRequestAction {
  RespondToRequestAction(this._ref);
  final Ref _ref;

  Future<({bool success, String? message})> call({
    required String requestId,
    String? message,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final res = await client.rpc(
        'respond_to_blood_request',
        params: {'p_request_id': requestId, 'p_message': message},
      );
      final map = res as Map<String, dynamic>? ?? {};
      final isSuccess = map['success'] == true;
      if (isSuccess) {
        _ref.invalidate(requestDetailProvider(requestId));
        _ref.invalidate(donorHasActiveCommitmentProvider);

        // Notify the seeker that a donor responded.
        unawaited(_notifySeeker(requestId));
      }
      return (success: isSuccess, message: map['message'] as String?);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Sends a push notification to the request's seeker.
  Future<void> _notifySeeker(String requestId) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final user = _ref.read(currentUserProvider);
      if (user == null) return;

      // Fetch the request to get the seeker's ID and details.
      final request = await client
          .from('blood_requests')
          .select('requester_id, hospital_name, blood_group, units_needed')
          .eq('id', requestId)
          .maybeSingle();
      if (request == null) return;

      final seekerId = request['requester_id'] as String?;
      if (seekerId == null || seekerId == user.id) return;

      // Fetch the donor's name for the notification body.
      final donorProfile = await client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final donorName = donorProfile?['name'] as String? ?? 'A donor';

      final hospital = request['hospital_name'] as String? ?? '';
      final bloodGroup = request['blood_group'] as String? ?? '';

      final pushService = _ref.read(pushNotificationServiceProvider);
      await pushService.send(
        recipientId: seekerId,
        type: 'request_accepted',
        title: 'Donor Responded',
        body: '$donorName offered to help with $bloodGroup at $hospital',
        deepLinkId: requestId,
      );
    } catch (_) {
      // Non-critical.
    }
  }
}

/// Action provider: confirms or cancels blood donation by the requester via secure RPC.
final confirmDonationActionProvider = Provider<ConfirmDonationAction>((ref) {
  return ConfirmDonationAction(ref);
});

class ConfirmDonationAction {
  ConfirmDonationAction(this._ref);
  final Ref _ref;

  Future<({bool success, String? message})> call({
    required String requestId,
    required bool confirmed,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final res = await client.rpc(
        'confirm_blood_donation',
        params: {'p_request_id': requestId, 'p_confirmed': confirmed},
      );
      final map = res as Map<String, dynamic>? ?? {};
      final isSuccess = map['success'] == true;
      _ref.invalidate(requestDetailProvider(requestId));
      _ref.invalidate(requestResponsesProvider(requestId));
      _ref.invalidate(donorHasActiveCommitmentProvider);

      // Notify the donor about the confirmation/cancellation.
      if (isSuccess) {
        unawaited(_notifyDonor(requestId, confirmed));
      }

      return (success: isSuccess, message: map['message'] as String?);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Sends a push notification to the donor who was confirmed/cancelled.
  Future<void> _notifyDonor(String requestId, bool confirmed) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final user = _ref.read(currentUserProvider);
      if (user == null) return;

      // Fetch the request to get the donor's ID.
      final request = await client
          .from('blood_requests')
          .select('fulfilled_by_donor_id, hospital_name, blood_group')
          .eq('id', requestId)
          .maybeSingle();
      if (request == null) return;

      final donorId = request['fulfilled_by_donor_id'] as String?;
      if (donorId == null || donorId == user.id) return;

      // Fetch the seeker's name for the notification body.
      final seekerProfile = await client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final seekerName = seekerProfile?['name'] as String? ?? 'The seeker';

      final bloodGroup = request['blood_group'] as String? ?? '';
      final hospital = request['hospital_name'] as String? ?? '';

      final pushService = _ref.read(pushNotificationServiceProvider);
      await pushService.send(
        recipientId: donorId,
        type: confirmed ? 'request_fulfilled' : 'request_expired',
        title: confirmed ? 'Donation Confirmed' : 'Donation Cancelled',
        body: confirmed
            ? '$seekerName confirmed your $bloodGroup donation at $hospital'
            : '$seekerName cancelled the $bloodGroup donation at $hospital',
        deepLinkId: requestId,
      );
    } catch (_) {
      // Non-critical.
    }
  }
}

/// Fetches donors who responded to a given blood request.
///
/// Queries `request_responses` joined with `profiles`.
/// Returns an empty list if the table doesn't exist yet (graceful fallback).
final requestResponsesProvider =
    FutureProvider.family<List<RequestResponder>, String>((
      ref,
      requestId,
    ) async {
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
          .update({'status': 'closed'})
          .eq('id', requestId);

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

/// Action provider: updates an existing blood request.
final updateRequestActionProvider = Provider<UpdateRequestAction>((ref) {
  return UpdateRequestAction(ref);
});

class UpdateRequestAction {
  UpdateRequestAction(this._ref);
  final Ref _ref;

  Future<bool> call({
    required String requestId,
    required String bloodGroup,
    required String reason,
    String? reasonNote,
    required int unitsNeeded,
    required String hospitalName,
    required String city,
    String? notes,
    required bool isUrgent,
    required bool allowPhoneContact,
    DateTime? plannedDate,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('blood_requests')
          .update({
            'blood_group': bloodGroup,
            'reason': reason,
            'reason_note': reasonNote,
            'units_needed': unitsNeeded,
            'hospital_name': hospitalName,
            'city': city,
            'notes': notes,
            'is_urgent': isUrgent,
            'allow_phone_contact': allowPhoneContact,
            'planned_date': isUrgent
                ? null
                : plannedDate?.toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      _ref.invalidate(requestDetailProvider(requestId));
      return true;
    } catch (_) {
      return false;
    }
  }
}
