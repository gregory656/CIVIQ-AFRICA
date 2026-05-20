import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../shared/models/kenya_location.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  KenyaCounty _county = kenyaCounties.first;
  KenyaSubcounty _subcounty = kenyaCounties.first.subcounties.first;
  List<String> _suggestions = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = const [];
    });

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final username = _usernameController.text.trim();
      if (await profileRepo.isUsernameTaken(username)) {
        setState(
          () => _suggestions = profileRepo.usernameSuggestions(username),
        );
        return;
      }

      final auth = ref.read(authRepositoryProvider);
      final user = auth.currentUser;
      if (user == null) throw Exception('You need to sign in again.');

      await profileRepo.upsertProfile(
        userId: user.id,
        email: user.email ?? '',
        username: username,
        bio: _bioController.text.trim(),
        countyId: _county.id,
        subcountyId: _subcounty.id,
      );

      if (mounted) context.go('/avatar-upload');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final username = value?.trim() ?? '';
                    if (username.length < 3)
                      return 'Use at least 3 characters.';
                    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(username)) {
                      return 'Use letters, numbers, and underscores only.';
                    }
                    return null;
                  },
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _suggestions
                        .map(
                          (name) => ActionChip(
                            label: Text(name),
                            onPressed: () {
                              _usernameController.text = name;
                              setState(() => _suggestions = const []);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<KenyaCounty>(
                  value: _county,
                  decoration: const InputDecoration(labelText: 'County'),
                  items: kenyaCounties
                      .map(
                        (county) => DropdownMenuItem(
                          value: county,
                          child: Text(county.name),
                        ),
                      )
                      .toList(),
                  onChanged: (county) {
                    if (county == null) return;
                    setState(() {
                      _county = county;
                      _subcounty = county.subcounties.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<KenyaSubcounty>(
                  value: _subcounty,
                  decoration: const InputDecoration(labelText: 'Sub-county'),
                  items: _county.subcounties
                      .map(
                        (subcounty) => DropdownMenuItem(
                          value: subcounty,
                          child: Text(subcounty.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _subcounty = value);
                  },
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
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? 'Saving...' : 'Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
