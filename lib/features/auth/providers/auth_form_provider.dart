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
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authServiceProvider).signUpWithEmail(
            email.trim(),
            password,
            data: {
              'full_name': fullName.trim(),
              'phone': phone.trim(),
              'active_role': role,
            },
          );

      // Create a profile row in Supabase so the user appears in
      // queries immediately (before the verification flow).
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
        // Normalise Pakistani phone to +92XXXXXXXXXX to satisfy DB check.
        final digits = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
        String? normalisedPhone;
        if (digits.length == 11 && digits.startsWith('0')) {
          normalisedPhone = '+92${digits.substring(1)}';
        } else if (digits.length == 12 && digits.startsWith('92')) {
          normalisedPhone = '+$digits';
        } else if (digits.length == 13 && digits.startsWith('0092')) {
          normalisedPhone = '+${digits.substring(2)}';
        }

        await _ref.read(supabaseClientProvider).from('profiles').upsert({
          'id': user.id,
          'name': fullName.trim(),
          'phone': normalisedPhone,
          'email': email.trim(),
          'active_role': role,
        });
      }

      state = const SignupState(success: true); // success — show confirmation
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

final signupNotifierProvider =
    StateNotifierProvider<SignupNotifier, SignupState>((ref) {
  return SignupNotifier(ref);
});
