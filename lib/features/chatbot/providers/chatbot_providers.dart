import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers.dart';
import '../../../services/chatbot/chatbot_service.dart';
import '../../../services/chatbot/qwen_chatbot_service.dart';
import '../../home/providers/home_providers.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// A single message in the chatbot conversation.
class BotMessage {
  const BotMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  /// 'user' or 'assistant'
  final String role;
  final String content;
  final DateTime timestamp;

  bool get isUser => role == 'user';

  Map<String, String> toHistoryEntry() => {'role': role, 'content': content};
}

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable state for the chatbot conversation.
class ChatbotState {
  const ChatbotState({
    this.messages = const [],
    this.isAwaitingResponse = false,
    this.error,
  });

  final List<BotMessage> messages;
  final bool isAwaitingResponse;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  /// Conversation history for the API (excludes the current message).
  List<Map<String, String>> get history =>
      messages.map((m) => m.toHistoryEntry()).toList();

  ChatbotState copyWith({
    List<BotMessage>? messages,
    bool? isAwaitingResponse,
    String? error,
    bool clearError = false,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isAwaitingResponse: isAwaitingResponse ?? this.isAwaitingResponse,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier(this._service, this._ref) : super(const ChatbotState());

  final ChatbotService _service;
  final Ref _ref;

  /// Builds a plain-text summary of the current user's profile for the
  /// system prompt.  Awaits the profile Future so context is always
  /// available even on the very first message.  Returns null when no
  /// profile is available.
  Future<String?> _buildUserContext() async {
    try {
      final profile = await _ref.read(userProfileProvider.future);
      final parts = <String>[];
      if (profile.name.isNotEmpty) parts.add('Name: ${profile.name}');
      if (profile.bloodGroup.isNotEmpty) {
        parts.add('Blood group: ${profile.bloodGroup}');
      }
      if (profile.city.isNotEmpty) parts.add('City: ${profile.city}');
      parts.add('Role: ${profile.activeRole}');
      if (profile.donorClassification.isNotEmpty) {
        parts.add('Donor classification: ${profile.donorClassification}');
      }
      parts.add('Verified: ${profile.isVerified ? "Yes" : "No"}');
      if (profile.isTopDonor) parts.add('Top donor: Yes');
      if (profile.lastDonationDate != null) {
        final days =
            DateTime.now().difference(profile.lastDonationDate!).inDays;
        parts.add(
            'Last donation: ${profile.lastDonationDate!.toIso8601String()} '
            '($days days ago)');
        parts.add(
            'Cooldown eligible: ${days >= 90 ? "Yes" : "No (remaining: ${90 - days} days)"}');
      } else {
        parts.add('Last donation: never');
      }
      return parts.join('\n');
    } catch (_) {
      return null;
    }
  }

  /// Sends a user message and awaits the bot's response.
  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.isAwaitingResponse) return;

    final userMessage = BotMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isAwaitingResponse: true,
      clearError: true,
    );

    try {
      // Await profile context so the bot always receives user data,
      // even on the very first message (when the profile Future may
      // still be resolving).
      final userContext = await _buildUserContext();

      final reply = await _service.sendMessage(
        text.trim(),
        conversationHistory: state.history
          ..removeLast(), // exclude the message we just added
        userContext: userContext,
      );

      final botMessage = BotMessage(
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, botMessage],
        isAwaitingResponse: false,
      );
    } catch (e) {
      String errorMessage;
      if (e is ChatbotApiKeyException) {
        errorMessage =
            'AI chatbot is not configured yet. Please add QWEN_API_KEY to your .env file.';
      } else {
        errorMessage = 'Something went wrong. Please try again.';
      }
      state = state.copyWith(
        isAwaitingResponse: false,
        error: errorMessage,
      );
    }
  }

  /// Clears the entire conversation.
  void clear() {
    state = const ChatbotState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final chatbotProvider =
    StateNotifierProvider<ChatbotNotifier, ChatbotState>((ref) {
  final service = ref.watch(chatbotServiceProvider);
  return ChatbotNotifier(service, ref);
});

// ── Quick-reply suggestions ───────────────────────────────────────────────────

/// Pre-built quick-reply chips shown on first open.
const chatbotQuickReplies = <String>[
  'Am I eligible to donate?',
  'How does verification work?',
  'Find blood near me',
];
