import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has completed the onboarding flow.
///
/// Persisted in [SharedPreferences] so onboarding only shows once per
/// install. Used by the splash screen and onboarding redirect guards.
final onboardingSeenProvider = StateNotifierProvider<OnboardingSeenNotifier, bool>(
  (ref) => OnboardingSeenNotifier(),
);

class OnboardingSeenNotifier extends StateNotifier<bool> {
  OnboardingSeenNotifier() : super(false) {
    _load();
  }

  static const _key = 'onboarding_complete';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  /// Marks onboarding as complete and persists the flag.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = true;
  }
}
