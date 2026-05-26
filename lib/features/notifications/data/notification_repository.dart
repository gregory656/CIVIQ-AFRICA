import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider<List<CiviqNotification>>((
  ref,
) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchNotifications(userId);
});

final archivedNotificationsProvider = FutureProvider<List<CiviqNotification>>((
  ref,
) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchArchived(userId);
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
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
    this.category = 'general',
    this.actionRoute,
    this.actionLabel,
    this.actorProfileId,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String category;
  final String? actionRoute;
  final String? actionLabel;
  final String? actorProfileId;

  factory CiviqNotification.fromJson(Map<String, dynamic> json) {
    return CiviqNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      category: json['category'] as String? ?? 'general',
      actionRoute: json['action_route'] as String?,
      actionLabel: json['action_label'] as String?,
      actorProfileId: json['actor_profile_id'] as String?,
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
        'title': 'Welcome to SIVIQ.',
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

  Future<void> createSecurityPinResetNotification(String userId) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': 'Security PIN reset',
      'body':
          'Your security PIN was reset successfully. If this was not you, secure your account immediately.',
      'category': 'security',
      'is_read': false,
    });
  }

  Future<List<CiviqNotification>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select(
          'id,title,body,is_read,category,action_route,action_label,actor_profile_id,created_at',
        )
        .eq('user_id', userId)
        .filter('archived_at', 'is', null)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    return response
        .map((json) => CiviqNotification.fromJson(json))
        .toList(growable: false);
  }

  Future<List<CiviqNotification>> fetchArchived(String userId) async {
    final response = await _client
        .from('notifications')
        .select(
          'id,title,body,is_read,category,action_route,action_label,actor_profile_id,created_at',
        )
        .eq('user_id', userId)
        .filter('archived_at', 'not.is', null)
        .filter('deleted_at', 'is', null)
        .order('archived_at', ascending: false);

    return response
        .map((json) => CiviqNotification.fromJson(json))
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false)
        .filter('archived_at', 'is', null)
        .filter('deleted_at', 'is', null);
    return response.length;
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false)
        .filter('archived_at', 'is', null)
        .filter('deleted_at', 'is', null);
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> archive(String notificationId) async {
    await _client
        .from('notifications')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId);
  }

  Future<void> unarchive(String notificationId) async {
    await _client
        .from('notifications')
        .update({'archived_at': null})
        .eq('id', notificationId);
  }

  Future<void> delete(String notificationId) async {
    await _client
        .from('notifications')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'is_read': true,
        })
        .eq('id', notificationId);
  }

  Future<void> reportSpam(String notificationId) async {
    await _client
        .from('notifications')
        .update({
          'spam_reported_at': DateTime.now().toUtc().toIso8601String(),
          'archived_at': DateTime.now().toUtc().toIso8601String(),
          'is_read': true,
        })
        .eq('id', notificationId);
  }
}
