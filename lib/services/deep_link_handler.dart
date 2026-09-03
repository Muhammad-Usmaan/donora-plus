import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks password-reset recovery state so the UI layer knows when to
/// show the "set new password" screen.
///
/// **How it works:**
/// `supabase_flutter` already observes OS-level deep links internally.
/// When the user taps the password-reset link in their email, the package:
///   1. Receives the deep link (`donora-plus://reset-password?code=...`)
///   2. Exchanges the PKCE code for a recovery session automatically
///   3. Emits [AuthChangeEvent.passwordRecovery] on the auth state stream
///
/// This class listens for that event and exposes [isPasswordRecoveryActive]
/// so the router / UI can navigate accordingly.
class DeepLinkHandler {
  DeepLinkHandler._();

  static StreamSubscription<AuthState>? _sub;

  /// Whether a password-reset recovery session is currently active.
  ///
  /// Set to `true` when [AuthChangeEvent.passwordRecovery] is received
  /// (i.e. the user tapped the reset link and Supabase exchanged the code).
  /// The UI should check this flag to decide whether to show the
  /// "set new password" screen, and reset it to `false` after the password
  /// has been updated successfully.
  static bool get isPasswordRecoveryActive => _passwordRecoveryActive;
  static bool _passwordRecoveryActive = false;

  /// Starts listening for auth state changes that indicate a password
  /// recovery session.
  ///
  /// Call once after [Supabase.initialize]. Safe to call multiple times.
  static void start() {
    if (_sub != null) return;

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          debugPrint('[DeepLinkHandler] password recovery session detected');
          _passwordRecoveryActive = true;
        }
      },
      onError: (err) => debugPrint('[DeepLinkHandler] stream error: $err'),
    );
  }

  /// Clears the recovery flag. Call after the user has successfully set
  /// a new password (or cancelled the flow).
  static void clearRecoveryFlag() {
    _passwordRecoveryActive = false;
  }

  /// Stops listening. Primarily useful in tests.
  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
