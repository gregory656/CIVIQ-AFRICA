import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';

final monetizationRepositoryProvider = Provider<MonetizationRepository>((ref) {
  return MonetizationRepository(ref.watch(supabaseClientProvider));
});

final interestsProvider = FutureProvider<List<CiviqInterest>>((ref) {
  return ref.watch(monetizationRepositoryProvider).fetchInterests();
});

const fallbackInterests = [
  'Infrastructure',
  'Roads',
  'Water',
  'Healthcare',
  'Education',
  'Jobs',
  'Youth',
  'Environment',
  'Safety',
  'Housing',
  'Technology',
  'Governance',
];

final recentSearchesProvider = FutureProvider<List<CiviqSearchHistoryItem>>((
  ref,
) {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return Future.value(const []);
  return ref.watch(monetizationRepositoryProvider).recentSearches(userId);
});

final discoverAdsProvider = FutureProvider<List<CiviqAd>>((ref) {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return Future.value(const []);
  return ref.watch(monetizationRepositoryProvider).fetchPersonalizedAds();
});

final weeklyTrendingSearchesProvider = FutureProvider<List<CiviqSearchTrend>>((
  ref,
) {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return Future.value(const []);
  return ref.watch(monetizationRepositoryProvider).fetchTrendingSearches();
});

class CiviqInterest {
  const CiviqInterest({required this.id, required this.name});

  final String id;
  final String name;

  factory CiviqInterest.fromJson(Map<String, dynamic> json) {
    return CiviqInterest(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
    );
  }
}

class CiviqSearchHistoryItem {
  const CiviqSearchHistoryItem({required this.term, this.searchType});

  final String term;
  final String? searchType;

  Map<String, dynamic> toJson() => {'term': term, 'searchType': searchType};

  factory CiviqSearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return CiviqSearchHistoryItem(
      term: json['term'] as String? ?? json['search_term'] as String? ?? '',
      searchType:
          json['searchType'] as String? ?? json['search_type'] as String?,
    );
  }
}

class CiviqSearchTrend {
  const CiviqSearchTrend({required this.term, required this.count});

  final String term;
  final int count;

  factory CiviqSearchTrend.fromJson(Map<String, dynamic> json) {
    return CiviqSearchTrend(
      term: json['search_term'] as String? ?? '',
      count: json['search_count'] as int? ?? 0,
    );
  }
}

class CiviqAd {
  const CiviqAd({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.destinationUrl,
    this.category,
  });

  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? destinationUrl;
  final String? category;

  factory CiviqAd.fromJson(Map<String, dynamic> json) {
    return CiviqAd(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Sponsored',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      destinationUrl: json['destination_url'] as String?,
      category: json['category'] as String?,
    );
  }
}

class MonetizationRepository {
  MonetizationRepository(this._client);

  final SupabaseClient _client;

  Future<List<CiviqInterest>> fetchInterests() async {
    try {
      final rows = await _client.from('interests').select().order('name');
      if (rows.isNotEmpty) {
        return rows
            .map<CiviqInterest>(
              (row) => CiviqInterest.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
      }
    } catch (_) {}
    return fallbackInterests
        .map((name) => CiviqInterest(id: 'fallback-$name', name: name))
        .toList(growable: false);
  }

  Future<void> saveUserInterests({
    required String userId,
    required Iterable<String> interestIds,
  }) async {
    final uniqueIds = interestIds.toSet().take(5).toList(growable: false);
    if (uniqueIds.every((id) => id.startsWith('fallback-'))) return;
    await _client.from('user_interests').delete().eq('user_id', userId);
    if (uniqueIds.isEmpty) return;
    await _client
        .from('user_interests')
        .insert(
          uniqueIds
              .map((interestId) {
                return {'user_id': userId, 'interest_id': interestId};
              })
              .toList(growable: false),
        );
  }

  Future<void> recordSearch({
    required String userId,
    required String searchTerm,
    String searchType = 'global',
  }) async {
    final normalized = searchTerm.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) return;
    await Future.wait([
      _recordSearchRemotely(
        userId: userId,
        searchTerm: normalized,
        searchType: searchType,
      ),
      _recordSearchLocally(
        userId: userId,
        item: CiviqSearchHistoryItem(term: normalized, searchType: searchType),
      ),
    ]);
  }

  Future<List<CiviqSearchHistoryItem>> recentSearches(String userId) async {
    final local = await _readLocalSearches(userId);
    if (local.isNotEmpty) return local;

    final rows = await _client
        .from('search_history')
        .select('search_term,search_type,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10);
    final seen = <String>{};
    return rows
        .map<CiviqSearchHistoryItem>(
          (row) =>
              CiviqSearchHistoryItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .where(
          (item) => item.term.isNotEmpty && seen.add(item.term.toLowerCase()),
        )
        .take(5)
        .toList(growable: false);
  }

  Future<void> removeRecentSearch(String userId, String term) async {
    final normalized = term.trim().toLowerCase();
    final local = await _readLocalSearches(userId);
    final remaining = local
        .where((item) => item.term.trim().toLowerCase() != normalized)
        .toList(growable: false);
    await _writeLocalSearches(userId, remaining);
    await _client
        .from('search_history')
        .delete()
        .eq('user_id', userId)
        .ilike('search_term', term);
  }

  Future<void> clearRecentSearches(String userId) async {
    await _writeLocalSearches(userId, const []);
    await _client.from('search_history').delete().eq('user_id', userId);
  }

  Future<List<CiviqAd>> fetchPersonalizedAds({int limit = 4}) async {
    final rows = await _client.rpc(
      'get_personalized_ads',
      params: {'page_limit': limit},
    );
    return (rows as List)
        .map<CiviqAd>((row) => CiviqAd.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> recordAdImpression(String adId) {
    return _client.rpc(
      'record_ad_event',
      params: {'target_ad_id': adId, 'event_kind': 'impression'},
    );
  }

  Future<void> recordAdClick(String adId) {
    return _client.rpc(
      'record_ad_event',
      params: {'target_ad_id': adId, 'event_kind': 'click'},
    );
  }

  Future<List<CiviqSearchTrend>> fetchTrendingSearches() async {
    final rows = await _client.rpc(
      'get_latest_weekly_search_trends',
      params: {'page_limit': 10},
    );
    return (rows as List)
        .map<CiviqSearchTrend>(
          (row) => CiviqSearchTrend.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((trend) => trend.term.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _recordSearchRemotely({
    required String userId,
    required String searchTerm,
    required String searchType,
  }) {
    return _client.from('search_history').insert({
      'user_id': userId,
      'search_term': searchTerm,
      'search_type': searchType,
    });
  }

  Future<void> _recordSearchLocally({
    required String userId,
    required CiviqSearchHistoryItem item,
  }) async {
    final existing = await _readLocalSearches(userId);
    final normalized = item.term.toLowerCase();
    final updated = [
      item,
      ...existing.where((entry) => entry.term.toLowerCase() != normalized),
    ].take(5).toList(growable: false);
    await _writeLocalSearches(userId, updated);
  }

  Future<File> _localSearchFile(String userId) async {
    final directory = await getApplicationSupportDirectory();
    final safeUserId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${directory.path}/siviq_recent_searches_$safeUserId.json');
  }

  Future<List<CiviqSearchHistoryItem>> _readLocalSearches(String userId) async {
    try {
      final file = await _localSearchFile(userId);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => CiviqSearchHistoryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.term.trim().isNotEmpty)
          .take(5)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeLocalSearches(
    String userId,
    List<CiviqSearchHistoryItem> searches,
  ) async {
    final file = await _localSearchFile(userId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(searches.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}
