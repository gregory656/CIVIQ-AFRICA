import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../locations/data/location_repository.dart';
import '../../../../shared/models/kenya_location.dart';
import '../../data/profile_repository.dart';

class EditLocationScreen extends ConsumerStatefulWidget {
  const EditLocationScreen({super.key});

  @override
  ConsumerState<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends ConsumerState<EditLocationScreen> {
  KenyaCounty? _county;
  KenyaSubcounty? _subcounty;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  Future<void> _save(CiviqProfile profile) async {
    if (_county == null || _subcounty == null) {
      setState(() => _error = 'Choose both your county and constituency.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        throw Exception('You need to sign in again.');
      }
      await ref
          .read(profileRepositoryProvider)
          .upsertProfile(
            userId: user.id,
            email: user.email ?? profile.email,
            countyId: _county!.id,
            subcountyId: _subcounty!.id,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('County and constituency updated')),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorMessage(
            error,
            fallback: 'We could not save your location. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final locations = ref.watch(governanceLocationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Update location')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyErrorMessage(error))),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }
          return locations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text(friendlyErrorMessage(error))),
            data: (counties) {
              if (!_initialized && counties.isNotEmpty) {
                _county =
                    counties
                        .where((c) => c.id == profile.countyId)
                        .firstOrNull ??
                    counties.first;
                _subcounty =
                    _county!.subcounties
                        .where((s) => s.id == profile.subcountyId)
                        .firstOrNull ??
                    _county!.subcounties.first;
                _initialized = true;
              }
              if (_county == null || _subcounty == null) {
                return const Center(child: Text('Locations are unavailable.'));
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Changing your location updates only these two fields.',
                    style: TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: ValueKey('county-${_county!.id}'),
                    initialValue: _county!.id,
                    decoration: const InputDecoration(
                      labelText: 'County',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: counties
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (id) => setState(() {
                            _county = counties.firstWhere((c) => c.id == id);
                            _subcounty = _county!.subcounties.first;
                          }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey('subcounty-${_subcounty!.id}'),
                    initialValue: _subcounty!.id,
                    decoration: const InputDecoration(
                      labelText: 'Constituency',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: _county!.subcounties
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (id) => setState(
                            () => _subcounty = _county!.subcounties.firstWhere(
                              (s) => s.id == id,
                            ),
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.dangerRed),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(profile),
                    child: Text(_saving ? 'Saving...' : 'Save location'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
