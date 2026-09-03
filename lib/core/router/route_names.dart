/// Named route constants used by GoRouter and navigation calls.
///
/// Always reference these instead of hard-coding path strings:
///   context.goNamed(RouteNames.home);
class RouteNames {
  const RouteNames._();

  // ── Public routes ───────────────────────────────────────────────────
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String auth = 'auth';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';

  // ── Authenticated routes ────────────────────────────────────────────
  static const String home = 'home';
  static const String verification = 'verification';

  // ── Home sub-routes (bottom-nav shell) ──────────────────────────────
  static const String map = 'map';
  static const String requests = 'requests';
  static const String requestCreate = 'request-create';
  static const String requestDetail = 'request-detail';
  static const String donors = 'donors';
  static const String donorDetail = 'donor-detail';
  static const String chat = 'chat';
  static const String conversation = 'conversation';
  static const String chatbot = 'chatbot';

  // ── Other authenticated routes ──────────────────────────────────────
  static const String notifications = 'notifications';
  static const String profile = 'profile';
  static const String locationPicker = 'location-picker';
  static const String helpFaq = 'help-faq';
  static const String myRequests = 'my-requests';
}

/// Route path segments (used inside GoRoute definitions).
class RoutePaths {
  const RoutePaths._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String verification = '/verification';
  static const String map = '/map';
  static const String requests = '/requests';
  static const String requestCreate = '/requests/create';
  static const String requestDetail = '/requests/:id';
  static const String donors = '/donors';
  static const String donorDetail = '/donors/:id';
  static const String chat = '/chat';
  static const String conversation = '/chat/:id';
  static const String chatbot = '/chatbot';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String locationPicker = '/location-picker';
  static const String helpFaq = '/help-faq';
  static const String myRequests = '/my-requests';
}
