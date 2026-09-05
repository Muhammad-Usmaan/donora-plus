import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../providers/home_providers.dart';

/// Pill-shaped Blood / Platelets segmented tab control.
///
/// Placed above the request feed on both seeker and donor home screens.
/// Tapping a segment updates [donationTypeFilterProvider], which the feed
/// stream providers watch to re-query with the matching `donation_type`
/// filter.
class DonationTypeTabs extends ConsumerWidget {
  const DonationTypeTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(donationTypeFilterProvider);
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            _TabButton(
              label: 'Blood',
              isActive: selected == DonationType.blood,
              activeColor: colors.primary,
              onTap: () =>
                  ref.read(donationTypeFilterProvider.notifier).state =
                      DonationType.blood,
            ),
            _TabButton(
              label: 'Platelets',
              isActive: selected == DonationType.platelet,
              activeColor: colors.primary,
              onTap: () =>
                  ref.read(donationTypeFilterProvider.notifier).state =
                      DonationType.platelet,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: isActive ? Colors.white : colors.textMedium,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
