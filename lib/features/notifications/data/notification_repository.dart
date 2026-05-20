import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

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
}
