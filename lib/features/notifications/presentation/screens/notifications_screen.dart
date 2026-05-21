import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final user = ref.read(authRepositoryProvider).currentUser;
              if (user == null) return;
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllRead(user.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            icon: const Icon(Icons.done_all_outlined),
            label: const Text('Mark all as read'),
          ),
        ],
      ),
      body: SafeArea(
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _NotificationError(error: error),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    onTap: () => _openNotification(context, ref, item),
                    leading: Icon(
                      item.isRead
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                      color: item.isRead
                          ? AppColors.grey
                          : AppColors.primaryGreen,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(item.body),
                    trailing: Text(
                      item.isRead ? 'Read' : 'Unread',
                      style: TextStyle(
                        color: item.isRead
                            ? AppColors.grey
                            : AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
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

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    CiviqNotification item,
  ) async {
    if (!item.isRead) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Text(item.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load notifications.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.dangerRed),
        ),
      ),
    );
  }
}
