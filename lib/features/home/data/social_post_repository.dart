import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../projects/data/project_repository.dart';

final socialPostRepositoryProvider = Provider<SocialPostRepository>((ref) {
  return SocialPostRepository(ref.watch(supabaseClientProvider));
});

final socialHomeFeedProvider = FutureProvider<List<SocialPost>>((ref) {
  final providerUserId = ref.watch(currentAuthUserIdProvider);
  final authUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (providerUserId == null && authUserId == null) return const [];
  return ref.watch(socialPostRepositoryProvider).fetchFeed();
});

final globalSearchProvider = FutureProvider.family<GlobalSearchResults, String>(
  (ref, query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return GlobalSearchResults.empty;
    return ref.watch(socialPostRepositoryProvider).globalSearch(normalized);
  },
);

class SocialPost {
  const SocialPost({
    required this.id,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.createdAt,
    required this.viewerHasLiked,
    this.authorId,
    this.imageUrl,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorIsVerified = false,
    this.authorRole = 'user',
  });

  final String id;
  final String? authorId;
  final String body;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final bool viewerHasLiked;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final bool authorIsVerified;
  final String authorRole;

  String get displayName {
    final username = authorUsername;
    return username == null || username.isEmpty ? 'SIVIQ Member' : '@$username';
  }

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    return SocialPost(
      id: json['id'] as String,
      authorId: json['author_id'] as String?,
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
      authorUsername: json['author_username'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsVerified: json['author_is_verified'] as bool? ?? false,
      authorRole: json['author_role'] as String? ?? 'user',
    );
  }
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.postId,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.viewerHasLiked,
    this.parentCommentId,
    this.authorId,
    this.editedAt,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorIsVerified = false,
    this.authorRole = 'user',
  });

  final String id;
  final String postId;
  final String? parentCommentId;
  final String? authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final bool authorIsVerified;
  final String authorRole;
  final int likeCount;
  final int replyCount;
  final bool viewerHasLiked;

  String get displayName {
    final username = authorUsername;
    return username == null || username.isEmpty ? 'SIVIQ Member' : '@$username';
  }

  factory SocialComment.fromJson(Map<String, dynamic> json) {
    return SocialComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      authorId: json['author_id'] as String?,
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      editedAt: DateTime.tryParse(json['edited_at'] as String? ?? ''),
      authorUsername: json['author_username'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsVerified: json['author_is_verified'] as bool? ?? false,
      authorRole: json['author_role'] as String? ?? 'user',
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
    );
  }
}

class SocialPostRepository {
  SocialPostRepository(this._client);

  final SupabaseClient _client;

  Future<List<SocialPost>> fetchFeed({int limit = 20, int offset = 0}) async {
    final archiveCutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 14))
        .toIso8601String();
    final rows = await _client
        .from('v_social_post_feed')
        .select()
        .gte('created_at', archiveCutoff)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .map<SocialPost>(
          (row) => SocialPost.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<GlobalSearchResults> globalSearch(String query) async {
    final pattern = '%${query.replaceAll('%', '').replaceAll('_', '')}%';
    final profileRows = await _client
        .from('profiles')
        .select('id,username,civiq_code,avatar_url,is_verified,role_label,role')
        .or(
          'username.ilike.$pattern,bio.ilike.$pattern,civiq_code.ilike.$pattern',
        )
        .limit(12);
    final postRows = await _client
        .from('v_social_post_feed')
        .select()
        .ilike('body', pattern)
        .order('created_at', ascending: false)
        .limit(20);
    final projectRows = await _client
        .from('v_project_feed')
        .select()
        .or(
          'title.ilike.$pattern,description.ilike.$pattern,location_name.ilike.$pattern',
        )
        .order('created_at', ascending: false)
        .limit(12);

    return GlobalSearchResults(
      profiles: profileRows
          .map<ProfileConnection>(
            (row) => ProfileConnection.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      posts: postRows
          .map<SocialPost>(
            (row) => SocialPost.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      projects: projectRows
          .map<CiviqProject>(
            (row) => CiviqProject.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
    );
  }

  Future<void> createPost({required String body, String? imageUrl}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to post.');
    await _client.from('social_posts').insert({
      'author_id': userId,
      'body': body,
      'image_url': imageUrl,
    });
  }

  Future<void> updatePost(String postId, String body) async {
    await _client
        .from('social_posts')
        .update({
          'body': body,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    await _client
        .from('social_posts')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  Future<void> moderatePost({
    required String postId,
    required String status,
    required String reason,
  }) async {
    await _client.rpc(
      'moderate_social_post',
      params: {
        'target_post_id': postId,
        'new_status': status,
        'reason': reason,
      },
    );
  }

  Future<void> moderateComment({
    required String commentId,
    required String status,
    required String reason,
  }) async {
    await _client.rpc(
      'moderate_social_comment',
      params: {
        'target_comment_id': commentId,
        'new_status': status,
        'reason': reason,
      },
    );
  }

  Future<void> moderateUserAccount({
    required String userId,
    required String status,
    required String reason,
    DateTime? suspensionUntil,
    DateTime? mutedUntil,
  }) async {
    await _client.rpc(
      'moderate_user_account',
      params: {
        'target_user_id': userId,
        'new_status': status,
        'reason': reason,
        'until_at': suspensionUntil?.toUtc().toIso8601String(),
        'mute_until_at': mutedUntil?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> reportPost(String postId, String reason) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to report.');
    await _client.from('social_post_reports').upsert({
      'post_id': postId,
      'reporter_id': userId,
      'reason': reason,
    }, onConflict: 'post_id,reporter_id');
  }

  Future<void> hidePost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to hide this post.');
    await _client.from('social_post_hidden_users').upsert({
      'post_id': postId,
      'user_id': userId,
      'hidden_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> blockPost(String postId) => hidePost(postId);

  Future<void> toggleLike(String postId) async {
    await _client.rpc(
      'toggle_social_post_like',
      params: {'target_post_id': postId},
    );
  }

  Future<List<SocialComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('v_social_post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    return rows
        .map<SocialComment>(
          (row) => SocialComment.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> addComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to comment.');
    await _client.from('social_post_comments').insert({
      'post_id': postId,
      'author_id': userId,
      'body': body,
      'parent_comment_id': parentCommentId,
    });
  }

  Future<void> updateComment(String commentId, String body) async {
    await _client
        .from('social_post_comments')
        .update({
          'body': body,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('social_post_comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', commentId);
  }

  Future<void> toggleCommentLike(String commentId) async {
    await _client.rpc(
      'toggle_social_comment_like',
      params: {'target_comment_id': commentId},
    );
  }

  Future<void> reportComment(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to report.');
    await _client.from('social_post_comment_reports').insert({
      'comment_id': commentId,
      'reporter_id': userId,
      'reason': 'reported',
    });
  }

  Future<void> recordShare(String postId) async {
    await _client.rpc(
      'increment_social_post_share',
      params: {'target_post_id': postId},
    );
  }
}

class GlobalSearchResults {
  const GlobalSearchResults({
    required this.profiles,
    required this.posts,
    required this.projects,
  });

  final List<ProfileConnection> profiles;
  final List<SocialPost> posts;
  final List<CiviqProject> projects;

  static const empty = GlobalSearchResults(
    profiles: [],
    posts: [],
    projects: [],
  );

  bool get isEmpty => profiles.isEmpty && posts.isEmpty && projects.isEmpty;
}
