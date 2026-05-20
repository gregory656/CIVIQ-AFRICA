import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/terms_screen.dart';
import '../../features/home/presentation/screens/app_shell.dart';
import '../../features/onboarding/presentation/screens/avatar_upload_screen.dart';
import '../../features/onboarding/presentation/screens/civiq_code_screen.dart';
import '../../features/onboarding/presentation/screens/intro_screen.dart';
import '../../features/onboarding/presentation/screens/notification_permission_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/intro', builder: (context, state) => const IntroScreen()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, state) =>
            AuthScreen(initialMode: state.uri.queryParameters['mode']),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/avatar-upload',
        builder: (context, state) => const AvatarUploadScreen(),
      ),
      GoRoute(
        path: '/civiq-code',
        builder: (context, state) =>
            CiviqCodeScreen(code: state.uri.queryParameters['code'] ?? ''),
      ),
      GoRoute(
        path: '/notifications-permission',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const AppShell()),
    ],
  );
});
