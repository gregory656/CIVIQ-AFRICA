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

final publicProfileProvider = FutureProvider.family<CiviqProfile?, String>((
  ref,
  userId,
) async {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

final isFollowingProvider = FutureProvider.family<bool, String>((
  ref,
  targetUserId,
) async {
  final currentUserId = ref.watch(currentAuthUserIdProvider);
  if (currentUserId == null || currentUserId == targetUserId) return false;
  return ref
      .watch(profileRepositoryProvider)
      .isFollowing(currentUserId, targetUserId);
});

class CiviqProfile {
  const CiviqProfile({
    required this.id,
    required this.email,
    this.displayName,
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
    this.isVerified = false,
    this.verificationType,
    this.roleLabel,
    this.role = 'user',
    this.accountStatus = 'active',
    this.suspensionUntil,
    this.mutedUntil,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  final String id;
  final String email;
  final String? displayName;
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
  final bool isVerified;
  final String? verificationType;
  final String? roleLabel;
  final String role;
  final String accountStatus;
  final DateTime? suspensionUntil;
  final DateTime? mutedUntil;
  final int followersCount;
  final int followingCount;

  String get primaryName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'SIVIQ Member';
  }

  String get handle {
    final value = username?.trim();
    return value == null || value.isEmpty ? 'No username' : '@$value';
  }

  bool get canModerate =>
      role == 'moderator' || role == 'admin' || role == 'super_admin';

  bool get isRestricted {
    if (accountStatus == 'banned' || accountStatus == 'under_review') {
      return true;
    }
    if (accountStatus != 'suspended') return false;
    final until = suspensionUntil;
    return until == null || until.isAfter(DateTime.now().toUtc());
  }

  factory CiviqProfile.fromJson(Map<String, dynamic> json) {
    return CiviqProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
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
      isVerified: json['is_verified'] as bool? ?? false,
      verificationType: json['verification_type'] as String?,
      roleLabel: json['role_label'] as String?,
      role: json['role'] as String? ?? 'user',
      accountStatus: json['account_status'] as String? ?? 'active',
      suspensionUntil: DateTime.tryParse(
        json['suspension_until'] as String? ?? '',
      ),
      mutedUntil: DateTime.tryParse(json['muted_until'] as String? ?? ''),
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }
}

class ProfileConnection {
  const ProfileConnection({
    required this.id,
    required this.displayName,
    required this.username,
    required this.civiqCode,
    required this.avatarUrl,
    required this.isVerified,
    required this.roleLabel,
    this.role = 'user',
    this.isFollowed = false,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? civiqCode;
  final String? avatarUrl;
  final bool isVerified;
  final String? roleLabel;
  final String role;
  final bool isFollowed;

  String get primaryName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'SIVIQ Member';
  }

  String get handle {
    final value = username?.trim();
    return value == null || value.isEmpty ? 'No username' : '@$value';
  }

  factory ProfileConnection.fromJson(Map<String, dynamic> json) {
    return ProfileConnection(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      civiqCode: json['civiq_code'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      roleLabel: json['role_label'] as String?,
      role: json['role'] as String? ?? 'user',
      isFollowed: json['is_followed'] as bool? ?? false,
    );
  }

  ProfileConnection copyWith({bool? isFollowed}) {
    return ProfileConnection(
      id: id,
      displayName: displayName,
      username: username,
      civiqCode: civiqCode,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
      roleLabel: roleLabel,
      role: role,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<CiviqProfile?> getProfile(String userId) async {
    final response = await _client
        .rpc('get_profile_summary', params: {'target_user_id': userId})
        .maybeSingle();
    if (response == null) return null;
    return CiviqProfile.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ProfileSocialCounts> socialCounts(String userId) async {
    final followers = await _client
        .from('follows')
        .count(CountOption.exact)
        .eq('following_id', userId);
    final following = await _client
        .from('follows')
        .count(CountOption.exact)
        .eq('follower_id', userId);
    return ProfileSocialCounts(followers: followers, following: following);
  }

  Future<List<ProfileConnection>> followers(String userId) async {
    final response = await _client
        .from('follows')
        .select(
          'follower:profiles!follows_follower_id_fkey(id,display_name,username,civiq_code,avatar_url,is_verified,role_label,role)',
        )
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return response
        .map<ProfileConnection>(
          (row) => ProfileConnection.fromJson(
            Map<String, dynamic>.from(row['follower'] as Map),
          ),
        )
        .toList();
  }

  Future<List<ProfileConnection>> following(String userId) async {
    final response = await _client
        .from('follows')
        .select(
          'following:profiles!follows_following_id_fkey(id,display_name,username,civiq_code,avatar_url,is_verified,role_label,role)',
        )
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return response
        .map<ProfileConnection>(
          (row) => ProfileConnection.fromJson(
            Map<String, dynamic>.from(row['following'] as Map),
          ),
        )
        .toList();
  }

  Future<List<ProfileConnection>> discoverSiviqUsers(
    String currentUserId,
  ) async {
    final response = await _client.rpc('discover_civiq_profiles');
    return (response as List)
        .map(
          (json) => ProfileConnection.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList(growable: false);
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final response = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return response != null;
  }

  Future<void> followProfile(String targetUserId) async {
    await _client.rpc(
      'follow_profile',
      params: {'target_user_id': targetUserId},
    );
  }

  Future<void> unfollowProfile(
    String currentUserId,
    String targetUserId,
  ) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
  }

  Future<void> upsertProfile({
    required String userId,
    required String email,
    String? displayName,
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
    if (displayName != null) payload['display_name'] = displayName;
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

  bool isReservedUsername(String username) {
    return _reservedUsernames.contains(username.trim().toLowerCase());
  }

  String? usernameValidationMessage(String username) {
    final normalized = username.trim();
    if (normalized.length < 3) return 'Use at least 3 characters.';
    if (normalized.length > 30) return 'Use 30 characters or fewer.';
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(normalized)) {
      return 'Use letters, numbers, and underscores only.';
    }
    if (isReservedUsername(normalized)) {
      return 'This username is reserved by SIVIQ.';
    }
    return null;
  }

  String? displayNameValidationMessage(String displayName) {
    final normalized = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) return 'Use at least 2 characters.';
    if (normalized.length > 80) return 'Use 80 characters or fewer.';
    if (RegExp(r'[\r\n\t]').hasMatch(normalized)) {
      return 'Use a single-line name.';
    }
    return null;
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
    final seed = cleaned.isEmpty ? 'SiviqUser' : cleaned;
    return ['${seed}254', '${seed}_KE', '${seed}_SQ'];
  }

  String generateCiviqCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    String chunk(int length) => List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'SQ-${chunk(4)}-${chunk(2)}';
  }
}

class ProfileSocialCounts {
  const ProfileSocialCounts({required this.followers, required this.following});

  final int followers;
  final int following;
}

const _reservedUsernames = {
  'admin',
  'administrator',
  'civiq',
  'siviq',
  'support',
  'help',
  'moderator',
  'official',
  'verified',
  'president',
  'deputypresident',
  'governor',
  'senator',
  'mp',
  'mca',
  'county',
  'government',
  'iebc',
  'police',
};
