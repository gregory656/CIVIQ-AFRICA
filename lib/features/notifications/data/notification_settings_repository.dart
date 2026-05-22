import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      return NotificationSettingsRepository(ref.watch(supabaseClientProvider));
    });

final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return const NotificationSettings();
  return ref.watch(notificationSettingsRepositoryProvider).getOrCreate(userId);
});

class NotificationSettings {
  const NotificationSettings({
    this.pushEnabled = true,
    this.notificationSound = 'default',
    this.messagesEnabled = true,
    this.projectUpdatesEnabled = true,
    this.moderationAlertsEnabled = true,
    this.rankingsEnabled = true,
    this.securityAlertsEnabled = true,
  });

  final bool pushEnabled;
  final String notificationSound;
  final bool messagesEnabled;
  final bool projectUpdatesEnabled;
  final bool moderationAlertsEnabled;
  final bool rankingsEnabled;
  final bool securityAlertsEnabled;

  NotificationSettings copyWith({
    bool? pushEnabled,
    String? notificationSound,
    bool? messagesEnabled,
    bool? projectUpdatesEnabled,
    bool? moderationAlertsEnabled,
    bool? rankingsEnabled,
    bool? securityAlertsEnabled,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      projectUpdatesEnabled:
          projectUpdatesEnabled ?? this.projectUpdatesEnabled,
      moderationAlertsEnabled:
          moderationAlertsEnabled ?? this.moderationAlertsEnabled,
      rankingsEnabled: rankingsEnabled ?? this.rankingsEnabled,
      securityAlertsEnabled:
          securityAlertsEnabled ?? this.securityAlertsEnabled,
    );
  }

  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'push_enabled': pushEnabled,
      'notification_sound': notificationSound,
      'messages_enabled': messagesEnabled,
      'project_updates_enabled': projectUpdatesEnabled,
      'moderation_alerts_enabled': moderationAlertsEnabled,
      'rankings_enabled': rankingsEnabled,
      'security_alerts_enabled': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      notificationSound: json['notification_sound'] as String? ?? 'default',
      messagesEnabled: json['messages_enabled'] as bool? ?? true,
      projectUpdatesEnabled: json['project_updates_enabled'] as bool? ?? true,
      moderationAlertsEnabled:
          json['moderation_alerts_enabled'] as bool? ?? true,
      rankingsEnabled: json['rankings_enabled'] as bool? ?? true,
      securityAlertsEnabled: true,
    );
  }
}

class NotificationSettingsRepository {
  NotificationSettingsRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationSettings> getOrCreate(String userId) async {
    final response = await _client
        .from('notification_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response != null) return NotificationSettings.fromJson(response);

    const settings = NotificationSettings();
    await save(userId, settings);
    return settings;
  }

  Future<void> save(String userId, NotificationSettings settings) async {
    await _client
        .from('notification_settings')
        .upsert(settings.toJson(userId), onConflict: 'user_id');
  }
}
