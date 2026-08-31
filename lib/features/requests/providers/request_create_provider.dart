import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/request_reasons.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../home/providers/home_providers.dart';
import 'request_detail_provider.dart';
import 'requests_list_provider.dart';

// ── Form state ────────────────────────────────────────────────────────────────

/// Immutable state for the "Request Blood" form.
class RequestFormState {
  const RequestFormState({
    this.editingRequestId,
    this.bloodGroup,
    this.isUrgent = true,
    this.reason,
    this.reasonNote = '',
    this.patientName = '',
    this.city,
    this.latitude,
    this.longitude,
    this.hospitalName = '',
    this.unitsNeeded = 1,
    this.notes = '',
    this.allowPhoneCall = false,
    this.isSubmitting = false,
    this.serverError,
    this.createdRequestId,
    this.plannedDate,
  });

  /// ID of the request being edited (null when creating a new request).
  final String? editingRequestId;

  /// Selected blood type (required).
  final String? bloodGroup;

  /// True = urgent (within hours), false = planned (within days).
  final bool isUrgent;

  /// Why blood is needed (required) — must be chosen explicitly.
  final RequestReason? reason;

  /// Free-text note when [reason] is [RequestReason.other] (max 60 chars).
  final String reasonNote;

  /// Patient's full name (required).
  final String patientName;

  /// City / location (auto-filled from profile, editable).
  final String? city;

  /// Precise latitude from map picker or GPS (optional).
  final double? latitude;

  /// Precise longitude from map picker or GPS (optional).
  final double? longitude;

  /// Hospital or location name.
  final String hospitalName;

  /// Number of blood units needed (1–10).
  final int unitsNeeded;

  /// Optional additional notes.
  final String notes;

  /// Contact preference: true = allow phone call, false = in-app chat only.
  final bool allowPhoneCall;

  /// Whether the form is currently being submitted.
  final bool isSubmitting;

  /// Server-side error message, if any.
  final String? serverError;

  /// The ID of the successfully created or edited request (null until submitted).
  final String? createdRequestId;

  /// When the donation is actually needed (non-urgent / pre-planned only).
  final DateTime? plannedDate;

  /// Whether editing an existing request.
  bool get isEditing => editingRequestId != null;

  /// Whether all required fields are filled.
  ///
  /// Non-urgent requests require [plannedDate] to be set.
  bool get isValid =>
      bloodGroup != null &&
      bloodGroup!.isNotEmpty &&
      reason != null &&
      patientName.trim().isNotEmpty &&
      city != null &&
      city!.isNotEmpty &&
      hospitalName.trim().isNotEmpty &&
      unitsNeeded >= 1 &&
      unitsNeeded <= 10 &&
      (isUrgent || plannedDate != null);

  /// Whether the form has been successfully submitted.
  bool get isSubmitted => createdRequestId != null;

