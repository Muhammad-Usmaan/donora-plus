import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env_config.dart';

/// Result of a password-reset email request.
class PasswordResetResult {
  const PasswordResetResult({required this.success, this.message});
  final bool success;

  /// User-facing message. On success this is generic for security reasons
  /// (Supabase does not reveal whether an account exists for the email).
  final String? message;
}

/// Wraps Supabase authentication methods used by the auth feature.
class SupabaseAuthService {
  const SupabaseAuthService(this._client);

  final SupabaseClient _client;

  /// Signs in with email/identifier and password.
  Future<AuthResponse> signInWithPassword(String email, String password) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new account with email and password.
  ///
  /// [data] is stored in user_metadata and can include name, phone, role.
  /// The confirmation email redirects to [EnvConfig.emailConfirmRedirectUrl].
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
        emailRedirectTo: EnvConfig.emailConfirmRedirectUrl,
      );
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuthService] signUp error: ${e.statusCode} — ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseAuthService] signUp unexpected error: $e');
      rethrow;
    }
  }

  /// Sends a password-reset email to [email].
  ///
  /// The email contains a link that redirects to
  /// [EnvConfig.passwordResetRedirectUrl].
  ///
  /// Always returns a successful result for security reasons — Supabase
  /// does not reveal whether an account exists for the given email.
  /// Only returns failure for client-side validation errors or network issues.
  Future<PasswordResetResult> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: EnvConfig.passwordResetRedirectUrl,
      );
      return const PasswordResetResult(
        success: true,
        message: 'If an account exists for that email, a reset link has been sent.',
      );
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuthService] resetPassword error: ${e.statusCode} — ${e.message}');
      // Rate limiting
      if (e.statusCode == 'over_email_send_rate_limit') {
        return const PasswordResetResult(
          success: false,
          message: 'Too many requests. Please try again later.',
        );
      }
      // Invalid email format or other auth errors — still show generic
      // message for security, but log the real error for debugging.
      return const PasswordResetResult(
        success: true, // Generic response: don't reveal account existence
        message: 'If an account exists for that email, a reset link has been sent.',
      );
    } catch (e) {
      debugPrint('[SupabaseAuthService] resetPassword unexpected error: $e');
      return const PasswordResetResult(
        success: false,
        message: 'Unable to send reset email. Please check your connection and try again.',
      );
    }
  }

  /// Sends an OTP code to [phone] via SMS.
  Future<void> signInWithOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Verifies the OTP token for the given [phone].
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return _client.auth.verifyOTP(
      type: OtpType.sms,
      token: token,
      phone: phone,
    );
  }

  /// Verifies a recovery OTP for password reset.
  ///
  /// On success, Supabase creates a temporary session that allows
  /// calling [updatePassword] to set the new password.
  Future<AuthResponse> verifyRecoveryOtp(String email, String token) async {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  /// Updates the current user's password.
  ///
  /// Works both for authenticated users changing their password and for
  /// users in a recovery session (after clicking a password-reset link
  /// or verifying a recovery OTP).
  /// Throws [AuthException] on failure (e.g. weak password, expired session).
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Checks whether a phone number is already associated with an account.
  Future<bool> isPhoneRegistered(String phone) async {
    final res = await _client.rpc(
      'is_phone_registered',
      params: {'check_phone': phone},
    );
    if (res is bool) return res;
    return false;
  }

  /// Checks whether an email is already registered in Supabase Auth.
  ///
  /// Calls the `check-email-exists` Edge Function which uses the service
  /// role key server-side to look up the email in auth.users.  Returns
  /// `true` if the email is already taken, `false` if available.
  /// On any error (network, function failure) returns `false` to avoid
  /// blocking signup — the actual signUp() call will catch real conflicts.
  Future<bool> isEmailRegistered(String email) async {
    try {
      final response = await _client.functions.invoke(
        'check-email-exists',
        body: {'email': email.trim().toLowerCase()},
      );
      return response.data?['exists'] == true;
    } catch (e) {
      debugPrint('[SupabaseAuthService] isEmailRegistered error: $e');
      // Fail open — let signUp() handle the real conflict.
      return false;
    }
  }

  /// Checks whether the given [userId]'s profile is suspended.
  ///
  /// Returns:
  ///   `true`  — profile exists and is_suspended is true
  ///   `false` — profile exists and is_suspended is false
  ///   `null`  — no profile row found (orphaned / deleted account)
  Future<bool?> checkSuspended(String userId) async {
    final data = await _client
        .from('profiles')
        .select('is_suspended')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return (data['is_suspended'] as bool?) ?? false;
  }

  /// Checks whether a profile row exists for the given [userId].
  ///
  /// Used as a safety-net after login to detect orphaned accounts
  /// (Auth user exists, profile was deleted).  Must NOT be called on
  /// the signup path — only on the login / session-restore path.
  Future<bool> profileExists(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return data != null;
  }

  /// The currently authenticated user, or null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign-in, sign-out, token refresh, etc.).
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
