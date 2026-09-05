import 'dart:async';

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

      // After successful sign-in, verify the profile row exists.
      // If it doesn't, this is an orphaned account (Auth user survived
      // a previous "delete account" that only removed the profile row).
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
        final hasProfile = await _ref
            .read(authServiceProvider)
            .profileExists(user.id);
        if (!hasProfile) {
          await _ref.read(authServiceProvider).signOut();
          state = state.copyWith(
            isLoading: false,
            serverError:
                'This account no longer exists. Please sign up again if you\'d like to create a new account.',
          );
          return;
        }

        // Check if the user is suspended immediately after sign-in.
        final suspended =
            await _ref.read(authServiceProvider).checkSuspended(user.id);
        if (suspended == true) {
          await _ref.read(authServiceProvider).signOut();
          state = state.copyWith(
            isLoading: false,
            serverError:
                'Your account has been suspended. Contact support for details.',
          );
          return;
        }
      }

      state = const LoginState(); // success — router redirect handles nav
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, serverError: e.message);
    } catch (e) {
      // If an unexpected error occurred, check whether the user is
      // actually signed in but suspended (session restored from cache).
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
        try {
          final suspended =
              await _ref.read(authServiceProvider).checkSuspended(user.id);
          if (suspended == true) {
            await _ref.read(authServiceProvider).signOut();
            state = state.copyWith(
              isLoading: false,
              serverError:
                  'Your account has been suspended. Contact support for details.',
            );
            return;
          }
        } catch (_) {}
      }
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

      // 1. Pre-check email uniqueness via Edge Function to prevent
      //    the confusing "confirmation sent" when the email is already
      //    registered (Supabase suppresses the duplicate-email error
      //    from signUp() to prevent user enumeration).
      final emailTaken = await _ref
          .read(authServiceProvider)
          .isEmailRegistered(email.trim());
      if (emailTaken) {
        state = state.copyWith(
          isLoading: false,
          serverError:
              'This email is already registered. Please log in instead, or reset your password if you forgot it.',
        );
        return;
      }

      // 2. Pre-check phone uniqueness via Supabase RPC to prevent registration collision.
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

      // 3. Sign up with Supabase Auth
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

      // 4. Create or update profile row in Supabase
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

// ── Forgot Password (send reset code) ────────────────────────────────────────

/// Immutable state for the "forgot password" email submission.
class ForgotPasswordState {
  const ForgotPasswordState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.message,
  });

  final bool isLoading;
  final String? error;
  final bool success;
  final String? message;

  ForgotPasswordState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? success,
    String? message,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
      message: message ?? this.message,
    );
  }
}

/// Handles sending the password-reset OTP email.
class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordNotifier(this._ref) : super(const ForgotPasswordState());

  final Ref _ref;

  Future<void> submit(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _ref.read(authServiceProvider).resetPassword(email);
    if (!mounted) return;
    state = ForgotPasswordState(
      success: result.success,
      message: result.message,
      error: result.success ? null : result.message,
    );
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Resets to initial state. Call when the screen is (re-)entered.
  /// No-op if state is already at default — avoids firing unnecessary
  /// state-change notifications during widget mount.
  void reset() {
    if (state == const ForgotPasswordState()) return;
    state = const ForgotPasswordState();
  }
}

final forgotPasswordNotifierProvider =
    StateNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>((ref) {
  return ForgotPasswordNotifier(ref);
});

// ── Verify Reset Code ────────────────────────────────────────────────────────

/// Immutable state for the OTP verification step.
class VerifyResetCodeState {
  const VerifyResetCodeState({
    this.isLoading = false,
    this.error,
    this.verified = false,
    this.cooldownSeconds = 0,
    this.resendMessage,
  });

  final bool isLoading;
  final String? error;
  final bool verified;
  final int cooldownSeconds;
  final String? resendMessage;

  VerifyResetCodeState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? verified,
    int? cooldownSeconds,
    String? resendMessage,
  }) {
    return VerifyResetCodeState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verified: verified ?? this.verified,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      resendMessage: resendMessage ?? this.resendMessage,
    );
  }
}

