import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/chat_providers.dart';

/// Chat list screen — shows all conversations for the current user.
///
/// Tapping a conversation navigates to the ConversationScreen.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final conversationsAsync = ref.watch(conversationsListProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Messages'),
        centerTitle: false,
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const _EmptyConversationsState();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsListProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                return _ConversationCard(conversation: conversations[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: colors.textMedium),
                const SizedBox(height: 12),
                Text(
                  'Could not load conversations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conversation card ─────────────────────────────────────────────────────────

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        context.pushNamed(
          RouteNames.conversation,
          pathParameters: {'id': conversation.id},
        );
      },
      child: Row(
        children: [
          // Avatar
          _ChatAvatar(
            name: conversation.otherUserName,
            photoUrl: conversation.otherUserPhotoUrl,
          ),
          const SizedBox(width: 12),

          // Name + preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conversation.otherUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textHigh,
                        ),
                      ),
                    ),
                    if (conversation.otherUserIsVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Last message preview
                if (conversation.lastMessage != null)
                  Text(
                    conversation.lastMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: conversation.hasUnread
                          ? colors.textHigh
                          : colors.textMedium,
                      fontWeight: conversation.hasUnread
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  )
                else
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMedium,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Timestamp + unread badge column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (conversation.lastMessageAt != null)
                Text(
                  Formatters.timeAgo(conversation.lastMessageAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMedium,
                  ),
                ),
              if (conversation.hasUnread) ...[
                const SizedBox(height: 6),
                _UnreadPill(count: conversation.unreadCount),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chat avatar ───────────────────────────────────────────────────────────────

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: colors.primaryContainer,
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ── Unread pill ───────────────────────────────────────────────────────────────

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyConversationsState extends StatelessWidget {
  const _EmptyConversationsState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration placeholder
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Start a conversation by tapping "Message"\non a donor\'s profile or request response.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
