import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/security_repository.dart';

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(accountDeletionProvider);
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account Status')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              friendlyErrorMessage(
                error,
                fallback: 'Could not load account status.',
              ),
            ),
          ),
          data: (profile) {
            if (profile?.isRestricted ?? false) {
              return _RestrictedAccount(profile: profile!);
            }
            return request.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  friendlyErrorMessage(
                    error,
                    fallback: 'Could not load account status.',
                  ),
                ),
              ),
              data: (request) {
                if (request == null || !request.isPending) {
                  return const Center(
                    child: Text(
                      'Your account is active.',
                      style: TextStyle(color: AppColors.grey),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      color: AppColors.dangerRed,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Deletion pending',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Requested: ${_dateLabel(request.requestedAt)}'),
                    Text(
                      'Scheduled purge: ${_dateLabel(request.scheduledPurgeAt)}',
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _cancel(context, ref),
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Cancel deletion'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    await ref.read(securityRepositoryProvider).cancelAccountDeletion(userId);
    ref.invalidate(accountDeletionProvider);
    ref.invalidate(currentProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion cancelled.')),
      );
    }
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _RestrictedAccount extends ConsumerWidget {
  const _RestrictedAccount({required this.profile});

  final CiviqProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final until = profile.suspensionUntil;
    final status = profile.accountStatus.replaceAll('_', ' ');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(
          Icons.gpp_maybe_outlined,
          color: AppColors.dangerRed,
          size: 44,
        ),
        const SizedBox(height: 12),
        Text(
          'Account restricted',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text('Status: $status'),
        if (until != null) Text('Suspension ends: ${_dateTimeLabel(until)}'),
        const SizedBox(height: 12),
        const Text(
          'Some SIVIQ actions are temporarily unavailable. You can submit an appeal if you believe this was a mistake.',
          style: TextStyle(color: AppColors.grey, height: 1.35),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => context.go('/legal/appeals'),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Appeal restriction'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) context.go('/intro');
          },
          icon: const Icon(Icons.logout_outlined),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  static String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
