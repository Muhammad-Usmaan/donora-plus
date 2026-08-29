import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

/// A conversation between two users, enriched with the other participant's
/// profile and the most recent message.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    required this.otherUserIsVerified,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final bool otherUserIsVerified;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  factory ChatConversation.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    // Determine which participant is the "other" user.
    final p1 = map['participant_1_id'] as String?;
    final p2 = map['participant_2_id'] as String?;
    final otherId = p1 == currentUserId ? p2 : p1;

    // Joined profile data for the other user.
    final profiles = map['profiles'] as Map<String, dynamic>? ??
        map['other_profile'] as Map<String, dynamic>? ??
        {};

    // Last message (from a join or subquery).
    final lastMsg = map['last_message'] as String?;
    final lastMsgAt = map['last_message_at'] != null
        ? DateTime.tryParse(map['last_message_at'] as String)
        : null;

    return ChatConversation(
      id: map['id'] as String? ?? '',
      otherUserId: otherId ?? '',
      otherUserName: profiles['name'] as String? ?? 'Unknown',
      otherUserPhotoUrl: profiles['profile_photo_url'] as String?,
      otherUserIsVerified: profiles['is_verified'] as bool? ?? false,
      lastMessage: lastMsg,
      lastMessageAt: lastMsgAt,
      unreadCount: map['unread_count'] as int? ?? 0,
    );
  }
}

/// A single chat message.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String? ?? '',
        conversationId: map['conversation_id'] as String? ?? '',
        senderId: map['sender_id'] as String? ?? '',
        content: map['content'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
                DateTime.now(),
        isRead: map['is_read'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches the current user's conversations with enriched participant info
/// and last message preview.
final conversationsListProvider =
    FutureProvider<List<ChatConversation>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  try {
    final data = await client
        .from('conversations')
        .select('''
          *,
          other_profile:profiles!participant_2_id(id, name, profile_photo_url, is_verified)
        ''')
        .or('participant_1_id.eq.${user.id},participant_2_id.eq.${user.id}')
        .order('updated_at', ascending: false);

    return (data as List)
        .map((row) => ChatConversation.fromMap(
              row as Map<String, dynamic>,
              currentUserId: user.id,
            ))
        .toList();
  } on PostgrestException catch (e) {
    // Table doesn't exist yet — graceful fallback.
    if (e.code == '42P01' || e.message.contains('does not exist')) {
      return <ChatConversation>[];
    }
    rethrow;
  }
});

/// Realtime stream of messages for a specific conversation.
///
/// Uses Supabase Realtime's `.stream()` to push new messages instantly
/// to both participants without polling.
final conversationMessagesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, conversationId) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .limit(200);
});

/// Parsed chat messages derived from the realtime stream.
final conversationMessagesProvider =
    Provider.family<List<ChatMessage>, String>((ref, conversationId) {
  final raw = ref.watch(conversationMessagesStreamProvider(conversationId));
  return raw.whenOrNull(
        data: (rows) =>
            rows.map((r) => ChatMessage.fromMap(r)).toList(),
      ) ??
      [];
});

/// Sends a new message in a conversation.
///
/// Also updates the conversation's `updated_at` timestamp so it
/// floats to the top of the list.
final sendMessageProvider = Provider<SendMessageAction>((ref) {
  return SendMessageAction(ref);
});

class SendMessageAction {
  SendMessageAction(this._ref);
  final Ref _ref;

  Future<bool> call({
    required String conversationId,
    required String content,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || content.trim().isEmpty) return false;

    try {
      final client = _ref.read(supabaseClientProvider);

      // Insert the message.
      await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'content': content.trim(),
      });

      // Update conversation's updated_at so it sorts to the top.
      await client.from('conversations').update({
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversationId);

      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Creates or retrieves an existing conversation with another user.
///
/// If a conversation already exists between the current user and the
/// target user, returns its ID. Otherwise creates a new one.
final getOrCreateConversationProvider =
    Provider<GetOrCreateConversationAction>((ref) {
  return GetOrCreateConversationAction(ref);
});

class GetOrCreateConversationAction {
  GetOrCreateConversationAction(this._ref);
  final Ref _ref;

  Future<String?> call(String otherUserId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    try {
      final client = _ref.read(supabaseClientProvider);

      // Check for existing conversation.
      final existing = await client
          .from('conversations')
          .select('id')
          .or(
            'and(participant_1_id.eq.${user.id},participant_2_id.eq.$otherUserId),'
            'and(participant_1_id.eq.$otherUserId,participant_2_id.eq.${user.id})',
          )
          .maybeSingle();

      if (existing != null) return existing['id'] as String?;

      // Create new conversation.
      final created = await client
          .from('conversations')
          .insert({
            'participant_1_id': user.id,
            'participant_2_id': otherUserId,
          })
          .select('id')
          .single();

      return created['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Marks all messages in a conversation as read for the current user.
final markMessagesReadProvider = Provider<MarkMessagesReadAction>((ref) {
  return MarkMessagesReadAction(ref);
});

class MarkMessagesReadAction {
  MarkMessagesReadAction(this._ref);
  final Ref _ref;

  Future<void> call(String conversationId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('sender_id', 'neq.${user.id}')
          .eq('is_read', false);
    } catch (_) {
      // Silently fail — marking read is non-critical.
    }
  }
}
