import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/data/notification_settings_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/data/security_repository.dart';
import 'local_notification_service.dart';
import 'supabase_service.dart';

class NotificationRealtimeListener extends ConsumerStatefulWidget {
  const NotificationRealtimeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationRealtimeListener> createState() =>
      _NotificationRealtimeListenerState();
}

class _NotificationRealtimeListenerState
    extends ConsumerState<NotificationRealtimeListener> {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref
        .read(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((state) {
          final userId = state.session?.user.id;
          ref.read(currentAuthUserIdProvider.notifier).state = userId;
          ref.invalidate(notificationsProvider);
          ref.invalidate(archivedNotificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);
          ref.invalidate(notificationSettingsProvider);
          ref.invalidate(currentProfileProvider);
          ref.invalidate(securityEventsProvider);
          ref.invalidate(trustedDevicesProvider);
          ref.invalidate(exportHistoryProvider);
          ref.invalidate(accountDeletionProvider);
          ref.invalidate(legalHistoryProvider);
          _syncSubscription();
        });
    _syncSubscription();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _removeChannel();
    super.dispose();
  }

  void _syncSubscription() {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == _userId) return;
    _removeChannel();
    _userId = userId;
    if (userId == null) return;

    _channel = client
        .channel('public:notifications:user:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleInsertedNotification,
        )
        .subscribe();
  }

  Future<void> _handleInsertedNotification(
    PostgresChangePayload payload,
  ) async {
    final record = payload.newRecord;
    final title = record['title'] as String? ?? 'CIVIQ Africa';
    final body = record['body'] as String? ?? '';
    final notificationId = record['id']?.toString() ?? '';

    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);

    final userId = _userId;
    if (userId == null) return;

    final settings = await ref
        .read(notificationSettingsRepositoryProvider)
        .getOrCreate(userId);
    if (!settings.pushEnabled) return;

    await LocalNotificationService.instance.show(
      id: notificationId.hashCode.abs(),
      title: title,
      body: body,
      sound: settings.notificationSound,
    );
  }

  void _removeChannel() {
    final channel = _channel;
    if (channel == null) return;
    ref.read(supabaseClientProvider).removeChannel(channel);
    _channel = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
