import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/security_repository.dart';

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(trustedDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Active Sessions')),
      body: SafeArea(
        child: devices.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load: $error')),
          data: (items) {
            final active = items.where((item) => !item.isRevoked).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FilledButton.icon(
                  onPressed: active.any((item) => !item.isCurrent)
                      ? () => _revokeOtherSessions(context, ref)
                      : null,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Revoke other sessions'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _logoutCurrent(context, ref),
                  icon: const Icon(Icons.power_settings_new_outlined),
                  label: const Text('Revoke all sessions'),
                ),
                const SizedBox(height: 16),
                for (final item in active)
                  _SessionTile(device: item, current: item.isCurrent),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No active sessions found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grey),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _revokeOtherSessions(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    await ref.read(authRepositoryProvider).signOutOtherSessions();
    await ref.read(securityRepositoryProvider).revokeOtherDevices(userId);
    ref.invalidate(trustedDevicesProvider);
    ref.invalidate(securityEventsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Other sessions revoked.')));
    }
  }

  Future<void> _logoutCurrent(BuildContext context, WidgetRef ref) async {
    ref.read(currentAuthUserIdProvider.notifier).state = null;
    await ref.read(authRepositoryProvider).signOutAllSessions();
    ref.invalidate(currentProfileProvider);
    ref.invalidate(trustedDevicesProvider);
    ref.invalidate(securityEventsProvider);
    if (context.mounted) context.go('/intro');
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.device, required this.current});

  final TrustedDevice device;
  final bool current;

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
        leading: const Icon(
          Icons.laptop_mac_outlined,
          color: AppColors.primaryGreen,
        ),
        title: Text(current ? 'Current session' : device.deviceLabel),
        subtitle: Text(
          'Login approx. ${_dateLabel(device.trustedAt)}\n'
          'Last active ${_dateLabel(device.lastSeenAt)} • ${device.platform}',
        ),
        isThreeLine: true,
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
