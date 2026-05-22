import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/security_repository.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(trustedDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: SafeArea(
        child: devices.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load: $error')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No devices registered yet.'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(trustedDevicesProvider),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = items[index];
                  return ListTile(
                    leading: Icon(
                      device.isRevoked
                          ? Icons.phonelink_erase_outlined
                          : Icons.devices_outlined,
                      color: device.isRevoked
                          ? AppColors.grey
                          : AppColors.primaryGreen,
                    ),
                    title: Text(
                      device.isCurrent
                          ? '${device.deviceLabel} (current)'
                          : device.deviceLabel,
                    ),
                    subtitle: Text(
                      '${device.platform} • Last seen ${_dateLabel(device.lastSeenAt)}',
                    ),
                    trailing: device.isRevoked
                        ? const Text('Revoked')
                        : TextButton(
                            onPressed: device.isCurrent
                                ? null
                                : () => _revoke(context, ref, device),
                            child: const Text('Revoke'),
                          ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    TrustedDevice device,
  ) async {
    await ref.read(securityRepositoryProvider).revokeDevice(device.id);
    ref.invalidate(trustedDevicesProvider);
    ref.invalidate(securityEventsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device revoked.')));
    }
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
