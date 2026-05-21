import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/profile_repository.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Account Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _SecurityTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _maskEmail(profile?.email ?? ''),
              ),
              const _SecurityTile(
                icon: Icons.lock_clock_outlined,
                label: 'Session timeout',
                value: 'Default Supabase session',
              ),
              const SizedBox(height: 20),
              Text(
                'App Lock',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const _SecurityTile(
                icon: Icons.pin_outlined,
                label: '4-digit PIN',
                value: 'Planned secure-storage setup',
              ),
              const _SecurityTile(
                icon: Icons.fingerprint_outlined,
                label: 'Biometrics',
                value: 'Uses OS biometrics when enabled later',
              ),
              const SizedBox(height: 20),
              Text(
                'Recovery',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const _SecurityTile(
                icon: Icons.restart_alt_outlined,
                label: 'PIN reset',
                value: 'Requires full account reauthentication',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return 'Not available';
    final local = parts.first;
    final visible = local.length <= 4 ? local[0] : local.substring(0, 4);
    return '$visible***@${parts.last}';
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
