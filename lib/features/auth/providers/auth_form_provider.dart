import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Login ─────────────────────────────────────────────────────────────────────

/// Immutable state for the login form submission.
class LoginState {
  const LoginState({
    this.isLoading = false,
    this.serverError,
  });

  final bool isLoading;
  final String? serverError;

  LoginState copyWith({bool? isLoading, String? serverError, bool clearError = false}) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      serverError: clearError ? null : (serverError ?? this.serverError),
    );
  }
}

/// Handles login form submission against Supabase Auth.
class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier(this._ref) : super(const LoginState());

  final Ref _ref;

  Future<void> submit(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authServiceProvider).signInWithPassword(
            emailOrPhone.trim(),
            password,
          );
      state = const LoginState(); // success — router redirect handles nav
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, serverError: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        serverError: 'Something went wrong. Please try again.',
      );
    }
  }

  void clearError() {
    if (state.serverError != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final loginNotifierProvider =
    StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref);
});

// ── Signup ────────────────────────────────────────────────────────────────────

/// Immutable state for the signup form submission.
class SignupState {
  const SignupState({
    this.isLoading = false,
    this.serverError,
    this.success = false,
  });

  final bool isLoading;
  final String? serverError;
  /// True when signup succeeded — the UI should show a confirmation message.
  final bool success;

  SignupState copyWith({bool? isLoading, String? serverError, bool clearError = false, bool? success}) {
    return SignupState(
      isLoading: isLoading ?? this.isLoading,
      serverError: clearError ? null : (serverError ?? this.serverError),
      success: success ?? this.success,
    );
  }
}

/// Handles signup form submission against Supabase Auth.
class SignupNotifier extends StateNotifier<SignupState> {
  SignupNotifier(this._ref) : super(const SignupState());

  final Ref _ref;

  Future<void> submit({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required DateTime birthdate,
    required String role,
    required String bloodGroup,
    required String city,
    double? latitude,
    double? longitude,
    String? donorClassification,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final formattedDob =
          '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}';

      // Normalise Pakistani phone to +92XXXXXXXXXX format.
      final digits = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
      String? normalisedPhone;
      if (digits.length == 11 && digits.startsWith('0')) {
        normalisedPhone = '+92${digits.substring(1)}';
      } else if (digits.length == 12 && digits.startsWith('92')) {
        normalisedPhone = '+$digits';
      } else if (digits.length == 13 && digits.startsWith('0092')) {
        normalisedPhone = '+${digits.substring(2)}';
      } else if (digits.length == 10) {
        normalisedPhone = '+92$digits';
      } else {
        normalisedPhone = phone.trim();
      }

      // 1. Pre-check phone uniqueness via Supabase RPC to prevent registration collision.
      final isTaken = await _ref
          .read(authServiceProvider)
          .isPhoneRegistered(normalisedPhone);
      if (isTaken) {
        state = state.copyWith(
          isLoading: false,
          serverError:
              'This phone number is already registered with another account.',
        );
        return;
      }

      // 2. Sign up with Supabase Auth
      await _ref.read(authServiceProvider).signUpWithEmail(
            email.trim(),
            password,
            data: {
              'full_name': fullName.trim(),
              'phone': normalisedPhone,
              'date_of_birth': formattedDob,
              'active_role': role,
              'blood_group': bloodGroup.trim(),
              'city': city.trim(),
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
              if (donorClassification != null && donorClassification.isNotEmpty)
                'donor_classification': donorClassification,
            },
          );

      // 3. Create or update profile row in Supabase
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
        try {
          await _ref.read(supabaseClientProvider).from('profiles').upsert({
            'id': user.id,
            'name': fullName.trim(),
            'phone': normalisedPhone,
            'email': email.trim(),
            'date_of_birth': formattedDob,
            'active_role': role,
            'blood_group': bloodGroup.trim(),
            'city': city.trim(),
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (donorClassification != null && donorClassification.isNotEmpty)
              'donor_classification': donorClassification,
          });
        } on PostgrestException catch (pe) {
          if (pe.code == '23505' ||
              (pe.message.contains('profiles_phone_key') ||
                  pe.message.contains('phone'))) {
            state = state.copyWith(
              isLoading: false,
              serverError:
                  'This phone number is already registered with another account.',
            );
            return;
          }
          rethrow;
        }
      }

      state = const SignupState(success: true); // success — show confirmation
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, serverError: e.message);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('phone') && msg.contains('unique') ||
          msg.contains('profiles_phone_key') ||
          msg.contains('duplicate')) {
        state = state.copyWith(
          isLoading: false,
          serverError:
              'This phone number is already registered with another account.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          serverError: 'Something went wrong. Please try again.',
        );
      }
    }
  }

  void clearError() {
    if (state.serverError != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final signupNotifierProvider =
    StateNotifierProvider<SignupNotifier, SignupState>((ref) {
  return SignupNotifier(ref);
});
