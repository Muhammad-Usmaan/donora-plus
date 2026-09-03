import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/providers.dart';
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
    final p1Id = map['participant_1_id'] as String?;
    final isUserP1 = p1Id == currentUserId;
    final otherId = isUserP1 ? (map['participant_2_id'] as String?) : p1Id;

    // Joined profile data for the other user.
    final p1Profile = map['p1'] as Map<String, dynamic>?;
    final p2Profile = map['p2'] as Map<String, dynamic>?;
    final profiles = (isUserP1 ? p2Profile : p1Profile) ??
        map['other_profile'] as Map<String, dynamic>? ??
        map['profiles'] as Map<String, dynamic>? ??
        {};

    // Last message (from a join or subquery).
    var lastMsg = map['last_message'] as String?;
    var lastMsgAt = map['last_message_at'] != null
        ? DateTime.tryParse(map['last_message_at'] as String)
        : null;
    var unreadCount = map['unread_count'] as int? ?? 0;

    final messagesList = (map['messages'] as List<dynamic>?)
        ?.map((m) => m as Map<String, dynamic>)
        .toList();

    if (messagesList != null && messagesList.isNotEmpty) {
      messagesList.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      lastMsg ??= messagesList.first['content'] as String?;
      lastMsgAt ??=
          DateTime.tryParse(messagesList.first['created_at'] as String? ?? '');

      unreadCount = messagesList
          .where((m) => m['sender_id'] != currentUserId && m['is_read'] == false)
          .length;
    }

    return ChatConversation(
      id: map['id'] as String? ?? '',
      otherUserId: otherId ?? '',
      otherUserName: profiles['name'] as String? ?? 'User',
      otherUserPhotoUrl: profiles['profile_photo_url'] as String?,
      otherUserIsVerified: profiles['is_verified'] as bool? ?? false,
      lastMessage: lastMsg,
      lastMessageAt: lastMsgAt,
      unreadCount: unreadCount,
    );
  }
}

/// Public profile info for the other participant in a conversation.
class OtherParticipantInfo {
  const OtherParticipantInfo({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isVerified = false,
    this.phone,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final bool isVerified;
  final String? phone;
}

/// Resolves the other participant's profile in a conversation given its ID.
final conversationOtherParticipantProvider =
    FutureProvider.family<OtherParticipantInfo?, String>(
        (ref, conversationId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || conversationId.isEmpty) return null;

  final client = ref.watch(supabaseClientProvider);
  try {
    // Step 1: Fetch conversation participant IDs.
    final row = await client
        .from('conversations')
        .select('participant_1_id, participant_2_id')
        .eq('id', conversationId)
        .maybeSingle();

    if (row == null) return null;

    final p1Id = row['participant_1_id'] as String?;
    final isUserP1 = p1Id == user.id;
    final otherId =
        (isUserP1 ? row['participant_2_id'] : p1Id) as String? ?? '';

    if (otherId.isEmpty) return null;

    // Step 2: Fetch the other participant's public profile.
    final profile = await client
        .from('profiles_public')
        .select('id, name, profile_photo_url, is_verified')
        .eq('id', otherId)
        .maybeSingle();

    return OtherParticipantInfo(
      id: otherId,
      name: profile?['name'] as String? ?? 'User',
      photoUrl: profile?['profile_photo_url'] as String?,
      isVerified: profile?['is_verified'] as bool? ?? false,
    );
  } catch (_) {
    return null;
  }
});

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
    // Step 1: Fetch conversations with messages (no profile join).
    final data = await client
        .from('conversations')
        .select('''
          *,
          messages(id, content, sender_id, is_read, created_at)
        ''')
        .or('participant_1_id.eq.${user.id},participant_2_id.eq.${user.id}')
        .not('participant_2_id', 'is', null)
        .order('updated_at', ascending: false);

    final conversations = (data as List).cast<Map<String, dynamic>>();
    if (conversations.isEmpty) return <ChatConversation>[];

    // Step 2: Collect all other-participant IDs and fetch from profiles_public.
    final otherIds = conversations.map((c) {
      final p1Id = c['participant_1_id'] as String?;
      return p1Id == user.id
          ? c['participant_2_id'] as String?
          : p1Id;
    }).whereType<String>().where((id) => id.isNotEmpty).toSet().toList();

    Map<String, Map<String, dynamic>> profileMap = {};
    if (otherIds.isNotEmpty) {
      final profiles = await client
          .from('profiles_public')
          .select('id, name, profile_photo_url, is_verified')
          .inFilter('id', otherIds);
      profileMap = {
        for (final p in (profiles as List).cast<Map<String, dynamic>>())
          p['id'] as String: p,
      };
    }

    // Step 3: Merge profiles into conversation rows.
    return conversations.map((row) {
      final p1Id = row['participant_1_id'] as String?;
      final isUserP1 = p1Id == user.id;
      final otherId =
          isUserP1 ? row['participant_2_id'] as String? : p1Id;
      final otherProfile =
          otherId != null ? profileMap[otherId] ?? {} : <String, dynamic>{};
      // Inject the resolved profile so fromMap can pick it up.
      row['other_profile'] = otherProfile;
      return ChatConversation.fromMap(
        row,
        currentUserId: user.id,
      );
    }).toList();
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

      // Notify the other participant via push.
      unawaited(_notifyOtherParticipant(conversationId, user.id, content.trim()));

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends a push notification to the other conversation participant.
  Future<void> _notifyOtherParticipant(
    String conversationId,
    String senderId,
    String messagePreview,
  ) async {
    try {
      final client = _ref.read(supabaseClientProvider);

      // Find the other participant.
      final convo = await client
          .from('conversations')
          .select('participant_1_id, participant_2_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (convo == null) return;

      final p1 = convo['participant_1_id'] as String?;
      final p2 = convo['participant_2_id'] as String?;
      final otherId = p1 == senderId ? p2 : p1;
      if (otherId == null) return;

      // Fetch sender name for the notification body.
      final senderProfile = await client
          .from('profiles')
          .select('name')
          .eq('id', senderId)
          .maybeSingle();
      final senderName = senderProfile?['name'] as String? ?? 'Someone';

      // Truncate the message for the notification body.
      final preview = messagePreview.length > 60
          ? '${messagePreview.substring(0, 60)}...'
          : messagePreview;

      final pushService = _ref.read(pushNotificationServiceProvider);
      await pushService.send(
        recipientId: otherId,
        type: 'new_message',
        title: senderName,
        body: preview,
        deepLinkId: conversationId,
      );
    } catch (_) {
      // Non-critical.
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
