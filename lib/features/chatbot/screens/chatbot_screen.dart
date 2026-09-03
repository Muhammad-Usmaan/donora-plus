import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/utils/extensions.dart';
import '../providers/chatbot_providers.dart';
import '../widgets/recent_chats_sheet.dart';

/// AI chatbot screen powered by Qwen / Alibaba Cloud.
///
/// Uses the standard Donora+ AppBar style for consistency with Home,
/// Profile, and other screens. The floating input bar and word-by-word
/// reveal animation differentiate it visually.
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
        _scrollController.position.maxScrollExtent,
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
        title: Text(state.title.isNotEmpty ? state.title : 'Donora AI'),
        actions: [
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.clockClockwise,
              size: 20,
            ),
            tooltip: 'Recent chats',
            onPressed: () => showRecentChatsSheet(context, ref),
          ),
          if (!state.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear conversation',
              onPressed: () => ref.read(chatbotProvider.notifier).clear(),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Messages area ──────────────────────────────────────
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.isEmpty
                    ? _EmptyState(onTap: _send)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: state.messages.length,
                        itemBuilder: (_, index) {
                          final msg = state.messages[index];
                          return _BotBubble(
                            message: msg,
                            isLatest: index == state.messages.length - 1,
                          );
                        },
                      ),
              ),

              // ── Error banner ────────────────────────────────────────
              if (state.error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: colors.urgentContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: colors.urgent),
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
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 90),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TypingIndicator(),
                  ),
                ),
            ],
          ),

          // ── Floating input bar ────────────────────────────────────
          _FloatingInputBar(
            controller: _messageController,
            isSending: state.isAwaitingResponse,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Empty state (greeting + example prompts) ──────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});

  final ValueChanged<String> onTap;

  static const _examplePrompts = <String>[
    'Am I eligible to donate?',
    'How does verification work?',
    'What\'s the cooldown period?',
    'Find donors near me',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        // ── Greeting bubble (bot style) ──────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 14,
                color: colors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: colors.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Hi, I\'m Donora AI. Ask me anything about '
                  'blood donation eligibility, verification, '
                  'or how the app works.',
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
        const SizedBox(height: 32),

        // ── "Examples" label ────────────────────────────────────
        Text(
          'Examples',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        // ── Example chips (vertical stack, SecondaryButton style) ──
        ..._examplePrompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onTap(prompt),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colors.card,
                  foregroundColor: colors.textHigh,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bot message bubble ────────────────────────────────────────────────────────

class _BotBubble extends StatefulWidget {
  const _BotBubble({required this.message, this.isLatest = false});

  final BotMessage message;
  final bool isLatest;

  @override
  State<_BotBubble> createState() => _BotBubbleState();
}

class _BotBubbleState extends State<_BotBubble> {
  Timer? _revealTimer;
  int _visibleWords = 0;

  @override
  void initState() {
    super.initState();
    // Only animate the latest bot (assistant) message.
    if (widget.isLatest && !widget.message.isUser) {
      _startReveal();
    } else {
      _revealAll();
    }
  }

  @override
  void didUpdateWidget(covariant _BotBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      _revealTimer?.cancel();
      if (widget.isLatest && !widget.message.isUser) {
        _startReveal();
      } else {
        _revealAll();
      }
    } else if (oldWidget.isLatest != widget.isLatest && !widget.isLatest) {
      // No longer the latest message — show everything immediately.
      _revealTimer?.cancel();
      _revealAll();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _startReveal() {
    final words = widget.message.content.split(' ');
    if (words.isEmpty) return;
    _visibleWords = 0;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      if (_visibleWords < words.length) {
        setState(() => _visibleWords++);
      } else {
        _revealTimer?.cancel();
      }
    });
  }

  void _revealAll() {
    _visibleWords = widget.message.content.split(' ').length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = widget.message.isUser;

    // Build visible portion of the text.
    final words = widget.message.content.split(' ');
    final visibleText = words
        .take(_visibleWords.clamp(0, words.length))
        .join(' ');
    final displayText = (_revealTimer?.isActive == true)
        ? visibleText
        : widget.message.content;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              child: Icon(
                Icons.smart_toy_outlined,
                size: 14,
                color: colors.secondary,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? colors.primaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: colors.secondary.withValues(alpha: 0.2),
                        width: 1,
                      ),
              ),
              child: Text(
                displayText,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              final phase = (_controller.value + i * 0.2) % 1.0;
              final opacity =
                  0.3 + (phase < 0.5 ? phase * 1.4 : (1.0 - phase) * 1.4);
              return Padding(
                padding: EdgeInsets.only(left: i > 0 ? 4.0 : 0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(
                      alpha: opacity.clamp(0.3, 1.0),
                    ),
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

// ── Floating input bar ────────────────────────────────────────────────────

class _FloatingInputBar extends StatelessWidget {
  const _FloatingInputBar({
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom:
          12 + (keyboardHeight > 0 ? 0 : MediaQuery.of(context).padding.bottom),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field (standard InputDecoration from theme)
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    enabled: !isSending,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ask Donora AI anything\u2026',
                      isDense: true,
                    ),
                    onSubmitted: onSend,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              SizedBox(
                width: 40,
                height: 40,
                child: ElevatedButton(
                  onPressed: isSending ? null : () => onSend(controller.text),
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
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
