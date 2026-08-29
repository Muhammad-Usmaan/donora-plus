import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../home/providers/home_providers.dart';

// ── Form state ────────────────────────────────────────────────────────────────

/// Immutable state for the "Request Blood" form.
class RequestFormState {
  const RequestFormState({
    this.bloodGroup,
    this.isUrgent = true,
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
  });

  /// Selected blood type (required).
  final String? bloodGroup;

  /// True = urgent (within hours), false = planned (within days).
  final bool isUrgent;

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

  /// The ID of the successfully created request (null until submitted).
  final String? createdRequestId;

  /// Whether all required fields are filled.
  bool get isValid =>
      bloodGroup != null &&
      bloodGroup!.isNotEmpty &&
      city != null &&
      city!.isNotEmpty &&
      hospitalName.trim().isNotEmpty &&
      unitsNeeded >= 1 &&
      unitsNeeded <= 10;

  /// Whether the form has been successfully submitted.
  bool get isSubmitted => createdRequestId != null;

  RequestFormState copyWith({
    String? bloodGroup,
    bool? isUrgent,
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
  }) {
    return RequestFormState(
      bloodGroup: bloodGroup ?? this.bloodGroup,
      isUrgent: isUrgent ?? this.isUrgent,
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
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages the "Request Blood" form: field updates, validation, and
/// submission to the `blood_requests` Supabase table.
class RequestCreateNotifier extends StateNotifier<RequestFormState> {
  RequestCreateNotifier(this._ref) : super(const RequestFormState());

  final Ref _ref;

  // ── Field setters ───────────────────────────────────────────────────

  void setBloodGroup(String type) =>
      state = state.copyWith(bloodGroup: type, clearError: true);

  void setUrgent(bool urgent) =>
      state = state.copyWith(isUrgent: urgent);

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

  /// Creates a new `blood_requests` row in Supabase and stores the
  /// resulting request ID in [RequestFormState.createdRequestId].
  Future<void> submit() async {
    if (!state.isValid) return;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) {
        state = state.copyWith(
          isSubmitting: false,
          serverError: 'You must be signed in to create a request.',
        );
        return;
      }

      final client = _ref.read(supabaseClientProvider);

      // Insert into blood_requests.
      final response = await client.from('blood_requests').insert({
        'requester_id': user.id,
        'blood_group': state.bloodGroup!,
        'units_needed': state.unitsNeeded,
        'hospital_name': state.hospitalName.trim(),
        'city': state.city!,
        'notes': state.notes.trim().isEmpty ? null : state.notes.trim(),
        'is_urgent': state.isUrgent,
        'status': 'active',
        'allow_phone_contact': state.allowPhoneCall,
        'expires_at': DateTime.now()
            .add(const Duration(hours: 72))
            .toIso8601String(),
      }).select('id').single();

      state = state.copyWith(
        isSubmitting: false,
        createdRequestId: response['id'] as String,
      );

      // Refresh home screen data so the new request appears immediately.
      _ref.invalidate(activeRequestsProvider);
      _ref.invalidate(urgentRequestsStreamProvider);
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
