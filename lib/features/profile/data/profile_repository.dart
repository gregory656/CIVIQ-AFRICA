import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final currentProfileProvider = FutureProvider<CiviqProfile?>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

class CiviqProfile {
  const CiviqProfile({
    required this.id,
    required this.email,
    this.username,
    this.civiqCode,
    this.bio,
    this.avatarUrl,
    this.countyId,
    this.subcountyId,
    this.isPublic = false,
    this.showOnlineStatus = true,
    this.showReadReceipts = true,
    this.allowMessageRequests = true,
    this.showActivity = false,
  });

  final String id;
  final String email;
  final String? username;
  final String? civiqCode;
  final String? bio;
  final String? avatarUrl;
  final int? countyId;
  final int? subcountyId;
  final bool isPublic;
  final bool showOnlineStatus;
  final bool showReadReceipts;
  final bool allowMessageRequests;
  final bool showActivity;

  factory CiviqProfile.fromJson(Map<String, dynamic> json) {
    return CiviqProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      civiqCode: json['civiq_code'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      countyId: json['county_id'] as int?,
      subcountyId: json['subcounty_id'] as int?,
      isPublic: json['is_public'] as bool? ?? false,
      showOnlineStatus: json['show_online_status'] as bool? ?? true,
      showReadReceipts: json['show_read_receipts'] as bool? ?? true,
      allowMessageRequests: json['allow_message_requests'] as bool? ?? true,
      showActivity: json['show_activity'] as bool? ?? false,
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<CiviqProfile?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select(
          'id,email,username,civiq_code,bio,avatar_url,county_id,subcounty_id,is_public,show_online_status,show_read_receipts,allow_message_requests,show_activity',
        )
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return CiviqProfile.fromJson(response);
  }

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
    final payload = <String, dynamic>{
      'id': userId,
      'email': email,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (username != null) payload['username'] = username;
    if (bio != null) payload['bio'] = bio;
    if (countyId != null) payload['county_id'] = countyId;
    if (subcountyId != null) payload['subcounty_id'] = subcountyId;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (civiqCode != null) payload['civiq_code'] = civiqCode;

    await _client.from('profiles').upsert(payload);
  }

  Future<bool> isUsernameTaken(String username) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return response != null;
  }

  Future<void> updatePrivacySettings({
    required String userId,
    required bool isPublic,
    required bool showOnlineStatus,
    required bool showReadReceipts,
    required bool allowMessageRequests,
    required bool showActivity,
  }) async {
    await _client
        .from('profiles')
        .update({
          'is_public': isPublic,
          'show_online_status': showOnlineStatus,
          'show_read_receipts': showReadReceipts,
          'allow_message_requests': allowMessageRequests,
          'show_activity': showActivity,
          'is_online': showOnlineStatus,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
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
