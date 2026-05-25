import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../models/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

final conversationsProvider = FutureProvider<List<ChatConversation>>((
  ref,
) async {
  final providerUserId = ref.watch(currentAuthUserIdProvider);
  final authUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (providerUserId == null && authUserId == null) return const [];
  return ref.watch(chatRepositoryProvider).fetchConversations();
});

final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).fetchMessages(conversationId);
});

final chatSearchProvider =
    FutureProvider.family<List<ChatProfileResult>, String>((ref, query) async {
      final normalized = query.trim();
      if (normalized.length < 2) return const [];
      return ref.watch(chatRepositoryProvider).searchProfiles(normalized);
    });

final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).fetchGroupMembers(conversationId);
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  RealtimeChannel messagesChannel(
    String conversationId, {
    required VoidCallback onChange,
  }) {
    return _client
        .channel('chat_messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reads',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel conversationsChannel({required VoidCallback onChange}) {
    final userId = _client.auth.currentUser?.id;
    return _client
        .channel('chat_conversations:${userId ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: userId == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: userId,
                ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel typingChannel({
    required String conversationId,
    required String userId,
    required void Function(Set<String> typingUserIds) onTypingChanged,
  }) {
    final channel = _client.channel('typing:$conversationId');
    Timer? clearTimer;

    channel
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['user_id'] as String?;
            if (senderId == null || senderId == userId) return;
            onTypingChanged({senderId});
            clearTimer?.cancel();
            clearTimer = Timer(
              const Duration(seconds: 3),
              () => onTypingChanged(const {}),
            );
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> removeChannel(RealtimeChannel channel) {
    return _client.removeChannel(channel);
  }

  Future<void> sendTyping(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .channel('typing:$conversationId')
        .sendBroadcastMessage(event: 'typing', payload: {'user_id': userId});
  }

  Future<void> updatePresence({required bool isOnline}) async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc(
      'update_profile_presence',
      params: {'online_now': isOnline},
    );
  }

  Future<void> ensureCurrentProfile() async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc('ensure_current_profile');
  }

  Future<List<ChatConversation>> fetchConversations() async {
    final response = await _client.rpc('list_conversations');
    return (response as List)
        .map(
          (json) =>
              ChatConversation.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList(growable: false);
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final response = await _client.rpc(
      'list_conversation_messages',
      params: {'target_conversation_id': conversationId, 'result_limit': 60},
    );
    final messages = (response as List)
        .map(
          (json) =>
              ChatMessage.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList(growable: false);
    return messages.reversed.toList(growable: false);
  }

  Future<List<ChatProfileResult>> searchProfiles(String query) async {
    final response = await _client.rpc(
      'search_chat_profiles',
      params: {'query_text': query, 'result_limit': 20},
    );
    return (response as List)
        .map(
          (json) => ChatProfileResult.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<String> ensureSelfConversation() async {
    final response = await _client.rpc('ensure_self_conversation');
    return response as String;
  }

  Future<String> createDirectConversation(String targetUserId) async {
    final response = await _client.rpc(
      'create_direct_conversation',
      params: {'target_user_id': targetUserId},
    );
    return response as String;
  }

  Future<String> createGroupConversation({
    required String title,
    required List<String> memberIds,
    String? description,
    String? photoUrl,
  }) async {
    final response = await _client.rpc(
      'create_group_conversation',
      params: {
        'group_title': title,
        'member_ids': memberIds,
        'group_description': description,
        'group_photo_url': photoUrl,
      },
    );
    return response as String;
  }

  Future<List<GroupMember>> fetchGroupMembers(String conversationId) async {
    final response = await _client.rpc(
      'list_group_members',
      params: {'target_conversation_id': conversationId, 'result_limit': 100},
    );
    return (response as List)
        .map(
          (json) =>
              GroupMember.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList(growable: false);
  }

  Future<int> addGroupMembers({
    required String conversationId,
    required List<String> memberIds,
  }) async {
    final response = await _client.rpc(
      'add_group_members',
      params: {
        'target_conversation_id': conversationId,
        'member_ids': memberIds,
      },
    );
    return (response as num?)?.toInt() ?? 0;
  }

  Future<void> removeGroupMember({
    required String conversationId,
    required String userId,
  }) async {
    await _client.rpc(
      'remove_group_member',
      params: {
        'target_conversation_id': conversationId,
        'target_user_id': userId,
      },
    );
  }

  Future<void> leaveGroup(String conversationId) async {
    await _client.rpc(
      'leave_group',
      params: {'target_conversation_id': conversationId},
    );
  }

  Future<void> reportGroup(String conversationId) async {
    await _client.rpc(
      'report_group',
      params: {'target_conversation_id': conversationId},
    );
  }

  Future<void> deleteGroup(String conversationId) async {
    await _client.rpc(
      'delete_group',
      params: {'target_conversation_id': conversationId},
    );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    await _client.rpc(
      'send_message',
      params: {
        'target_conversation_id': conversationId,
        'body': content,
        'target_message_type': 'text',
      },
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'target_conversation_id': conversationId},
    );
  }

  Future<bool> toggleFavoriteMessage(String messageId) async {
    final response = await _client.rpc(
      'toggle_favorite_message',
      params: {'target_message_id': messageId},
    );
    return response as bool? ?? false;
  }

  Future<void> updateConversationState({
    required String conversationId,
    bool? isMuted,
    bool? isArchived,
    bool? isFavorite,
  }) async {
    final payload = <String, dynamic>{};
    if (isMuted != null) payload['is_muted'] = isMuted;
    if (isArchived != null) payload['is_archived'] = isArchived;
    if (isFavorite != null) payload['is_favorite'] = isFavorite;
    if (payload.isEmpty) return;
    await _client
        .from('conversation_participants')
        .update(payload)
        .eq('conversation_id', conversationId);
  }
}
