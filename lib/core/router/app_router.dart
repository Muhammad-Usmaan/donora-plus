import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../core/providers/auth_providers.dart';
import '../../features/verification/screens/verification_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/requests/providers/request_detail_provider.dart';
import '../../features/requests/screens/requests_screen.dart';
import '../../features/requests/screens/request_create_screen.dart';
import '../../features/requests/screens/request_detail_screen.dart';
import '../../features/donors/screens/donors_screen.dart';
import '../../features/donors/screens/donor_detail_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/conversation_screen.dart';
import '../../features/chatbot/screens/chatbot_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/my_requests_screen.dart';
import '../../features/profile/screens/help_faq_screen.dart';
import '../../features/requests/screens/location_picker_screen.dart';
import '../widgets/main_shell.dart';

/// Navigator key for the root navigator.
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The GoRouter instance exposed via Riverpod.
///
/// Usage:
///   ref.watch(routerProvider).go(RoutePaths.home);
///   ref.watch(routerProvider).pushNamed(RouteNames.requestCreate);
/// Notifier that triggers GoRouter redirect re-evaluation on auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Create a refresh notifier that fires on every auth state change
  // so GoRouter re-evaluates redirects (e.g. login → home, logout → auth).
  final authRefresh = _AuthRefreshNotifier(ref);

  ref.onDispose(() {
    authRefresh.dispose();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    refreshListenable: authRefresh,
    routes: [
      // ── Splash (initial entry point) ──────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.splash,
        path: RoutePaths.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.onboarding,
        path: RoutePaths.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.auth,
        path: RoutePaths.auth,
        builder: (_, _) => const AuthScreen(),
      ),

      // ── Bottom-nav shell (StatefulShellRoute preserves each tab) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Home tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.home,
                path: RoutePaths.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          // Map tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.map,
                path: RoutePaths.map,
                builder: (_, _) => const MapScreen(),
              ),
            ],
          ),
          // Chat tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.chat,
                path: RoutePaths.chat,
                builder: (_, _) => const ChatScreen(),
              ),
            ],
          ),
          // Profile tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.profile,
                path: RoutePaths.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (pushed on top of the shell) ─────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.verification,
        path: RoutePaths.verification,
        builder: (_, _) => const VerificationScreen(),
      ),
      // AI assistant — full-screen route; the Home "Ask Donora AI"
      // card is its single entry point (not a bottom-nav tab).
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.chatbot,
        path: RoutePaths.chatbot,
        builder: (_, _) => const ChatbotScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.requests,
        path: RoutePaths.requests,
        builder: (_, _) => const RequestsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.requestCreate,
        path: RoutePaths.requestCreate,
        builder: (_, state) {
          final extra = state.extra;
          RequestDetail? initialRequest;
          if (extra is RequestDetail) {
            initialRequest = extra;
          }
          final editRequestId =
              state.uri.queryParameters['editId'] ?? initialRequest?.id;
          return RequestCreateScreen(
            initialRequest: initialRequest,
            editRequestId: editRequestId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.requestDetail,
        path: RoutePaths.requestDetail,
        builder: (_, state) => RequestDetailScreen(
          requestId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.donors,
        path: RoutePaths.donors,
        builder: (_, _) => const DonorsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.donorDetail,
        path: RoutePaths.donorDetail,
        builder: (_, state) => DonorDetailScreen(
          donorId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.conversation,
        path: RoutePaths.conversation,
        builder: (_, state) => ConversationScreen(
          conversationId: state.pathParameters['id'] ?? '',
          otherUserName: state.uri.queryParameters['name'],
          otherUserPhotoUrl: state.uri.queryParameters['photo'],
          otherUserIsVerified: state.uri.queryParameters['verified'] == '1',
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.notifications,
        path: RoutePaths.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.helpFaq,
        path: RoutePaths.helpFaq,
        builder: (_, _) => const HelpFaqScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.myRequests,
        path: RoutePaths.myRequests,
        builder: (_, _) => const MyRequestsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: RouteNames.locationPicker,
        path: RoutePaths.locationPicker,
        builder: (_, state) => LocationPickerScreen(
          initialLat: double.tryParse(
              state.uri.queryParameters['lat'] ?? ''),
          initialLng: double.tryParse(
              state.uri.queryParameters['lng'] ?? ''),
        ),
      ),
    ],
    // ── Redirect guards ──────────────────────────────────────────────
    // Safety net: prevents deep-linking into authenticated routes when
    // the user is signed out. The splash screen handles initial routing;
    // this catches edge cases (e.g. browser back/forward, deep links).
    redirect: (context, state) {
      // Read the user directly from the auth service (synchronous) to avoid
      // the StreamProvider race condition where authStateProvider is still
      // in AsyncLoading on the first redirect evaluation after sign-in.
      final user = ref.read(authServiceProvider).currentUser;
      final path = state.matchedLocation;
      final isAuthFlow = path == RoutePaths.splash ||
          path == RoutePaths.onboarding ||
          path == RoutePaths.auth ||
          path == RoutePaths.locationPicker;

      // Signed-out user trying to access a protected route → auth.
      if (user == null && !isAuthFlow) return RoutePaths.auth;

      // Signed-in user trying to access auth/onboarding → home.
      if (user != null &&
          (path == RoutePaths.auth || path == RoutePaths.onboarding)) {
        return RoutePaths.home;
      }

      return null; // no redirect
    },
  );
});
