import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../profile/data/profile_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(supabaseClientProvider));
});

final localProjectFeedProvider = FutureProvider<List<CiviqProject>>((ref) {
  final profile = ref.watch(currentProfileProvider).asData?.value;
  return ref
      .watch(projectRepositoryProvider)
      .fetchFeed(
        countyId: profile?.countyId,
        subcountyId: profile?.subcountyId,
      );
});

final projectsProvider = FutureProvider<List<CiviqProject>>((ref) {
  final profile = ref.watch(currentProfileProvider).asData?.value;
  return ref
      .watch(projectRepositoryProvider)
      .fetchFeed(
        countyId: profile?.countyId,
        subcountyId: profile?.subcountyId,
      );
});

class CiviqProject {
  const CiviqProject({
    required this.id,
    required this.title,
    required this.projectType,
    required this.verificationStatus,
    required this.approvalCount,
    required this.disapprovalCount,
    required this.commentCount,
    required this.createdAt,
    this.creatorId,
    this.description,
    this.countyId,
    this.countyName,
    this.subcountyId,
    this.subcountyName,
    this.locationName,
    this.imageUrl,
    this.creatorUsername,
    this.creatorAvatarUrl,
    this.creatorIsVerified = false,
  });

  final String id;
  final String? creatorId;
  final String title;
  final String? description;
  final String projectType;
  final int? countyId;
  final String? countyName;
  final int? subcountyId;
  final String? subcountyName;
  final String? locationName;
  final String? imageUrl;
  final String verificationStatus;
  final int approvalCount;
  final int disapprovalCount;
  final int commentCount;
  final DateTime createdAt;
  final String? creatorUsername;
  final String? creatorAvatarUrl;
  final bool creatorIsVerified;

  factory CiviqProject.fromJson(Map<String, dynamic> json) {
    return CiviqProject(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      projectType: json['project_type'] as String? ?? 'ongoing',
      countyId: json['county_id'] as int?,
      countyName: json['county_name'] as String?,
      subcountyId: json['subcounty_id'] as int?,
      subcountyName: json['subcounty_name'] as String?,
      locationName: json['location_name'] as String?,
      imageUrl: json['image_url'] as String?,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      approvalCount: json['approval_count'] as int? ?? 0,
      disapprovalCount: json['disapproval_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      creatorUsername: json['creator_username'] as String?,
      creatorAvatarUrl: json['creator_avatar_url'] as String?,
      creatorIsVerified: json['creator_is_verified'] as bool? ?? false,
    );
  }
}

class ProjectComment {
  const ProjectComment({
    required this.id,
    required this.projectId,
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
  });

  final String id;
  final String projectId;
  final String? parentCommentId;
  final String? authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final bool authorIsVerified;
  final int likeCount;
  final int replyCount;
  final bool viewerHasLiked;

  String get displayName {
    final username = authorUsername;
    return username == null || username.isEmpty ? 'SIVIQ Member' : '@$username';
  }

  factory ProjectComment.fromJson(Map<String, dynamic> json) {
    return ProjectComment(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
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
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
    );
  }
}

class CreateProjectInput {
  const CreateProjectInput({
    required this.title,
    required this.projectType,
    required this.confirmedAccuracy,
    this.description,
    this.countyId,
    this.subcountyId,
    this.locationName,
    this.imageUrl,
  });

  final String title;
  final String? description;
  final String projectType;
  final int? countyId;
  final int? subcountyId;
  final String? locationName;
  final String? imageUrl;
  final bool confirmedAccuracy;
}

class ProjectRepository {
  ProjectRepository(this._client);

  final SupabaseClient _client;

  Future<List<CiviqProject>> fetchFeed({
    int? countyId,
    int? subcountyId,
    int limit = 30,
  }) async {
    var query = _client
        .from('v_project_feed')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    final rows = await query;
    final projects = rows
        .map<CiviqProject>(
          (row) => CiviqProject.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();

    projects.sort((a, b) {
      final aLocal = _localWeight(a, countyId, subcountyId);
      final bLocal = _localWeight(b, countyId, subcountyId);
      if (aLocal != bLocal) return bLocal.compareTo(aLocal);
      return b.createdAt.compareTo(a.createdAt);
    });
    return projects;
  }

  int _localWeight(CiviqProject project, int? countyId, int? subcountyId) {
    var weight = 0;
    if (countyId != null && project.countyId == countyId) weight += 5;
    if (subcountyId != null && project.subcountyId == subcountyId) weight += 8;
    if (project.verificationStatus == 'community_verified') weight += 2;
    return weight;
  }

  Future<void> createProject(CreateProjectInput input) async {
    if (!input.confirmedAccuracy) {
      throw Exception('Confirm the project information before submitting.');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to post a project.');

    await _client.from('projects').insert({
      'creator_id': userId,
      'title': input.title,
      'description': input.description,
      'project_type': input.projectType,
      'county_id': input.countyId,
      'subcounty_id': input.subcountyId,
      'location_name': input.locationName,
      'image_url': input.imageUrl,
      'verification_status': input.imageUrl == null
          ? 'unverified'
          : 'unverified',
    });
  }

  Future<void> updateProject(String projectId, CreateProjectInput input) async {
    if (!input.confirmedAccuracy) {
      throw Exception('Confirm the project information before saving.');
    }
    await _client
        .from('projects')
        .update({
          'title': input.title,
          'description': input.description,
          'project_type': input.projectType,
          'county_id': input.countyId,
          'subcounty_id': input.subcountyId,
          'location_name': input.locationName,
          if (input.imageUrl != null) 'image_url': input.imageUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', projectId);
  }

  Future<void> deleteProject(String projectId) async {
    await _client
        .from('projects')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', projectId);
  }

  Future<void> voteProject(String projectId, bool isApproval) async {
    await _client.rpc(
      'vote_project',
      params: {'target_project_id': projectId, 'vote_is_approval': isApproval},
    );
  }

  Future<void> reportProject(String projectId, String reason) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to report.');
    await _client.from('project_reports').upsert({
      'project_id': projectId,
      'reporter_id': userId,
      'reason': reason,
    }, onConflict: 'project_id,reporter_id');
  }

  Future<List<ProjectComment>> fetchComments(String projectId) async {
    final rows = await _client
        .from('v_project_comments')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);
    return rows
        .map<ProjectComment>(
          (row) => ProjectComment.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> addComment(
    String projectId,
    String body, {
    String? parentCommentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to comment.');
    await _client.from('project_comments').insert({
      'project_id': projectId,
      'author_id': userId,
      'body': body,
      'parent_comment_id': parentCommentId,
    });
  }

  Future<void> updateComment(String commentId, String body) async {
    await _client
        .from('project_comments')
        .update({
          'body': body,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('project_comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', commentId);
  }

  Future<void> toggleCommentLike(String commentId) async {
    await _client.rpc(
      'toggle_project_comment_like',
      params: {'target_comment_id': commentId},
    );
  }

  Future<void> reportComment(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sign in again to report.');
    await _client.from('project_comment_reports').insert({
      'comment_id': commentId,
      'reporter_id': userId,
      'reason': 'reported',
    });
  }
}
