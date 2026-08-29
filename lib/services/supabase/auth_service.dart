import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Sends a password-reset email to [email].
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
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

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// The currently authenticated user, or null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign-in, sign-out, token refresh, etc.).
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
