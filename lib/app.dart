import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/services/notification_realtime_listener.dart';
import 'core/security/app_lock_gate.dart';
import 'core/theme/app_theme.dart';

class CiviqAfricaApp extends ConsumerWidget {
  const CiviqAfricaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SIVIQ',
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => NotificationRealtimeListener(
        child: AppLockGate(child: child ?? const SizedBox()),
      ),
    );
  }
}
