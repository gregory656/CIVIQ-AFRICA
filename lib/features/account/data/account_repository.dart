import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(supabaseClientProvider));
});

class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  Future<void> requestAccountDeletion(String userId) async {
    final now = DateTime.now().toUtc();
    await _client.from('account_deletion_requests').upsert({
      'user_id': userId,
      'requested_at': now.toIso8601String(),
      'scheduled_purge_at': now.add(const Duration(days: 30)).toIso8601String(),
      'cancelled_at': null,
    }, onConflict: 'user_id');

    await _client
        .from('profiles')
        .update({
          'deleted_at': now.toIso8601String(),
          'is_online': false,
          'last_seen': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', userId);
  }
}
