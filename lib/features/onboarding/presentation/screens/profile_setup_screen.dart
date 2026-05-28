import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/locations/data/location_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../shared/models/kenya_location.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  KenyaCounty? _county;
  KenyaSubcounty? _subcounty;
  List<String> _suggestions = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
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
      final displayName = _displayNameController.text.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final username = _usernameController.text.trim();
      if (await profileRepo.isUsernameTaken(username)) {
        setState(
          () => _suggestions = profileRepo.usernameSuggestions(username),
        );
        return;
      }

      if (_county == null || _subcounty == null) {
        throw Exception('Select your county and sub-county.');
      }

      final auth = ref.read(authRepositoryProvider);
      final user = auth.currentUser;
      if (user == null) throw Exception('You need to sign in again.');

      await profileRepo.upsertProfile(
        userId: user.id,
        email: user.email ?? '',
        displayName: displayName,
        username: username,
        bio: _bioController.text.trim(),
        countyId: _county!.id,
        subcountyId: _subcounty!.id,
      );
      ref.invalidate(currentProfileProvider);

      if (mounted) context.go('/avatar-upload');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(governanceLocationsProvider);

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
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'Gregory Steve',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  validator: (value) {
                    return ref
                        .read(profileRepositoryProvider)
                        .displayNameValidationMessage(value ?? '');
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                    LengthLimitingTextInputFormatter(30),
                  ],
                  validator: (value) {
                    final username = value?.trim() ?? '';
                    return ref
                        .read(profileRepositoryProvider)
                        .usernameValidationMessage(username);
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
                locations.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Could not load counties: $error'),
                  data: (counties) {
                    final county = _county ?? counties.first;
                    _county ??= county;
                    _subcounty ??= county.subcounties.first;
                    return _SearchPickerField<KenyaCounty>(
                      label: 'County',
                      icon: Icons.location_on_outlined,
                      value: county.name,
                      options: counties,
                      optionTitle: (county) => county.name,
                      optionSubtitle: (county) {
                        final governor = county.governorName;
                        if (governor == null || governor.isEmpty) {
                          return '${county.subcounties.length} constituencies';
                        }
                        return 'Governor: $governor (${county.governorParty ?? 'Party N/A'})';
                      },
                      onSelected: (county) {
                        setState(() {
                          _county = county;
                          _subcounty = county.subcounties.first;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                _SearchPickerField<KenyaSubcounty>(
                  label: 'Sub-county / Constituency',
                  icon: Icons.map_outlined,
                  value: _subcounty?.name ?? '',
                  options: _county?.subcounties ?? const [],
                  optionTitle: (subcounty) => subcounty.name,
                  optionSubtitle: (subcounty) {
                    final mp = subcounty.mpName;
                    if (mp == null || mp.isEmpty) return 'MP details pending';
                    return 'MP: $mp (${subcounty.mpParty ?? 'Party N/A'})';
                  },
                  onSelected: (subcounty) {
                    setState(() => _subcounty = subcounty);
                  },
                  validator: (_) {
                    if (_subcounty == null) {
                      return 'Select your sub-county.';
                    }
                    return null;
                  },
                ),
                if (_county != null || _subcounty != null) ...[
                  const SizedBox(height: 12),
                  _LeaderSummary(county: _county, subcounty: _subcounty),
                ],
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

class _SearchPickerField<T> extends StatelessWidget {
  const _SearchPickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.optionTitle,
    required this.optionSubtitle,
    required this.onSelected,
    this.validator,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<T> options;
  final String Function(T option) optionTitle;
  final String Function(T option) optionSubtitle;
  final ValueChanged<T> onSelected;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.search),
      ),
      validator: validator,
      onTap: options.isEmpty
          ? null
          : () async {
              final selected = await showSearch<T?>(
                context: context,
                delegate: _OptionSearchDelegate<T>(
                  label: label,
                  options: options,
                  titleFor: optionTitle,
                  subtitleFor: optionSubtitle,
                ),
              );
              if (selected != null) onSelected(selected);
            },
    );
  }
}

class _OptionSearchDelegate<T> extends SearchDelegate<T?> {
  _OptionSearchDelegate({
    required this.label,
    required this.options,
    required this.titleFor,
    required this.subtitleFor,
  });

  final String label;
  final List<T> options;
  final String Function(T option) titleFor;
  final String Function(T option) subtitleFor;

  @override
  String get searchFieldLabel => 'Search $label';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Clear',
        onPressed: () => query = '',
        icon: const Icon(Icons.close),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildOptions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildOptions(context);

  Widget _buildOptions(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? options
        : options.where((option) {
            final title = titleFor(option).toLowerCase();
            final subtitle = subtitleFor(option).toLowerCase();
            return title.contains(normalized) || subtitle.contains(normalized);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No matches found.'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final option = filtered[index];
        return ListTile(
          title: Text(titleFor(option)),
          subtitle: Text(subtitleFor(option)),
          onTap: () => close(context, option),
        );
      },
    );
  }
}

class _LeaderSummary extends StatelessWidget {
  const _LeaderSummary({required this.county, required this.subcounty});

  final KenyaCounty? county;
  final KenyaSubcounty? subcounty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _LeaderRow(
            icon: Icons.account_balance_outlined,
            label: 'Governor',
            value: county?.governorName ?? 'Pending',
            party: county?.governorParty,
          ),
          const Divider(),
          _LeaderRow(
            icon: Icons.how_to_vote_outlined,
            label: 'MP',
            value: subcounty?.mpName ?? 'Pending',
            party: subcounty?.mpParty,
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.icon,
    required this.label,
    required this.value,
    this.party,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? party;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.grey)),
              Text(
                party == null || party!.isEmpty ? value : '$value - $party',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
