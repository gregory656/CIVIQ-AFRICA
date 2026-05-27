import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/notification_settings_repository.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (settings) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Enable Notifications',
                subtitle: 'Master switch for configurable notifications.',
                value: settings.pushEnabled,
                onChanged: (value) =>
                    _togglePushNotifications(context, ref, settings, value),
              ),
              _SoundTile(settings: settings),
              _SwitchTile(
                icon: Icons.message_outlined,
                title: 'Messages',
                subtitle: 'Message and request notifications.',
                value: settings.messagesEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(messagesEnabled: value),
                ),
              ),
              _SwitchTile(
                icon: Icons.work_outline,
                title: 'Project updates',
                subtitle: 'Updates for SIVIQ project workflows.',
                value: settings.projectUpdatesEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(projectUpdatesEnabled: value),
                ),
              ),
              _SwitchTile(
                icon: Icons.shield_outlined,
                title: 'Moderation alerts',
                subtitle: 'Reports, appeals, and moderation decisions.',
                value: settings.moderationAlertsEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(moderationAlertsEnabled: value),
                ),
              ),
              _SwitchTile(
                icon: Icons.bar_chart_outlined,
                title: 'Rankings',
                subtitle: 'Ranking-related updates when rankings launch.',
                value: settings.rankingsEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(rankingsEnabled: value),
                ),
              ),
              const _LockedSecurityAlertsTile(),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    try {
      await ref
          .read(notificationSettingsRepositoryProvider)
          .save(userId, settings);
      ref.invalidate(notificationSettingsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    }
  }

  static Future<void> _togglePushNotifications(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
    bool enabled,
  ) async {
    if (enabled) {
      final allowed = await LocalNotificationService.instance
          .requestPermission();
      if (!allowed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Turn on notification permission to enable alerts.',
              ),
            ),
          );
        }
        ref.invalidate(notificationSettingsProvider);
        return;
      }
    }

    if (!context.mounted) return;
    await _save(context, ref, settings.copyWith(pushEnabled: enabled));
  }
}

class _SoundTile extends ConsumerWidget {
  const _SoundTile({required this.settings});

  final NotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.volume_up_outlined,
          color: AppColors.primaryGreen,
        ),
        title: const Text('Notification Sounds'),
        subtitle: Text(_label(settings.notificationSound)),
        trailing: DropdownButton<String>(
          value: settings.notificationSound,
          items: const [
            DropdownMenuItem(value: 'default', child: Text('Default')),
            DropdownMenuItem(value: 'soft', child: Text('Soft')),
            DropdownMenuItem(value: 'alert', child: Text('Alert')),
            DropdownMenuItem(value: 'silent', child: Text('Silent')),
          ],
          onChanged: (value) {
            if (value == null) return;
            NotificationSettingsScreen._save(
              context,
              ref,
              settings.copyWith(notificationSound: value),
            );
          },
        ),
      ),
    );
  }

  String _label(String value) {
    return switch (value) {
      'soft' => 'Soft',
      'alert' => 'Alert',
      'silent' => 'Silent',
      _ => 'Default',
    };
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

class _LockedSecurityAlertsTile extends StatelessWidget {
  const _LockedSecurityAlertsTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const SwitchListTile(
        secondary: Icon(Icons.security_outlined, color: AppColors.primaryGreen),
        title: Text('Security alerts'),
        subtitle: Text('Always on for account protection.'),
        value: true,
        onChanged: null,
      ),
    );
  }
}
