import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          name: widget.otherUserName,
          photoUrl: widget.otherUserPhotoUrl,
          isVerified: widget.otherUserIsVerified,
        ),
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

                        // Show timestamp if this is the first message
                        // or if there's a >5 min gap from the previous one.
                        final showTimestamp = index == 0 ||
                            msg.createdAt
                                    .difference(messages[index - 1].createdAt)
                                    .inMinutes >
                                5;

                        return _MessageBubble(
                          message: msg,
                          isOutgoing: isOutgoing,
                          showTimestamp: showTimestamp,
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

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.isVerified,
    this.name,
    this.photoUrl,
  });

  final String? name;
  final String? photoUrl;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayName = name ?? 'Conversation';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small avatar
        photoUrl != null && photoUrl!.isNotEmpty
            ? CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(photoUrl!),
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
                if (isVerified) ...[
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

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOutgoing,
    required this.showTimestamp,
  });

  final ChatMessage message;
  final bool isOutgoing;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // Time gap label
        if (showTimestamp) ...[
          const SizedBox(height: 12),
          Text(
            _formatTimestamp(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: colors.textMedium,
              fontWeight: FontWeight.w500,
            ),
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
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOutgoing
                  ? colors.primaryContainer
                  : colors.card,
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
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: colors.textHigh,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "10:32 AM" for today, "Mon 10:32 AM" for older messages.
  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final time =
        '${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}'
        ':${dt.minute.toString().padLeft(2, '0')} '
        '${dt.hour >= 12 ? 'PM' : 'AM'}';

    if (isToday) return time;

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]} $time';
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
