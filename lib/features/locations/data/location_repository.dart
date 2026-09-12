import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../shared/models/kenya_location.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(supabaseClientProvider));
});

final governanceLocationsProvider = FutureProvider<List<KenyaCounty>>((
  ref,
) async {
  return ref.watch(locationRepositoryProvider).fetchGovernanceLocations();
});

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  Future<List<KenyaCounty>> fetchGovernanceLocations() async {
    try {
      final rows = await _client
          .from('v_geographic_governance')
          .select(
            'county_id,county_name,subcounty_id,subcounty_name,governor_name,governor_party,mp_name,mp_party',
          )
          .order('county_name')
          .order('subcounty_name');
      final result = _buildLocations(rows);
      if (result.isEmpty) return kenyaCounties;
      return result;
    } catch (_) {
      return _fetchDirectLocations();
    }
  }

  Future<List<KenyaCounty>> _fetchDirectLocations() async {
    try {
      final responses = await Future.wait([
        _client.from('counties').select('id,name').order('name'),
        _client.from('subcounties').select('id,county_id,name').order('name'),
      ]);
      final counties = <int, _CountyBuilder>{};
      for (final row in responses[0]) {
        final id = row['id'] as int?;
        final name = row['name'] as String?;
        if (id != null && name != null) {
          counties[id] = _CountyBuilder(id: id, name: name);
        }
      }
      for (final row in responses[1]) {
        final id = row['id'] as int?;
        final countyId = row['county_id'] as int?;
        final name = row['name'] as String?;
        if (id != null && countyId != null && name != null) {
          counties[countyId]?.subcounties.add(
            KenyaSubcounty(id: id, name: name),
          );
        }
      }
      final result =
          counties.values
              .where((county) => county.subcounties.isNotEmpty)
              .map((county) => county.build())
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return result.isEmpty ? kenyaCounties : result;
    } catch (_) {
      return kenyaCounties;
    }
  }

  List<KenyaCounty> _buildLocations(List<dynamic> rows) {
    final counties = <int, _CountyBuilder>{};
    for (final row in rows) {
      final countyId = row['county_id'] as int?;
      final countyName = row['county_name'] as String?;
      final subcountyId = row['subcounty_id'] as int?;
      final subcountyName = row['subcounty_name'] as String?;
      if (countyId == null ||
          countyName == null ||
          subcountyId == null ||
          subcountyName == null) {
        continue;
      }
      final county = counties.putIfAbsent(
        countyId,
        () => _CountyBuilder(
          id: countyId,
          name: countyName,
          governorName: row['governor_name'] as String?,
          governorParty: row['governor_party'] as String?,
        ),
      );
      county.subcounties.add(
        KenyaSubcounty(
          id: subcountyId,
          name: subcountyName,
          mpName: row['mp_name'] as String?,
          mpParty: row['mp_party'] as String?,
        ),
      );
    }
    final result = counties.values.map((county) => county.build()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}

class _CountyBuilder {
  _CountyBuilder({
    required this.id,
    required this.name,
    this.governorName,
    this.governorParty,
  });

  final int id;
  final String name;
  final String? governorName;
  final String? governorParty;
  final List<KenyaSubcounty> subcounties = [];

  KenyaCounty build() {
    subcounties.sort((a, b) => a.name.compareTo(b.name));
    return KenyaCounty(
      id: id,
      name: name,
      governorName: governorName,
      governorParty: governorParty,
      subcounties: List.unmodifiable(subcounties),
    );
  }
}