  RequestFormState copyWith({
    String? editingRequestId,
    bool clearEditingId = false,
    String? bloodGroup,
    bool? isUrgent,
    RequestReason? reason,
    String? reasonNote,
    String? patientName,
    String? city,
    double? latitude,
    double? longitude,
    String? hospitalName,
    int? unitsNeeded,
    String? notes,
    bool? allowPhoneCall,
    bool? isSubmitting,
    String? serverError,
    bool clearError = false,
    String? createdRequestId,
    DateTime? plannedDate,
    bool clearPlannedDate = false,
  }) {
    return RequestFormState(
      editingRequestId:
          clearEditingId ? null : (editingRequestId ?? this.editingRequestId),
      bloodGroup: bloodGroup ?? this.bloodGroup,
      isUrgent: isUrgent ?? this.isUrgent,
      reason: reason ?? this.reason,
      reasonNote: reasonNote ?? this.reasonNote,
      patientName: patientName ?? this.patientName,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hospitalName: hospitalName ?? this.hospitalName,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      notes: notes ?? this.notes,
      allowPhoneCall: allowPhoneCall ?? this.allowPhoneCall,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      serverError: clearError ? null : (serverError ?? this.serverError),
      createdRequestId: createdRequestId ?? this.createdRequestId,
      plannedDate: clearPlannedDate ? null : (plannedDate ?? this.plannedDate),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages the "Request Blood" form: field updates, validation, and
/// submission/updating to the `blood_requests` Supabase table.
class RequestCreateNotifier extends StateNotifier<RequestFormState> {
  RequestCreateNotifier(this._ref) : super(const RequestFormState());

  final Ref _ref;

  /// Prefills state with existing request data for editing.
  void initializeForEdit(RequestDetail request) {
    state = RequestFormState(
      editingRequestId: request.id,
      bloodGroup: request.bloodGroup,
      isUrgent: request.isUrgent,
      reason: request.reason,
      reasonNote: request.reasonNote ?? '',
      patientName: request.patientName,
      city: request.city,
      hospitalName: request.hospitalName,
      unitsNeeded: request.unitsNeeded,
      notes: request.notes ?? '',
      allowPhoneCall: request.allowPhoneContact,
      plannedDate: request.plannedDate,
    );
  }

  /// Resets state for creating a new request.
  void resetForCreate() {
    state = const RequestFormState();
  }

  // ── Field setters ───────────────────────────────────────────────────

  void setBloodGroup(String type) =>
      state = state.copyWith(bloodGroup: type, clearError: true);

  void setUrgent(bool urgent) =>
      state = state.copyWith(isUrgent: urgent, clearPlannedDate: urgent);

  /// Sets the planned date for non-urgent requests.
  void setPlannedDate(DateTime? date) =>
      state = state.copyWith(plannedDate: date, clearError: true);

  /// Sets the reason for the request.
  ///
  /// The free-text note only applies to `other`, so it is cleared
  /// whenever another reason is picked.
  void setReason(RequestReason reason) => state = state.copyWith(
        reason: reason,
        reasonNote:
            reason == RequestReason.other ? state.reasonNote : '',
        clearError: true,
      );

  /// Sets the optional note shown when the reason is `other` (max 60).
  void setReasonNote(String note) => state = state.copyWith(
        reasonNote:
            note.length > 60 ? note.substring(0, 60) : note,
      );

  void setPatientName(String name) =>
      state = state.copyWith(patientName: name, clearError: true);

  void setCity(String city) =>
      state = state.copyWith(city: city, clearError: true);

  /// Sets the precise location from map picker or GPS.
  void setLocation(double lat, double lng, String city) =>
      state = state.copyWith(
        latitude: lat,
        longitude: lng,
        city: city,
        clearError: true,
      );

  void setHospitalName(String name) =>
      state = state.copyWith(hospitalName: name, clearError: true);

  void setUnitsNeeded(int units) =>
      state = state.copyWith(unitsNeeded: units.clamp(1, 10));

  void incrementUnits() => setUnitsNeeded(state.unitsNeeded + 1);

  void decrementUnits() => setUnitsNeeded(state.unitsNeeded - 1);

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  void setAllowPhoneCall(bool allow) =>
      state = state.copyWith(allowPhoneCall: allow);

  // ── Pre-fill city from profile ──────────────────────────────────────

  void prefillCity(String? city) {
    if (city != null && city.isNotEmpty && state.city == null) {
      state = state.copyWith(city: city);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────

  /// Creates or updates a `blood_requests` row in Supabase and stores the
  /// resulting request ID in [RequestFormState.createdRequestId].
  Future<void> submit() async {
    if (!state.isValid) return;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) {
        state = state.copyWith(
          isSubmitting: false,
          serverError: 'You must be signed in to submit a request.',
        );
        return;
      }

      final client = _ref.read(supabaseClientProvider);

      if (state.isEditing) {
        final reqId = state.editingRequestId!;
        await client.from('blood_requests').update({
          'blood_group': state.bloodGroup!,
          'reason': state.reason!.value,
          'reason_note': state.reason == RequestReason.other &&
                  state.reasonNote.trim().isNotEmpty
              ? state.reasonNote.trim()
              : null,
          'patient_name': state.patientName.trim(),
          'units_needed': state.unitsNeeded,
          'hospital_name': state.hospitalName.trim(),
          'city': state.city!,
          'notes': state.notes.trim().isEmpty ? null : state.notes.trim(),
          'is_urgent': state.isUrgent,
          'allow_phone_contact': state.allowPhoneCall,
          'planned_date': state.isUrgent
              ? null
              : state.plannedDate?.toUtc().toIso8601String(),
        }).eq('id', reqId);

        state = state.copyWith(
          isSubmitting: false,
          createdRequestId: reqId,
        );

        _ref.invalidate(requestDetailProvider(reqId));
        _ref.invalidate(requestsListProvider);
        _ref.invalidate(activeRequestsProvider);
        _ref.invalidate(urgentRequestsStreamProvider);
      } else {
        // Insert into blood_requests.
        // expires_at is set server-side by the trg_set_request_expiry trigger:
        //   urgent  → created_at + 24h
        //   planned → end of planned_date day
        final response = await client.from('blood_requests').insert({
          'requester_id': user.id,
          'blood_group': state.bloodGroup!,
          'reason': state.reason!.value,
          'reason_note': state.reason == RequestReason.other &&
                  state.reasonNote.trim().isNotEmpty
              ? state.reasonNote.trim()
              : null,
          'patient_name': state.patientName.trim(),
          'units_needed': state.unitsNeeded,
          'hospital_name': state.hospitalName.trim(),
          'city': state.city!,
          'notes': state.notes.trim().isEmpty ? null : state.notes.trim(),
          'is_urgent': state.isUrgent,
          'status': 'active',
          'allow_phone_contact': state.allowPhoneCall,
          if (!state.isUrgent && state.plannedDate != null)
            'planned_date': state.plannedDate!.toUtc().toIso8601String(),
        }).select('id').single();

        state = state.copyWith(
          isSubmitting: false,
          createdRequestId: response['id'] as String,
        );

        // Refresh home screen data so the new request appears immediately.
        _ref.invalidate(requestsListProvider);
        _ref.invalidate(activeRequestsProvider);
        _ref.invalidate(urgentRequestsStreamProvider);
      }
    } on PostgrestException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        serverError: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        serverError:
            'Something went wrong. Please check your connection and try again.',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final requestCreateProvider =
    StateNotifierProvider<RequestCreateNotifier, RequestFormState>((ref) {
  return RequestCreateNotifier(ref);
});

