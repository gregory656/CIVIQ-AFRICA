import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/profile_repository.dart';

class PrivacyVisibilityScreen extends ConsumerStatefulWidget {
  const PrivacyVisibilityScreen({super.key});

  @override
  ConsumerState<PrivacyVisibilityScreen> createState() =>
      _PrivacyVisibilityScreenState();
}

class _PrivacyVisibilityScreenState
    extends ConsumerState<PrivacyVisibilityScreen> {
  bool? _isPublic;
  bool? _showOnlineStatus;
  bool? _showReadReceipts;
  bool? _allowMessageRequests;
  bool? _showActivity;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Visibility')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not available.'));
            }
            _hydrate(profile);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SwitchTile(
                  icon: Icons.public_outlined,
                  title: 'Public Profile',
                  subtitle: 'Controls username search and profile discovery.',
                  value: _isPublic!,
                  onChanged: (value) => _save(isPublic: value),
                ),
                _SwitchTile(
                  icon: Icons.online_prediction_outlined,
                  title: 'Show Online Status',
                  subtitle: 'Controls online presence and last seen.',
                  value: _showOnlineStatus!,
                  onChanged: (value) => _save(showOnlineStatus: value),
                ),
                _SwitchTile(
                  icon: Icons.done_all_outlined,
                  title: 'Show Read Receipts',
                  subtitle: 'Applies to future chat features.',
                  value: _showReadReceipts!,
                  onChanged: (value) => _save(showReadReceipts: value),
                ),
                _SwitchTile(
                  icon: Icons.qr_code_2_outlined,
                  title: 'Allow message requests via CIVIQ code',
                  subtitle:
                      'Lets people request contact using your CIVIQ code.',
                  value: _allowMessageRequests!,
                  onChanged: (value) => _save(allowMessageRequests: value),
                ),
                _SwitchTile(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Show civic engagement publicly',
                  subtitle: 'Controls public activity visibility.',
                  value: _showActivity!,
                  onChanged: (value) => _save(showActivity: value),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _hydrate(CiviqProfile profile) {
    _isPublic ??= profile.isPublic;
    _showOnlineStatus ??= profile.showOnlineStatus;
    _showReadReceipts ??= profile.showReadReceipts;
    _allowMessageRequests ??= profile.allowMessageRequests;
    _showActivity ??= profile.showActivity;
  }

  Future<void> _save({
    bool? isPublic,
    bool? showOnlineStatus,
    bool? showReadReceipts,
    bool? allowMessageRequests,
    bool? showActivity,
  }) async {
    if (_saving) return;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    setState(() {
      _saving = true;
      _isPublic = isPublic ?? _isPublic;
      _showOnlineStatus = showOnlineStatus ?? _showOnlineStatus;
      _showReadReceipts = showReadReceipts ?? _showReadReceipts;
      _allowMessageRequests = allowMessageRequests ?? _allowMessageRequests;
      _showActivity = showActivity ?? _showActivity;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePrivacySettings(
            userId: userId,
            isPublic: _isPublic!,
            showOnlineStatus: _showOnlineStatus!,
            showReadReceipts: _showReadReceipts!,
            allowMessageRequests: _allowMessageRequests!,
            showActivity: _showActivity!,
          );
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primaryGreen),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
