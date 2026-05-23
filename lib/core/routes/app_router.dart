import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/terms_screen.dart';
import '../../features/chats/data/models/chat_models.dart';
import '../../features/chats/presentation/screens/chat_room_screen.dart';
import '../../features/export/presentation/screens/export_data_screen.dart';
import '../../features/home/presentation/screens/app_shell.dart';
import '../../features/legal/presentation/screens/legal_document_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/avatar_upload_screen.dart';
import '../../features/onboarding/presentation/screens/civiq_code_screen.dart';
import '../../features/onboarding/presentation/screens/intro_screen.dart';
import '../../features/onboarding/presentation/screens/notification_permission_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/profile/presentation/screens/account_status_screen.dart';
import '../../features/profile/presentation/screens/active_sessions_screen.dart';
import '../../features/profile/presentation/screens/devices_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/legal_history_screen.dart';
import '../../features/profile/presentation/screens/privacy_visibility_screen.dart';
import '../../features/profile/presentation/screens/public_profile_screen.dart';
import '../../features/profile/presentation/screens/security_activity_screen.dart';
import '../../features/profile/presentation/screens/security_screen.dart';
import '../../features/profile/presentation/screens/social_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/intro', builder: (context, state) => const IntroScreen()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/legal/privacy-policy',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacyPolicy),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/community-guidelines',
        builder: (context, state) => const LegalDocumentScreen(
          document: LegalDocument.communityGuidelines,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/chats/:id',
        builder: (context, state) {
          final conversationId = state.pathParameters['id'];
          if (conversationId == null || conversationId.isEmpty) {
            return const AppShell();
          }
          return ChatRoomScreen(
            conversationId: conversationId,
            initialConversation: state.extra is ChatConversation
                ? state.extra! as ChatConversation
                : null,
          );
        },
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/settings/security/activity',
        builder: (context, state) => const SecurityActivityScreen(),
      ),
      GoRoute(
        path: '/settings/security/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/settings/security/sessions',
        builder: (context, state) => const ActiveSessionsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyVisibilityScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/export',
        builder: (context, state) => const ExportDataScreen(),
      ),
      GoRoute(
        path: '/settings/account-status',
        builder: (context, state) => const AccountStatusScreen(),
      ),
      GoRoute(
        path: '/settings/legal-history',
        builder: (context, state) => const LegalHistoryScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:id/followers',
        builder: (context, state) {
          final profileId = state.pathParameters['id'];
          if (profileId == null || profileId.isEmpty) {
            return const AppShell();
          }
          return SocialListScreen(
            profileId: profileId,
            type: SocialListType.followers,
          );
        },
      ),
      GoRoute(
        path: '/profile/:id/following',
        builder: (context, state) {
          final profileId = state.pathParameters['id'];
          if (profileId == null || profileId.isEmpty) {
            return const AppShell();
          }
          return SocialListScreen(
            profileId: profileId,
            type: SocialListType.following,
          );
        },
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) {
          final profileId = state.pathParameters['id'];
          if (profileId == null || profileId.isEmpty) {
            return const AppShell();
          }
          return PublicProfileScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(
          initialMode: state.uri.queryParameters['mode'],
          initialLegalAccepted:
              state.uri.queryParameters['acceptedLegal'] == 'true',
        ),
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
