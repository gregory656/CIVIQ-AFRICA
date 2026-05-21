import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider<List<CiviqNotification>>((
  ref,
) async {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchNotifications(userId);
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return 0;
  return ref.watch(notificationRepositoryProvider).fetchUnreadCount(userId);
});

class CiviqNotification {
  const CiviqNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  factory CiviqNotification.fromJson(Map<String, dynamic> json) {
    return CiviqNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<void> createWelcomeNotifications(String userId) async {
    await _client.from('notifications').insert([
      {
        'user_id': userId,
        'title': 'Welcome to CIVIQ Africa.',
        'body':
            'Read our guidelines and help improve your community responsibly.',
        'is_read': false,
      },
      {
        'user_id': userId,
        'title': 'Create your first civic project report.',
        'body': 'Engage your local leadership and track development near you.',
        'is_read': false,
      },
    ]);
  }

  Future<List<CiviqNotification>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id,title,body,is_read,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response
        .map((json) => CiviqNotification.fromJson(json))
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return response.length;
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }
}