/// Handles OTP verification and resend with cooldown.
class VerifyResetCodeNotifier extends StateNotifier<VerifyResetCodeState> {
  VerifyResetCodeNotifier(this._ref) : super(const VerifyResetCodeState());

  final Ref _ref;
  Timer? _cooldownTimer;
  static const int _cooldownDuration = 30;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void startCooldown() {
    _cooldownTimer?.cancel();
    int remaining = _cooldownDuration;
    state = state.copyWith(cooldownSeconds: remaining);
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        remaining--;
        if (remaining <= 0) {
          _cooldownTimer?.cancel();
          if (mounted) state = state.copyWith(cooldownSeconds: 0);
        } else if (mounted) {
          state = state.copyWith(cooldownSeconds: remaining);
        }
      },
    );
  }

  Future<void> verify(String email, String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref
          .read(authServiceProvider)
          .verifyRecoveryOtp(email, code);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, verified: true);
    } on AuthException catch (e) {
      if (!mounted) return;
      String message;
      if (e.message.toLowerCase().contains('expired')) {
        message = 'This code has expired. Please request a new one.';
      } else if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('incorrect')) {
        message = 'Invalid code. Please try again.';
      } else {
        message = e.message;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> resend(String email) async {
    if (state.cooldownSeconds > 0) return;
    final result = await _ref.read(authServiceProvider).resetPassword(email);
    if (!mounted) return;
    if (result.success) {
      startCooldown();
      state = state.copyWith(
        resendMessage: 'A new code has been sent to your email.',
        clearError: true,
      );
    } else {
      state = state.copyWith(error: result.message);
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Resets to initial state and cancels the cooldown timer.
  /// Call when the screen is (re-)entered.
  /// No-op if state is already at default — avoids firing unnecessary
  /// state-change notifications during widget mount.
  void reset() {
    _cooldownTimer?.cancel();
    if (state == const VerifyResetCodeState()) return;
    state = const VerifyResetCodeState();
  }
}

final verifyResetCodeNotifierProvider =
    StateNotifierProvider<VerifyResetCodeNotifier, VerifyResetCodeState>((ref) {
  return VerifyResetCodeNotifier(ref);
});

// ── Reset Password (set new password) ────────────────────────────────────────

/// Immutable state for the new-password submission.
class ResetPasswordState {
  const ResetPasswordState({
    this.isLoading = false,
    this.error,
    this.done = false,
  });

  final bool isLoading;
  final String? error;
  final bool done;

  ResetPasswordState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? done,
  }) {
    return ResetPasswordState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      done: done ?? this.done,
    );
  }
}

/// Handles updating the password and signing out for clean re-login.
class ResetPasswordNotifier extends StateNotifier<ResetPasswordState> {
  ResetPasswordNotifier(this._ref) : super(const ResetPasswordState());

  final Ref _ref;

  Future<void> submit(String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authServiceProvider).updatePassword(newPassword);
      await _ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, done: true);
    } on AuthException catch (e) {
      if (!mounted) return;
      String message;
      final lower = e.message.toLowerCase();
      if (lower.contains('password') && lower.contains('weak')) {
        message =
            'Password is too weak. Please choose a stronger password (at least 6 characters).';
      } else if (lower.contains('expired') || lower.contains('invalid')) {
        message = 'This reset session has expired. Please request a new code.';
      } else {
        message = e.message;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') && msg.contains('weak')) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Password is too weak. Please choose a stronger password (at least 6 characters).',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Something went wrong. Please try again.',
        );
      }
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Resets to initial state. Call when the screen is (re-)entered.
  /// No-op if state is already at default — avoids firing unnecessary
  /// state-change notifications during widget mount.
  void reset() {
    if (state == const ResetPasswordState()) return;
    state = const ResetPasswordState();
  }
}

final resetPasswordNotifierProvider =
    StateNotifierProvider<ResetPasswordNotifier, ResetPasswordState>((ref) {
  return ResetPasswordNotifier(ref);
});
