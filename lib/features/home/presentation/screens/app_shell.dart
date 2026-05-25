import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../../features/account/data/account_repository.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/chats/data/repositories/chat_repository.dart';
import '../../../../features/chats/presentation/screens/chats_screen.dart';
import '../../../../features/locations/data/location_repository.dart';
import '../../../../features/notifications/data/notification_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../features/profile/data/security_repository.dart';
import '../../../../features/profile/presentation/screens/social_list_screen.dart';
import '../../../../shared/models/kenya_location.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  final _tabs = const [
    _ShellTab(title: 'Home Feed', icon: Icons.home_outlined),
    _ShellTab(title: 'Rankings', icon: Icons.bar_chart_outlined),
    _ShellTab(title: 'Projects', icon: Icons.work_outline),
    _ShellTab(title: 'Chats', icon: Icons.message_outlined),
    _ShellTab(title: 'Profile', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];

    return Scaffold(
      drawer: _index == 3
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: BrandMark(size: 38),
                    ),
                    const Divider(),
                    const _DrawerItem(icon: Icons.help_outline, label: 'FAQ'),
                    _DrawerItem(
                      icon: Icons.groups_outlined,
                      label: 'Community Guidelines',
                      route: '/legal/community-guidelines',
                    ),
                    _DrawerItem(
                      icon: Icons.gavel_outlined,
                      label: 'Terms',
                      route: '/legal/terms',
                    ),
                    const _DrawerItem(
                      icon: Icons.assignment_return_outlined,
                      label: 'Appeals',
                    ),
                    _DrawerItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      route: '/legal/privacy-policy',
                    ),
                    const _DrawerItem(icon: Icons.info_outline, label: 'About'),
                    const _DrawerItem(
                      icon: Icons.mail_outline,
                      label: 'Contact',
                    ),
                  ],
                ),
              ),
            ),
      appBar: _index == 3
          ? null
          : AppBar(
              titleSpacing: 0,
              title: const BrandMark(size: 34),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final unread = ref.watch(
                          unreadNotificationCountProvider,
                        );
                        return unread.maybeWhen(
                          data: (count) => count > 0
                              ? Positioned(
                                  top: 11,
                                  right: 10,
                                  child: _UnreadBadge(count: count),
                                )
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                    PopupMenuItem(value: 'report', child: Text('Report issue')),
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'sort', child: Text('Sort')),
                    PopupMenuItem(value: 'filter', child: Text('Filter')),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search anything...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _ShellBody(tab: tab, index: _index),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.title.split(' ').first,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShellBody extends ConsumerWidget {
  const _ShellBody({required this.tab, required this.index});

  final _ShellTab tab;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (index == 4) {
      final profile = ref.watch(currentProfileProvider);
      final locations = ref.watch(governanceLocationsProvider);
      return profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileError(error: error),
        data: (profile) => locations.when(
          loading: () => _ProfileTab(profile: profile, counties: kenyaCounties),
          error: (_, _) =>
              _ProfileTab(profile: profile, counties: kenyaCounties),
          data: (counties) => _ProfileTab(profile: profile, counties: counties),
        ),
      );
    }

    if (index == 3) {
      return const ChatsScreen();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 72, color: AppColors.primaryGreen),
            const SizedBox(height: 18),
            Text(
              '${tab.title} Coming Soon',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.profile, required this.counties});

  final CiviqProfile? profile;
  final List<KenyaCounty> counties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final county = _countyName(profile?.countyId, counties);
    final subcounty = _subcountyName(
      profile?.countyId,
      profile?.subcountyId,
      counties,
    );
    final displayName = profile?.username?.isNotEmpty == true
        ? '@${profile!.username}'
        : 'CIVIQ Member';
    final code = profile?.civiqCode?.isNotEmpty == true
        ? profile!.civiqCode!
        : 'Pending code';

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(currentProfileProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _ProfileAvatar(url: profile?.avatarUrl)),
          const SizedBox(height: 12),
          Center(
            child: _VerifiedName(
              displayName: displayName,
              isVerified: profile?.isVerified ?? false,
            ),
          ),
          if (profile?.roleLabel?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              profile!.roleLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _SocialStatsRow(profile: profile),
          const SizedBox(height: 10),
          const Text(
            'Email hidden for privacy',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 18),
          _CodePanel(code: code),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 10),
          _ProfileDetail(
            icon: Icons.notes_outlined,
            label: 'Bio',
            value: profile?.bio?.isNotEmpty == true
                ? profile!.bio!
                : 'No bio added yet.',
          ),
          _ProfileDetail(
            icon: Icons.location_on_outlined,
            label: 'County',
            value: county ?? 'Not selected',
          ),
          _ProfileDetail(
            icon: Icons.map_outlined,
            label: 'Sub-county',
            value: subcounty ?? 'Not selected',
          ),
          const SizedBox(height: 14),
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          _SettingsTile(
            icon: Icons.security_outlined,
            label: 'Security',
            onTap: () => context.push('/settings/security'),
          ),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            label: 'Privacy & Visibility',
            onTap: () => context.push('/settings/privacy'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => context.push('/settings/notifications'),
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            label: 'Export Data',
            onTap: () => context.push('/settings/export'),
          ),
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            label: 'Account Status',
            onTap: () => context.push('/settings/account-status'),
          ),
          _SettingsTile(
            icon: Icons.gavel_outlined,
            label: 'Legal History',
            onTap: () => context.push('/settings/legal-history'),
          ),
          const SizedBox(height: 20),
          const _DangerZoneActions(),
        ],
      ),
    );
  }
}

