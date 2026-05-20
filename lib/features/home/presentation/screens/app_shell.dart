import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../features/auth/data/auth_repository.dart';

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
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: BrandMark(size: 38),
              ),
              Divider(),
              _DrawerItem(icon: Icons.help_outline, label: 'FAQ'),
              _DrawerItem(
                icon: Icons.groups_outlined,
                label: 'Community Guidelines',
              ),
              _DrawerItem(icon: Icons.gavel_outlined, label: 'Legal'),
              _DrawerItem(
                icon: Icons.assignment_return_outlined,
                label: 'Appeals',
              ),
              _DrawerItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
              ),
              _DrawerItem(icon: Icons.info_outline, label: 'About'),
              _DrawerItem(icon: Icons.mail_outline, label: 'Contact'),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        title: const BrandMark(size: 34),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
              Positioned(
                top: 13,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerRed,
                    shape: BoxShape.circle,
                  ),
                ),
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
                hintText: 'Search projects...',
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
      final user = ref.watch(authRepositoryProvider).currentUser;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: AppColors.border,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            user?.email ?? 'CIVIQ Member',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          const _SettingsTile(icon: Icons.security_outlined, label: 'Security'),
          const _SettingsTile(icon: Icons.lock_outline, label: 'Privacy'),
          const _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
          ),
          const _SettingsTile(
            icon: Icons.download_outlined,
            label: 'Export data',
          ),
          const _SettingsTile(
            icon: Icons.delete_outline,
            label: 'Delete account',
            danger: true,
          ),
        ],
      );
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: () {});
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.dangerRed : AppColors.black;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class _ShellTab {
  const _ShellTab({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
