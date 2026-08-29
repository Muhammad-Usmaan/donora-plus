import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'donora_bottom_nav.dart';

/// Persistent bottom navigation bar shell for the main app tabs.
///
/// Floating pill-shaped dark nav bar (DocSpot-inspired design) where
/// only the active tab shows its icon + label inside a colored pill;
/// inactive tabs show icon only, dimmed.
/// 4 tabs: Home, Map, Chat, Profile.
/// Used as the `builder` of StatefulShellRoute.indexedStack.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: DonoraBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