class _VerifiedName extends StatelessWidget {
  const _VerifiedName({required this.displayName, required this.isVerified});

  final String displayName;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 5),
          const CiviqVerifiedBadge(size: 17),
        ],
      ],
    );
  }
}

class _SocialStatsRow extends StatelessWidget {
  const _SocialStatsRow({required this.profile});

  final CiviqProfile? profile;

  @override
  Widget build(BuildContext context) {
    final id = profile?.id;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialStatButton(
          label: 'Following',
          count: profile?.followingCount ?? 0,
          onTap: id == null
              ? null
              : () => _openSocialList(context, id, SocialListType.following),
        ),
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AppColors.border,
        ),
        _SocialStatButton(
          label: 'Followers',
          count: profile?.followersCount ?? 0,
          onTap: id == null
              ? null
              : () => _openSocialList(context, id, SocialListType.followers),
        ),
      ],
    );
  }

  void _openSocialList(
    BuildContext context,
    String profileId,
    SocialListType type,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SocialListScreen(profileId: profileId, type: type),
      ),
    );
  }
}

class _SocialStatButton extends StatelessWidget {
  const _SocialStatButton({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.grey)),
          ],
        ),
      ),
    );
  }
}

class _DangerZoneActions extends ConsumerStatefulWidget {
  const _DangerZoneActions();

  @override
  ConsumerState<_DangerZoneActions> createState() => _DangerZoneActionsState();
}

class _DangerZoneActionsState extends ConsumerState<_DangerZoneActions> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: const Icon(Icons.warning_amber_outlined),
          label: const Text('Danger Zone'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerRed),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () async {
              ref.read(currentAuthUserIdProvider.notifier).state = null;
              await ref.read(authRepositoryProvider).signOut();
              _clearUserScopedProviders(ref);
              if (context.mounted) context.go('/intro');
            },
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            label: 'Delete account',
            danger: true,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your account will be scheduled for deletion with a 30-day recovery period. Confirm your password to continue.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export is coming soon')),
              );
            },
            child: const Text('Export data first'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      if (!mounted) return;
      await ref.read(accountRepositoryProvider).requestAccountDeletion(user.id);
      if (!mounted) return;
      await ref
          .read(securityRepositoryProvider)
          .logSecurityEvent('account_deletion_requested');
      if (!mounted) return;
      _clearUserScopedProviders(ref);
      ref.read(currentAuthUserIdProvider.notifier).state = null;
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion requested')),
        );
        context.go('/intro');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $error')),
        );
      }
    }
  }

  void _clearUserScopedProviders(WidgetRef ref) {
    ref.invalidate(currentProfileProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(archivedNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(securityEventsProvider);
    ref.invalidate(trustedDevicesProvider);
    ref.invalidate(exportHistoryProvider);
    ref.invalidate(accountDeletionProvider);
    ref.invalidate(legalHistoryProvider);
  }
}

String? _countyName(int? countyId, List<KenyaCounty> counties) {
  if (countyId == null) return null;
  for (final county in counties) {
    if (county.id == countyId) return county.name;
  }
  return null;
}

String? _subcountyName(
  int? countyId,
  int? subcountyId,
  List<KenyaCounty> counties,
) {
  if (countyId == null || subcountyId == null) return null;
  for (final county in counties) {
    if (county.id != countyId) continue;
    for (final subcounty in county.subcounties) {
      if (subcounty.id == subcountyId) return subcounty.name;
    }
  }
  return null;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.border,
        child: Icon(Icons.person_outline, size: 42),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const CircleAvatar(radius: 48, backgroundColor: AppColors.border),
        errorWidget: (context, url, error) => const CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.border,
          child: Icon(Icons.person_outline, size: 42),
        ),
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_outlined, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CIVIQ Code',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy CIVIQ code',
            onPressed: code == 'Pending code'
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CIVIQ code copied')),
                    );
                  },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.dangerRed,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load profile.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(currentProfileProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, this.route});

  final IconData icon;
  final String label;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: route == null ? null : () => context.push(route!),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.dangerRed,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.dangerRed : AppColors.black;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ShellTab {
  const _ShellTab({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
