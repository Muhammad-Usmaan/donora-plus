import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../providers/home_providers.dart';
import '../widgets/seeker_home_view.dart';
import '../widgets/donor_home_view.dart';

/// Home dashboard — renders differently based on the active role.
///
/// AppBar: "Hi, {name}" greeting + notification bell + role-switch pill.
/// Body: SeekerHomeView or DonorHomeView.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Periodic refresh every 15 seconds as a fallback for stale data
    // (the StreamProviders already push real-time updates).
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.invalidate(activeRequestsProvider);
        ref.invalidate(urgentRequestsStreamProvider);
        ref.invalidate(nearbyDonorsProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = ref.watch(activeRoleProvider);
    final profileAsync = ref.watch(userProfileProvider);

    // Realtime toast when new urgent requests arrive (donor view).
    ref.listen(urgentRequestsStreamProvider, (prev, next) {
      if (prev == null) return;
      final prevData = prev.valueOrNull;
      final nextData = next.valueOrNull;
      if (prevData != null &&
          nextData != null &&
          nextData.length > prevData.length) {
        context.showSnackBar('New urgent request nearby');
      }
    });

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: profileAsync.whenOrNull(
              data: (p) => _Greeting(name: p.name, isTopDonor: p.isTopDonor),
            ) ??
            Text(
              'Donora+',
              style: context.textTheme.titleLarge
                  ?.copyWith(color: context.colors.primary),
            ),
        actions: [
          _NotificationBell(),
          const SizedBox(width: 12),
        ],
      ),
      body: activeRole == 'seeker'
          ? const SeekerHomeView()
          : const DonorHomeView(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Greeting
// ═══════════════════════════════════════════════════════════════════════════════

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.isTopDonor});

  final String name;
  final bool isTopDonor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Hi, ${name.split(' ').first}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isTopDonor) ...[
          const SizedBox(width: 6),
          Icon(Icons.star, size: 18, color: context.colors.warning),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Notification bell
// ═══════════════════════════════════════════════════════════════════════════════

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.pushNamed(RouteNames.notifications),
        ),
        // Red dot — always shown for MVP; replace with unread-count
        // provider when the notifications feature is built.
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.colors.urgent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// (Role switch moved to Profile & Settings screen)
