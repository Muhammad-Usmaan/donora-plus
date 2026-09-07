import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/chatbot/chatbot_service.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../home/providers/home_providers.dart';

// ── Models ────────────────────────────────────────────────────────────────────

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

/// Metadata for an AI chatbot conversation thread.
class AiConversationThread {
  const AiConversationThread({
    required this.id,
    this.title,
    this.lastMessageAt,
  });

  final String id;
  final String? title;
  final DateTime? lastMessageAt;

  /// Display title — falls back to "New chat" when untitled.
  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : 'New chat';
}

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable state for the chatbot conversation.
class ChatbotState {
  const ChatbotState({
    this.messages = const [],
    this.isAwaitingResponse = false,
    this.isLoading = false,
    this.error,
    this.threads = const [],
    this.currentConversationId,
    this.title = '',
  });

  final List<BotMessage> messages;
  final bool isAwaitingResponse;
  final bool isLoading;
  final String? error;

  /// All AI conversation threads for the current user.
  final List<AiConversationThread> threads;

  /// The active conversation row ID (null before first load).
  final String? currentConversationId;

  /// Display title for the current conversation.
  final String title;

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
    List<AiConversationThread>? threads,
    String? currentConversationId,
    String? title,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isAwaitingResponse: isAwaitingResponse ?? this.isAwaitingResponse,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      threads: threads ?? this.threads,
      currentConversationId:
          currentConversationId ?? this.currentConversationId,
      title: title ?? this.title,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier(this._service, this._ref)
      : super(const ChatbotState(isLoading: true)) {
    _init();
  }

  final ChatbotService _service;
  final Ref _ref;
  String? _conversationId;

