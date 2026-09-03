import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/chatbot_providers.dart';

/// Shows the "Recent Chats" draggable bottom sheet.
///
/// Lists all AI conversation threads sorted by [last_message_at]
/// descending and offers a "New Chat" action.
void showRecentChatsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RecentChatsSheet(ref: ref),
  );
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _RecentChatsSheet extends ConsumerWidget {
  const _RecentChatsSheet({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(chatbotProvider);
    final threads = state.threads;
    final currentId = state.currentConversationId;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              // ── Drag handle ────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header row ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Chats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textHigh,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(context).pop();
                      await ref.read(chatbotProvider.notifier).newChat();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'New Chat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Switch between your AI conversations.',
                style: TextStyle(fontSize: 13, color: colors.textMedium),
              ),
              const SizedBox(height: 20),

              // ── Thread list ────────────────────────────────────────
              if (threads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 36, color: colors.textMedium),
                      const SizedBox(height: 12),
                      Text(
                        'No conversations yet.\nStart a new chat!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMedium,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...threads.map((thread) {
                  final isActive = thread.id == currentId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(chatbotProvider.notifier)
                            .switchConversation(thread.id);
                      },
                      borderColor:
                          isActive ? colors.secondary : null,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.secondaryContainer
                                  : colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy_outlined,
                              size: 18,
                              color: isActive
                                  ? colors.secondary
                                  : colors.textMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  thread.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textHigh,
                                  ),
                                ),
                                if (thread.lastMessageAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.timeAgo(
                                        thread.lastMessageAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textMedium,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right,
                              size: 20, color: colors.textMedium),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
