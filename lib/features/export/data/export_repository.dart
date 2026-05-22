import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(supabaseClientProvider));
});

class ExportRepository {
  ExportRepository(this._client);

  final SupabaseClient _client;

  Future<String> requestExport() async {
    final response = await _client.functions.invoke('export-user-data');
    final data = response.data;
    if (data is Map && data['download_url'] is String) {
      return data['download_url'] as String;
    }
    throw StateError('Export function did not return a download link.');
  }
}
