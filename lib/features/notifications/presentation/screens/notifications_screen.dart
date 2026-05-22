import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirmation_popup.dart';
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
          IconButton(
            tooltip: 'Archive',
            onPressed: () => _openArchive(context),
            icon: const Icon(Icons.archive_outlined),
          ),
          TextButton.icon(
            onPressed: () async {
              final user = ref.read(authRepositoryProvider).currentUser;
              if (user == null) return;
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllRead(user.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
              if (context.mounted) {
                await showConfirmationPopup(
                  context,
                  message: 'Notifications marked read',
                );
              }
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
                    onLongPress: () => _showActions(context, ref, item),
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

  void _openArchive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ArchivedNotificationsScreen(),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationDetailScreen(notification: item),
      ),
    );
    _refresh(ref);
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    CiviqNotification item,
  ) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(notificationRepositoryProvider).archive(item.id);
                _refresh(ref);
                if (parentContext.mounted) {
                  await showConfirmationPopup(
                    parentContext,
                    message: 'Notification archived',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_outlined),
              title: const Text('Report as spam'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref
                    .read(notificationRepositoryProvider)
                    .reportSpam(item.id);
                _refresh(ref);
                if (parentContext.mounted) {
                  await showConfirmationPopup(
                    parentContext,
                    message: 'Notification reported',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.dangerRed,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.dangerRed),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(notificationRepositoryProvider).delete(item.id);
                _refresh(ref);
                if (parentContext.mounted) {
                  await showConfirmationPopup(
                    parentContext,
                    message: 'Notification deleted',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(archivedNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }
}

class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({required this.notification, super.key});

  final CiviqNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.category == 'security'
                        ? Icons.security_outlined
                        : Icons.notifications_outlined,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              notification.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _archive(context, ref),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _reportSpam(context, ref),
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: const Text('Report as spam'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).archive(notification.id);
    _refresh(ref);
    if (context.mounted) {
      await showConfirmationPopup(context, message: 'Notification archived');
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _reportSpam(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).reportSpam(notification.id);
    _refresh(ref);
    if (context.mounted) {
      await showConfirmationPopup(context, message: 'Notification reported');
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).delete(notification.id);
    _refresh(ref);
    if (context.mounted) {
      await showConfirmationPopup(context, message: 'Notification deleted');
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(archivedNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }
}

class ArchivedNotificationsScreen extends ConsumerWidget {
  const ArchivedNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(archivedNotificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Archive')),
      body: SafeArea(
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _NotificationError(error: error),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No archived notifications.',
                  style: TextStyle(color: AppColors.grey),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(
                    Icons.archive_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(notificationRepositoryProvider)
                          .unarchive(item.id);
                      ref.invalidate(archivedNotificationsProvider);
                      ref.invalidate(notificationsProvider);
                      if (context.mounted) {
                        await showConfirmationPopup(
                          context,
                          message: 'Notification restored',
                        );
                      }
                    },
                    child: const Text('Restore'),
                  ),
                );
              },
            );
          },
        ),
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
