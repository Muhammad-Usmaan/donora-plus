import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/chat_providers.dart';

/// Real-time conversation screen between two users.
///
/// Outgoing bubbles: Primary Container, right-aligned.
/// Incoming bubbles: white surface with Neutral-300 border, left-aligned.
/// Timestamps shown beneath bubble groups separated by time gaps.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.otherUserIsVerified = false,
  });

  final String conversationId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final bool otherUserIsVerified;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  // ID of the first unread message (from other user) at the time the
  // screen opened. Used to render the "UNREAD MESSAGES" divider.
  // Captured once before the mark-as-read call erases the information.
  String? _firstUnreadMessageId;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when the conversation is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markMessagesReadProvider)(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final success = await ref.read(sendMessageProvider)(
      conversationId: widget.conversationId,
      content: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    // Watch the raw stream for auto-scroll trigger.
    final streamAsync = ref.watch(
      conversationMessagesStreamProvider(widget.conversationId),
    );
    final messages = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );

    // Capture the first-unread divider position once, before the
    // mark-as-read call (fired in initState post-frame) updates the
    // DB and the realtime stream pushes is_read = true for these rows.
    //
    // Race-condition handling:
    // - The realtime stream emits current DB state on subscribe (is_read = false).
    // - The mark-as-read call fires AFTER the first frame (post-frame callback).
    // - We snapshot _firstUnreadMessageId on the FIRST build where both
    //   messages and currentUserId are available — this is guaranteed to
    //   happen before the mark-as-read response arrives via realtime.
    // - Once captured, the divider ID is never recomputed, so the divider
    //   stays in the correct position even after messages are marked read.
    if (_firstUnreadMessageId == null && messages.isNotEmpty) {
      final uid = currentUserId;
      if (uid.isNotEmpty) {
        final firstUnread = messages.cast<ChatMessage?>().firstWhere(
          (m) => m != null && m.senderId != uid && !m.isRead,
          orElse: () => null,
        );
        _firstUnreadMessageId = firstUnread?.id;
      }
    }

    // Auto-scroll when new messages arrive.
    ref.listen(conversationMessagesStreamProvider(widget.conversationId),
        (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: _AppBarTitle(
          conversationId: widget.conversationId,
          name: widget.otherUserName,
          photoUrl: widget.otherUserPhotoUrl,
          isVerified: widget.otherUserIsVerified,
        ),
        actions: [
          _CallButton(conversationId: widget.conversationId),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Messages area ─────────────────────────────────────
          Expanded(
            child: streamAsync.when(
              data: (_) => messages.isEmpty
                  ? _EmptyMessagesPlaceholder(
                      name: widget.otherUserName ?? 'this person',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final msg = messages[index];
                        final isOutgoing = msg.senderId == currentUserId;

                        // Show date separator if first message or >30 min gap / day change.
                        final showDateHeader = index == 0 ||
                            msg.createdAt.toLocal().day !=
                                messages[index - 1].createdAt.toLocal().day;

                        // Show "UNREAD MESSAGES" divider above the first
                        // message that was unread when the screen opened.
                        final showUnreadDivider = _firstUnreadMessageId != null &&
                            msg.id == _firstUnreadMessageId;

                        return _MessageBubble(
                          message: msg,
                          isOutgoing: isOutgoing,
                          showDateHeader: showDateHeader,
                          showUnreadDivider: showUnreadDivider,
                        );
                      },
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load messages',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Input bar ─────────────────────────────────────────
          _MessageInputBar(
            controller: _messageController,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── App bar title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends ConsumerWidget {
  const _AppBarTitle({
    required this.conversationId,
    required this.isVerified,
    this.name,
    this.photoUrl,
  });

  final String conversationId;
  final String? name;
  final String? photoUrl;
  final bool isVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final otherInfo = ref
        .watch(conversationOtherParticipantProvider(conversationId))
        .valueOrNull;

    final displayName = (name != null && name!.isNotEmpty && name != 'null')
        ? name!
        : (otherInfo != null && otherInfo.name.isNotEmpty
            ? otherInfo.name
            : 'Conversation');

    final displayPhoto =
        (photoUrl != null && photoUrl!.isNotEmpty && photoUrl != 'null')
            ? photoUrl
            : otherInfo?.photoUrl;

    final displayVerified = isVerified || (otherInfo?.isVerified ?? false);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small avatar
        displayPhoto != null && displayPhoto.isNotEmpty
            ? CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(displayPhoto),
                backgroundColor: colors.primaryContainer,
              )
            : CircleAvatar(
                radius: 16,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
        const SizedBox(width: 10),

        // Name + badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textHigh,
                    ),
                  ),
                ),
                if (displayVerified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(compact: true),
                ],
              ],
            ),
            Text(
              'Online',
              style: TextStyle(
                fontSize: 11,
                color: colors.textMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Call button ───────────────────────────────────────────────────────────────

class _CallButton extends ConsumerWidget {
  const _CallButton({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherInfo = ref
        .watch(conversationOtherParticipantProvider(conversationId))
        .valueOrNull;

    final phone = otherInfo?.phone;
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(Icons.phone_outlined, color: context.colors.primary),
      onPressed: () async {
        final uri = Uri.parse('tel:$phone');
        try {
          if (!await launchUrl(uri)) {
            if (context.mounted) {
              context.showSnackBar('No dialer app available to place the call.', isError: true);
            }
          }
        } catch (e) {
          if (context.mounted) {
            context.showSnackBar('No dialer app available to place the call.', isError: true);
          }
        }
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOutgoing,
    required this.showDateHeader,
    this.showUnreadDivider = false,
  });

  final ChatMessage message;
  final bool isOutgoing;
  final bool showDateHeader;
  final bool showUnreadDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final localTime = message.createdAt.toLocal();

    return Column(
      children: [
        // Date gap label
        if (showDateHeader) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              _formatDateHeader(localTime),
              style: TextStyle(
                fontSize: 11,
                color: colors.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Unread messages divider
        if (showUnreadDivider) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'UNREAD MESSAGES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMedium,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colors.border.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 4),

        // Bubble
        Align(
          alignment:
              isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
              minWidth: 70,
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: isOutgoing ? colors.primaryContainer : colors.card,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                bottomRight: Radius.circular(isOutgoing ? 4 : 16),
              ),
              border: isOutgoing
                  ? null
                  : Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textHigh,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      _formatTime(localTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textMedium.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isOutgoing) ...[
                      const SizedBox(width: 3),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 13,
                        color: message.isRead
                            ? colors.primary
                            : colors.textMedium.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Formats time as "10:32 AM" in the user's local timezone.
  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Formats date headers: "Today", "Yesterday", or "Mon, Aug 30".
  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) return 'Today';
    if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }
}

// ── Empty messages placeholder ────────────────────────────────────────────────

class _EmptyMessagesPlaceholder extends StatelessWidget {
  const _EmptyMessagesPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_outlined,
                size: 32,
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Send a message to $name',
              style: TextStyle(
                fontSize: 14,
                color: colors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colors.textMedium,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: isSending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
