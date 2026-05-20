import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertProfile({
    required String userId,
    required String email,
    String? username,
    String? bio,
    int? countyId,
    int? subcountyId,
    String? avatarUrl,
    String? civiqCode,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'email': email,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (countyId != null) 'county_id': countyId,
      if (subcountyId != null) 'subcounty_id': subcountyId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (civiqCode != null) 'civiq_code': civiqCode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> isUsernameTaken(String username) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return response != null;
  }

  List<String> usernameSuggestions(String base) {
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final seed = cleaned.isEmpty ? 'CiviqUser' : cleaned;
    return ['${seed}254', '${seed}_KE', '${seed}_CQ'];
  }

  String generateCiviqCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    String chunk(int length) => List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'CQ-${chunk(4)}-${chunk(2)}';
  }
}
