import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/notifications/data/notification_repository.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    final user = ref.read(authRepositoryProvider).currentUser;
    await LocalNotificationService.instance.requestPermission();
    if (user != null) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .createWelcomeNotifications(user.id);
        await LocalNotificationService.instance.show(
          id: 1001,
          title: 'Welcome to CIVIQ Africa.',
          body:
              'Read our guidelines and help improve your community responsibly.',
        );
        await LocalNotificationService.instance.show(
          id: 1002,
          title: 'Create your first civic project report.',
          body: 'Engage your local leadership and track development near you.',
        );
      } catch (_) {
        // Remote push delivery is added later with FCM/APNs; don't block onboarding.
      }
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.notifications_active_outlined,
                size: 82,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(height: 24),
              Text(
                'Stay updated',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Get real-time notifications and alerts...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _continue,
                child: Text(_loading ? 'Almost there...' : 'Continue to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
