import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';

/// Reusable "Ask Donora AI" card component shown on seeker and donor home screens.
class AskDonoraAiCard extends StatelessWidget {
  const AskDonoraAiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.pushNamed(RouteNames.chatbot),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: PhosphorIcon(
                  PhosphorIconsRegular.sparkle,
                  color: colors.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask Donora AI', style: context.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Get quick answers about donating or requesting blood.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: colors.textMedium,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
