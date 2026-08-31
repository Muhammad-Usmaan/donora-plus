import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../providers/chatbot_providers.dart';

/// AI chatbot screen powered by Qwen / Alibaba Cloud.
///
/// Visually similar to the in-app chat for consistency, but with a
/// distinct Secondary teal AppBar and bot avatar to differentiate
/// it from human conversations.
class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();

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

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _messageController.clear();
    ref.read(chatbotProvider.notifier).send(text.trim());
    // Delay scroll so the new message is laid out.
    Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(chatbotProvider);

    // Auto-scroll when messages change.
    ref.listen<ChatbotState>(chatbotProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bot avatar icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Donora Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'AI-powered help',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!state.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear conversation',
              onPressed: () =>
                  ref.read(chatbotProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages area ──────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.isEmpty
                    ? _WelcomePlaceholder()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: state.messages.length,
                        itemBuilder: (_, index) {
                          final msg = state.messages[index];
                          return _BotBubble(message: msg);
                        },
                      ),
          ),

          // ── Error banner ────────────────────────────────────────
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: colors.urgentContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 18, color: colors.urgent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.urgent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Typing indicator ────────────────────────────────────
          if (state.isAwaitingResponse)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypingIndicator(),
              ),
            ),

          // ── Quick-reply chips (shown when no messages yet) ──────
          if (state.isEmpty)
            _QuickReplies(onTap: _send),

          // ── Input bar ───────────────────────────────────────────
          _ChatbotInputBar(
            controller: _messageController,
            isSending: state.isAwaitingResponse,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Welcome placeholder ───────────────────────────────────────────────────────

class _WelcomePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Scrollable + centered: stays centered when there's room, but scrolls
    // instead of overflowing when vertical space is tight (small screens,
    // keyboard open).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 36,
                      color: colors.secondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Donora Assistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask me about blood donation, eligibility,\nverification, or finding donors near you.',
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
          ),
        ),
      ),
    );
  }
}

// ── Bot message bubble ────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.message});

  final BotMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Bot avatar (incoming only)
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined,
                  size: 14, color: colors.secondary),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? colors.primaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(isUser ? 16 : 4),
                  bottomRight:
                      Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: colors.secondary
                            .withValues(alpha: 0.2),
                        width: 1),
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
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Stagger each dot by 0.2s phase offset.
              final phase =
                  (_controller.value + i * 0.2) % 1.0;
              final opacity = 0.3 + (phase < 0.5
                  ? phase * 1.4
                  : (1.0 - phase) * 1.4);
              return Padding(
                padding: EdgeInsets.only(
                    left: i > 0 ? 4.0 : 0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.secondary
                        .withValues(alpha: opacity.clamp(0.3, 1.0)),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Quick-reply chips ─────────────────────────────────────────────────────────

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested questions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chatbotQuickReplies.map((label) {
              return GestureDetector(
                onTap: () => onTap(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          colors.secondary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.secondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _ChatbotInputBar extends StatelessWidget {
  const _ChatbotInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding + 80),
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
                border:
                    Border.all(color: colors.border, width: 1),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                enabled: !isSending,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask Donora Assistant…',
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
                onSubmitted: onSend,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              onPressed: isSending
                  ? null
                  : () => onSend(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.secondary,
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