  // ── Initialisation ────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadThreads();
    if (!mounted) return;
    if (state.threads.isNotEmpty) {
      _conversationId = state.threads.first.id;
      await _loadMessagesForConversation(_conversationId!,
          setAsCurrent: true);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Fetches all AI conversation threads for the current user,
  /// sorted by [last_message_at] descending.
  Future<void> _loadThreads() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final client = _ref.read(supabaseClientProvider);
      final rows = await client
          .from('conversations')
          .select('id, title, last_message_at')
          .eq('participant_1_id', user.id)
          .isFilter('participant_2_id', null)
          .order('last_message_at', ascending: false);

      final threads = (rows as List).map((row) {
        return AiConversationThread(
          id: row['id'] as String,
          title: row['title'] as String?,
          lastMessageAt: row['last_message_at'] != null
              ? DateTime.tryParse(row['last_message_at'] as String)
              : null,
        );
      }).toList();

      state = state.copyWith(threads: threads);
    } catch (_) {}
  }

  /// Loads messages for a specific conversation and optionally updates
  /// the current-conversation pointer in state.
  Future<void> _loadMessagesForConversation(
    String conversationId, {
    bool setAsCurrent = false,
  }) async {
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final client = _ref.read(supabaseClientProvider);

      if (setAsCurrent) {
        _conversationId = conversationId;
      }

      final msgRows = await client
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final loaded = (msgRows as List).map((row) {
        final sId = row['sender_id'] as String?;
        final isUser = sId == user.id;
        final content = row['content'] as String? ?? '';
        final time =
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now();
        return BotMessage(
          role: isUser ? 'user' : 'assistant',
          content: content,
          timestamp: time,
        );
      }).toList();

      // Resolve the thread title.
      final thread = state.threads
          .cast<AiConversationThread?>()
          .firstWhere(
            (t) => t!.id == conversationId,
            orElse: () => null,
          );
      final title = thread?.title ?? '';

      state = state.copyWith(
        messages: loaded,
        isLoading: false,
        currentConversationId: conversationId,
        title: title,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Switches to an existing conversation thread and loads its messages.
  Future<void> switchConversation(String conversationId) async {
    if (conversationId == _conversationId) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadMessagesForConversation(conversationId,
        setAsCurrent: true);
  }

  /// Creates a brand-new conversation row and prepares the UI for a
  /// fresh chat.  The row is persisted immediately so it appears in the
  /// recent-chats list even before the first message is sent.
  Future<void> newChat() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final client = _ref.read(supabaseClientProvider);
      final newConv = await client
          .from('conversations')
          .insert({
            'participant_1_id': user.id,
            'participant_2_id': null,
          })
          .select('id')
          .single();
      final newId = newConv['id'] as String;

      _conversationId = newId;

      final newThread = AiConversationThread(
        id: newId,
        lastMessageAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: const [],
        currentConversationId: newId,
        threads: [newThread, ...state.threads],
        title: '',
        clearError: true,
      );
    } catch (_) {}
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
        // UTC-only math to stay consistent with the Supabase admin panel.
        final nowUtc = DateTime.now().toUtc();
        final lastUtc = profile.lastDonationDate!.toUtc();
        final days = DateTime.utc(
              nowUtc.year, nowUtc.month, nowUtc.day,
            ).difference(
              DateTime.utc(lastUtc.year, lastUtc.month, lastUtc.day),
            ).inDays;
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
      final newConv = await client
          .from('conversations')
          .insert({
            'participant_1_id': userId,
            'participant_2_id': null,
          })
          .select('id')
          .single();
      final newId = newConv['id'] as String;
      _conversationId = newId;

      // Add the new thread to the local list.
      final newThread = AiConversationThread(
        id: newId,
        lastMessageAt: DateTime.now(),
      );
      state = state.copyWith(
        currentConversationId: newId,
        threads: [newThread, ...state.threads],
      );
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
      if (!mounted) return;
      if (_conversationId != null) {
        try {
          final isFirstMessage = state.messages.length == 1;
          await client.from('messages').insert({
            'conversation_id': _conversationId,
            'sender_id': user.id,
            'content': text.trim(),
          });
          final updates = <String, dynamic>{
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'last_message_at': DateTime.now().toUtc().toIso8601String(),
          };
          // Auto-generate a title from the first user message.
          if (isFirstMessage && state.title.isEmpty) {
            final titleText = text.trim().length > 40
                ? '${text.trim().substring(0, 40)}...'
                : text.trim();
            updates['title'] = titleText;
            state = state.copyWith(title: titleText);
            _updateThreadInList(_conversationId!,
                title: titleText,
                lastMessageAt: DateTime.now());
          } else {
            _updateThreadInList(_conversationId!,
                lastMessageAt: DateTime.now());
          }
          await client
              .from('conversations')
              .update(updates)
              .eq('id', _conversationId!);
        } catch (_) {}
      }
    }

    try {
      final userContext = await _buildUserContext();
      if (!mounted) return;

      final reply = await _service.sendMessage(
        text.trim(),
        conversationHistory: state.history
          ..removeLast(), // exclude the message we just added
        userContext: userContext,
      );

      if (!mounted) return;
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
            'last_message_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', _conversationId!);
          _updateThreadInList(_conversationId!,
              lastMessageAt: DateTime.now());
        } catch (_) {}
      }
    } catch (e) {
      const errorMessage = 'Something went wrong. Please try again.';
      state = state.copyWith(
        isAwaitingResponse: false,
        error: errorMessage,
      );
    }
  }

  /// Moves the given thread to the top of the list with updated metadata.
  void _updateThreadInList(
    String conversationId, {
    String? title,
    DateTime? lastMessageAt,
  }) {
    final updated = state.threads.map((t) {
      if (t.id != conversationId) return t;
      return AiConversationThread(
        id: t.id,
        title: title ?? t.title,
        lastMessageAt: lastMessageAt ?? t.lastMessageAt,
      );
    }).toList();
    // Bubble the active thread to the top.
    updated.sort((a, b) {
      if (a.id == conversationId) return -1;
      if (b.id == conversationId) return 1;
      final aTime = a.lastMessageAt ?? DateTime(1970);
      final bTime = b.lastMessageAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    state = state.copyWith(threads: updated);
  }

  /// Clears messages in the current conversation (local + Supabase).
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

  // Invalidate the chatbot provider whenever the signed-in user changes
  // (logout or account switch).  Without this the previous user's
  // conversation threads, messages, and _conversationId leak into the
  // next session because the StateNotifier is not auto-disposed.
  ref.listen(currentUserProvider, (previous, next) {
    if (previous != null && previous.id != next?.id) {
      ref.invalidateSelf();
    }
  });

  return ChatbotNotifier(service, ref);
});

// ── Quick-reply suggestions ───────────────────────────────────────────────────

/// Pre-built quick-reply chips shown on first open.
const chatbotQuickReplies = <String>[
  'Am I eligible to donate?',
  'How does verification work?',
  'Find blood near me',
];
