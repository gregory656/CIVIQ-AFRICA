import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../profile/data/profile_repository.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>((ref) {
  return RankingsRepository(ref.watch(supabaseClientProvider));
});

final rankingsProvider = FutureProvider<List<LeaderRanking>>((ref) async {
  final repository = ref.watch(rankingsRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).asData?.value;
  final filter = ref.watch(rankingFilterProvider);
  return repository.fetchRankings(
    filter: filter,
    viewerCountyId: profile?.countyId,
    viewerSubcountyId: profile?.subcountyId,
  );
});

final leaderProjectsProvider =
    FutureProvider.family<List<RankedLeaderProject>, String>((ref, leaderId) {
      return ref
          .watch(rankingsRepositoryProvider)
          .fetchLeaderProjects(leaderId);
    });

final rankingFilterProvider = StateProvider<RankingFilter>((ref) {
  return const RankingFilter();
});

enum RankingScope { national, county, subcounty }

enum RankingRole { governors, mps, mcas, senators }

class RankingFilter {
  const RankingFilter({
    this.scope = RankingScope.national,
    this.role = RankingRole.governors,
    this.countyId,
    this.subcountyId,
    this.query = '',
  });

  final RankingScope scope;
  final RankingRole role;
  final int? countyId;
  final int? subcountyId;
  final String query;

  String get roleLabel {
    return switch (role) {
      RankingRole.governors => 'Governor',
      RankingRole.mps => 'MP',
      RankingRole.mcas => 'MCA',
      RankingRole.senators => 'Senator',
    };
  }

  RankingFilter copyWith({
    RankingScope? scope,
    RankingRole? role,
    int? countyId,
    int? subcountyId,
    String? query,
    bool clearCounty = false,
    bool clearSubcounty = false,
  }) {
    return RankingFilter(
      scope: scope ?? this.scope,
      role: role ?? this.role,
      countyId: clearCounty ? null : countyId ?? this.countyId,
      subcountyId: clearSubcounty ? null : subcountyId ?? this.subcountyId,
      query: query ?? this.query,
    );
  }
}

class LeaderRanking {
  const LeaderRanking({
    required this.leaderId,
    required this.leaderName,
    required this.role,
    required this.partyName,
    required this.countyId,
    required this.countyName,
    required this.hasSnapshot,
    this.subcountyId,
    this.subcountyName,
    this.snapshotWeek,
    this.rank,
    this.score = 0,
    this.movement = 0,
    this.totalProjects = 0,
    this.completedProjects = 0,
    this.stalledProjects = 0,
    this.approvalCount = 0,
    this.disapprovalCount = 0,
    this.isTopTwenty = false,
    this.demographicMetadata = const {},
  });

  final String leaderId;
  final String leaderName;
  final String role;
  final String partyName;
  final int countyId;
  final String countyName;
  final int? subcountyId;
  final String? subcountyName;
  final bool hasSnapshot;
  final DateTime? snapshotWeek;
  final int? rank;
  final double score;
  final double movement;
  final int totalProjects;
  final int completedProjects;
  final int stalledProjects;
  final int approvalCount;
  final int disapprovalCount;
  final bool isTopTwenty;
  final Map<String, dynamic> demographicMetadata;

  int get totalVotes => approvalCount + disapprovalCount;

  double get approvalRatio {
    if (totalVotes == 0) return 0;
    return approvalCount / totalVotes;
  }

  double get completionRatio {
    if (totalProjects == 0) return 0;
    return completedProjects / totalProjects;
  }

  String get regionLabel {
    if (subcountyName != null && subcountyName!.isNotEmpty) {
      return '$subcountyName, $countyName';
    }
    return countyName;
  }

  factory LeaderRanking.fromSnapshot(Map<String, dynamic> json) {
    return LeaderRanking(
      leaderId: json['leader_id'] as String,
      leaderName: json['leader_name'] as String? ?? 'Unnamed leader',
      role: json['role'] as String? ?? '',
      partyName: json['party_name'] as String? ?? 'N/A',
      countyId: json['county_id'] as int? ?? 0,
      countyName: json['county_name'] as String? ?? 'Unknown county',
      subcountyId: json['subcounty_id'] as int?,
      subcountyName: json['subcounty_name'] as String?,
      hasSnapshot: true,
      snapshotWeek: DateTime.tryParse(json['snapshot_week'] as String? ?? ''),
      rank: json['rank'] as int?,
      score: _asDouble(json['score']),
      movement: _asDouble(json['movement']),
      totalProjects: json['total_projects'] as int? ?? 0,
      completedProjects: json['completed_projects'] as int? ?? 0,
      stalledProjects: json['stalled_projects'] as int? ?? 0,
      approvalCount: json['approval_count'] as int? ?? 0,
      disapprovalCount: json['disapproval_count'] as int? ?? 0,
      isTopTwenty: json['is_top_twenty'] as bool? ?? false,
      demographicMetadata: Map<String, dynamic>.from(
        json['demographic_metadata'] as Map? ?? const {},
      ),
    );
  }

