import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/chatbot/chatbot_service.dart';
import '../../../services/chatbot/qwen_chatbot_service.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
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
    this.isLoading = false,
    this.error,
  });

  final List<BotMessage> messages;
  final bool isAwaitingResponse;
  final bool isLoading;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  /// Conversation history for the API (excludes the current message).
  List<Map<String, String>> get history =>
      messages.map((m) => m.toHistoryEntry()).toList();

  ChatbotState copyWith({
    List<BotMessage>? messages,
    bool? isAwaitingResponse,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isAwaitingResponse: isAwaitingResponse ?? this.isAwaitingResponse,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier(this._service, this._ref)
      : super(const ChatbotState(isLoading: true)) {
    _loadHistory();
  }

  final ChatbotService _service;
  final Ref _ref;
  String? _conversationId;

  Future<void> _loadHistory() async {
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final client = _ref.read(supabaseClientProvider);

      // Fetch or create user's AI conversation
      final convRow = await client
          .from('conversations')
          .select('id')
          .eq('participant_1_id', user.id)
          .isFilter('participant_2_id', null)
          .maybeSingle();

      if (convRow != null) {
        _conversationId = convRow['id'] as String?;
      } else {
        final newConv = await client
            .from('conversations')
            .insert({
              'participant_1_id': user.id,
              'participant_2_id': null,
            })
            .select('id')
            .single();
        _conversationId = newConv['id'] as String?;
      }

      if (_conversationId != null) {
        final msgRows = await client
            .from('messages')
            .select('*')
            .eq('conversation_id', _conversationId!)
            .order('created_at', ascending: true);

        final loaded = (msgRows as List).map((row) {
          final sId = row['sender_id'] as String?;
          final isUser = sId == user.id;
          final content = row['content'] as String? ?? '';
          final time = DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now();
          return BotMessage(
            role: isUser ? 'user' : 'assistant',
            content: content,
            timestamp: time,
          );
        }).toList();

        state = state.copyWith(
          messages: loaded,
          isLoading: false,
        );
        return;
      }
    } catch (_) {
      // Fallback gracefully on network / auth error
    }
    state = state.copyWith(isLoading: false);
  }

  /// Builds a plain-text summary of the current user's profile for the
  /// system prompt.
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

  Future<void> _ensureConversation(String userId) async {
    if (_conversationId != null) return;
    try {
      final client = _ref.read(supabaseClientProvider);
      final convRow = await client
          .from('conversations')
          .select('id')
          .eq('participant_1_id', userId)
          .isFilter('participant_2_id', null)
          .maybeSingle();

      if (convRow != null) {
        _conversationId = convRow['id'] as String?;
      } else {
        final newConv = await client
            .from('conversations')
            .insert({
              'participant_1_id': userId,
              'participant_2_id': null,
            })
            .select('id')
            .single();
        _conversationId = newConv['id'] as String?;
      }
    } catch (_) {}
  }

  /// Sends a user message, persists it, calls the AI service, and persists the response.
  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.isAwaitingResponse) return;

    final user = _ref.read(currentUserProvider);
    final client = _ref.read(supabaseClientProvider);

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

    if (user != null) {
      await _ensureConversation(user.id);
      if (_conversationId != null) {
        try {
          await client.from('messages').insert({
            'conversation_id': _conversationId,
            'sender_id': user.id,
            'content': text.trim(),
          });
          await client.from('conversations').update({
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', _conversationId!);
        } catch (_) {}
      }
    }

    try {
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

      if (_conversationId != null) {
        try {
          await client.from('messages').insert({
            'conversation_id': _conversationId,
            'sender_id': null,
            'content': reply,
          });
          await client.from('conversations').update({
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', _conversationId!);
        } catch (_) {}
      }
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

  /// Clears the entire conversation both locally and in Supabase.
  Future<void> clear() async {
    state = state.copyWith(messages: const []);
    if (_conversationId != null) {
      try {
        final client = _ref.read(supabaseClientProvider);
        await client
            .from('messages')
            .delete()
            .eq('conversation_id', _conversationId!);
      } catch (_) {}
    }
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
