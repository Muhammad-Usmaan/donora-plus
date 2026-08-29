import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Floating pill-shaped bottom navigation bar — DocSpot-inspired design.
///
/// Near-black background (rounded-full, elevated shadow). All tabs are
/// icon-only; the active tab uses a filled brand-red pill with a
/// brighter icon, inactive tabs are dimmed.
///
/// 4 tabs (Home, Map, Chat, Profile) using a single rounded-stroke
/// Phosphor icon family — regular weight when inactive, fill weight
/// when active — so stroke style stays consistent across the bar.
///
/// Designed to replace the Material NavigationBar inside [MainShell].
class DonoraBottomNavBar extends StatelessWidget {
  const DonoraBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
    ),
    _NavItem(
      icon: PhosphorIconsRegular.mapPin,
      activeIcon: PhosphorIconsFill.mapPin,
    ),
    _NavItem(
      icon: PhosphorIconsRegular.chatCircle,
      activeIcon: PhosphorIconsFill.chatCircle,
    ),
    _NavItem(
      icon: PhosphorIconsRegular.user,
      activeIcon: PhosphorIconsFill.user,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A1A1E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(
              _items.length,
              (i) => _buildItem(context, i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: PhosphorIcon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? Colors.white : Colors.white54,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon});

  final PhosphorIconData icon;
  final PhosphorIconData activeIcon;
}
