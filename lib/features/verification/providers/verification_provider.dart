import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/storage_service_provider.dart';
import '../../../services/supabase/supabase_client_provider.dart';

/// Steps in the donor verification flow.
enum VerificationStep { cnicUpload, selfie, submitting, confirmed }

/// Immutable state for the multi-step verification flow.
class VerificationState {
  const VerificationState({
    this.step = VerificationStep.cnicUpload,
    this.cnicFront,
    this.cnicBack,
    this.selfie,
    this.isSubmitting = false,
    this.serverError,
  });

  final VerificationStep step;
  final XFile? cnicFront;
  final XFile? cnicBack;
  final XFile? selfie;
  final bool isSubmitting;
  final String? serverError;

  VerificationState copyWith({
    VerificationStep? step,
    XFile? cnicFront,
    XFile? cnicBack,
    XFile? selfie,
    bool? isSubmitting,
    String? serverError,
    bool clearError = false,
    bool clearCnicFront = false,
    bool clearCnicBack = false,
    bool clearSelfie = false,
  }) {
    return VerificationState(
      step: step ?? this.step,
      cnicFront: clearCnicFront ? null : (cnicFront ?? this.cnicFront),
      cnicBack: clearCnicBack ? null : (cnicBack ?? this.cnicBack),
      selfie: clearSelfie ? null : (selfie ?? this.selfie),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      serverError: clearError ? null : (serverError ?? this.serverError),
    );
  }
}

/// Manages the donor verification flow: image selection, step navigation,
/// and submission to Supabase (storage + database).
class VerificationNotifier extends StateNotifier<VerificationState> {
  VerificationNotifier(this._ref) : super(const VerificationState());

  final Ref _ref;

  // ── Image selection ─────────────────────────────────────────────────

  void setCnicFront(XFile? file) =>
      state = state.copyWith(cnicFront: file, clearError: true);

  void setCnicBack(XFile? file) =>
      state = state.copyWith(cnicBack: file, clearError: true);

  void setSelfie(XFile? file) =>
      state = state.copyWith(selfie: file, clearError: true);

  // ── Navigation ──────────────────────────────────────────────────────

  void goToSelfieStep() =>
      state = state.copyWith(step: VerificationStep.selfie);

  void backToCnicStep() =>
      state = state.copyWith(step: VerificationStep.cnicUpload);

  /// Resets the flow to a fresh state (called after navigating away
  /// from the confirmation screen).
  void reset() => state = const VerificationState();

  // ── Submit ──────────────────────────────────────────────────────────

  /// Uploads all three images to Supabase Storage, creates a
  /// `verification_submissions` row, and sets the donor's profile to
  /// "pending" verification.
  Future<void> submit() async {
    state = state.copyWith(
      step: VerificationStep.submitting,
      isSubmitting: true,
      clearError: true,
    );

    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) {
        state = state.copyWith(
          isSubmitting: false,
          serverError: 'You must be signed in to verify your identity.',
        );
        return;
      }

      final storage = _ref.read(storageServiceProvider);

      // Upload images to private storage bucket and store paths
      // (bucket is private, so public URLs are not accessible).
      final cnicFrontPath = await storage.uploadFile(
        bucket: 'verifications',
        path: '${user.id}/cnic_front',
        bytes: await state.cnicFront!.readAsBytes(),
        returnPath: true,
      );
      final cnicBackPath = await storage.uploadFile(
        bucket: 'verifications',
        path: '${user.id}/cnic_back',
        bytes: await state.cnicBack!.readAsBytes(),
        returnPath: true,
      );
      final selfiePath = await storage.uploadFile(
        bucket: 'verifications',
        path: '${user.id}/selfie',
        bytes: await state.selfie!.readAsBytes(),
        returnPath: true,
      );

      // Create verification submission record.
      await _ref.read(supabaseClientProvider)
          .from('verification_submissions')
          .insert({
        'user_id': user.id,
        'cnic_front_url': cnicFrontPath,
        'cnic_back_url': cnicBackPath,
        'selfie_url': selfiePath,
        'status': 'pending',
      });

      // Mark profile as pending verification.
      await _ref.read(supabaseClientProvider)
          .from('profiles')
          .update({'is_verified': false})
          .eq('id', user.id);

      state = state.copyWith(
        step: VerificationStep.confirmed,
        isSubmitting: false,
      );
    } on AuthException catch (e) {
      state = state.copyWith(
        step: VerificationStep.selfie,
        isSubmitting: false,
        serverError: e.message,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final serverError = msg.contains('unique') ||
              msg.contains('duplicate') ||
              msg.contains('already exists')
          ? 'You already have a pending or approved verification submission.'
          : 'Upload failed: ${e.toString()}. Please try again.';
      state = state.copyWith(
        step: VerificationStep.selfie,
        isSubmitting: false,
        serverError: serverError,
      );
    }
  }
}

final verificationNotifierProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  return VerificationNotifier(ref);
});