  factory LeaderRanking.fromDirectory(Map<String, dynamic> json) {
    return LeaderRanking(
      leaderId: json['leader_id'] as String,
      leaderName: json['leader_name'] as String? ?? 'Unnamed leader',
      role: json['role'] as String? ?? '',
      partyName: json['party_name'] as String? ?? 'N/A',
      countyId: json['county_id'] as int? ?? 0,
      countyName: json['county_name'] as String? ?? 'Unknown county',
      subcountyId: json['subcounty_id'] as int?,
      subcountyName: json['subcounty_name'] as String?,
      totalProjects: json['linked_projects'] as int? ?? 0,
      hasSnapshot: false,
    );
  }
}

class RankedLeaderProject {
  const RankedLeaderProject({
    required this.projectId,
    required this.title,
    required this.projectType,
    required this.verificationStatus,
    required this.approvalCount,
    required this.disapprovalCount,
    required this.score,
    this.countyName,
    this.subcountyName,
  });

  final String projectId;
  final String title;
  final String projectType;
  final String verificationStatus;
  final int approvalCount;
  final int disapprovalCount;
  final double score;
  final String? countyName;
  final String? subcountyName;

  factory RankedLeaderProject.fromJson(Map<String, dynamic> json) {
    return RankedLeaderProject(
      projectId: json['project_id'] as String,
      title: json['title'] as String? ?? 'Untitled project',
      projectType: json['project_type'] as String? ?? 'ongoing',
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      approvalCount: json['approval_count'] as int? ?? 0,
      disapprovalCount: json['disapproval_count'] as int? ?? 0,
      score: _asDouble(json['score']),
      countyName: json['county_name'] as String?,
      subcountyName: json['subcounty_name'] as String?,
    );
  }
}

class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  Future<List<LeaderRanking>> fetchRankings({
    required RankingFilter filter,
    int? viewerCountyId,
    int? viewerSubcountyId,
  }) async {
    final snapshotRows = await _client
        .from('v_latest_leaderboard')
        .select()
        .eq('role', filter.roleLabel)
        .order('rank');

    final rankings = snapshotRows
        .map<LeaderRanking>(
          (row) => LeaderRanking.fromSnapshot(Map<String, dynamic>.from(row)),
        )
        .toList();

    final source = rankings.isEmpty
        ? await _fetchDirectory(filter.roleLabel)
        : rankings;
    return _applyFilter(
      source,
      filter,
      viewerCountyId: viewerCountyId,
      viewerSubcountyId: viewerSubcountyId,
    );
  }

  Future<List<LeaderRanking>> _fetchDirectory(String role) async {
    final rows = await _client
        .from('v_leader_directory')
        .select()
        .eq('role', role)
        .order('leader_name');

    return rows
        .map<LeaderRanking>(
          (row) => LeaderRanking.fromDirectory(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  List<LeaderRanking> _applyFilter(
    List<LeaderRanking> rows,
    RankingFilter filter, {
    int? viewerCountyId,
    int? viewerSubcountyId,
  }) {
    final countyId = filter.countyId ?? viewerCountyId;
    final subcountyId = filter.subcountyId ?? viewerSubcountyId;
    final query = filter.query.trim().toLowerCase();

    return rows.where((row) {
      if (filter.scope == RankingScope.county &&
          countyId != null &&
          row.countyId != countyId) {
        return false;
      }
      if (filter.scope == RankingScope.subcounty &&
          subcountyId != null &&
          row.subcountyId != subcountyId) {
        return false;
      }
      if (query.isNotEmpty &&
          !row.leaderName.toLowerCase().contains(query) &&
          !row.countyName.toLowerCase().contains(query) &&
          !(row.subcountyName?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<List<RankedLeaderProject>> fetchLeaderProjects(String leaderId) async {
    final rows = await _client
        .from('v_leader_project_links')
        .select()
        .eq('leader_id', leaderId)
        .order('created_at', ascending: false)
        .limit(30);

    return rows
        .map<RankedLeaderProject>(
          (row) => RankedLeaderProject.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
