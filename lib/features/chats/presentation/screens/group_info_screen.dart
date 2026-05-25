import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';
import '../widgets/chat_avatar.dart';

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  final String conversationId;
  final ChatConversation? initialConversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation =
        ref
            .watch(conversationsProvider)
            .maybeWhen(
              data: (items) {
                for (final item in items) {
                  if (item.id == conversationId) return item;
                }
                return null;
              },
              orElse: () => null,
            ) ??
        initialConversation;
    final members = ref.watch(groupMembersProvider(conversationId));
    final role = conversation?.currentUserRole ?? 'member';
    final canAdmin = role == 'owner' || role == 'admin';
    final isOwner = role == 'owner';

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 20),
          Center(
            child: ChatAvatar(
              imageUrl: conversation?.groupPhotoUrl,
              radius: 48,
              icon: Icons.groups_outlined,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                conversation?.displayTitle(null) ?? 'Group chat',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (conversation?.groupDescription?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                conversation!.groupDescription!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Center(
            child: Text(
              '${conversation?.groupMemberCount ?? 0} members',
              style: const TextStyle(
                color: AppColors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (canAdmin)
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Add Members'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AddMembersSheet(
                  conversationId: conversationId,
                  existingIds: members.maybeWhen(
                    data: (items) => items.map((item) => item.userId).toSet(),
                    orElse: () => const <String>{},
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          members.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load members: $error'),
            ),
            data: (items) => Column(
              children: items
                  .map(
                    (member) => _MemberTile(
                      conversationId: conversationId,
                      member: member,
                      currentUserRole: role,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.dangerRed),
            title: const Text('Leave Group'),
            textColor: AppColors.dangerRed,
            onTap: () => _leaveGroup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report Group'),
            onTap: () => _reportGroup(context, ref),
          ),
          if (isOwner)
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.dangerRed,
              ),
              title: const Text('Delete Group'),
              textColor: AppColors.dangerRed,
              onTap: () => _deleteGroup(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(chatRepositoryProvider).leaveGroup(conversationId);
      ref.invalidate(conversationsProvider);
      if (context.mounted) router.go('/home');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not leave: $error')),
      );
    }
  }

  Future<void> _reportGroup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatRepositoryProvider).reportGroup(conversationId);
      messenger.showSnackBar(const SnackBar(content: Text('Group reported.')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not report group: $error')),
      );
    }
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(chatRepositoryProvider).deleteGroup(conversationId);
      ref.invalidate(conversationsProvider);
      if (context.mounted) router.go('/home');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete group: $error')),
      );
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.conversationId,
    required this.member,
    required this.currentUserRole,
  });

  final String conversationId;
  final GroupMember member;
  final String currentUserRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRemove =
        currentUserRole == 'owner' ||
        (currentUserRole == 'admin' && member.memberRole == 'member');
    return ListTile(
      leading: ChatAvatar(imageUrl: member.avatarUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (member.isVerified) ...[
            const SizedBox(width: 4),
            const CiviqVerifiedBadge(size: 15),
          ],
        ],
      ),
      subtitle: Text(member.roleLabel ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RolePill(role: member.memberRole),
          if (canRemove && member.memberRole != 'owner') ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove member',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(chatRepositoryProvider)
                      .removeGroupMember(
                        conversationId: conversationId,
                        userId: member.userId,
                      );
                  ref.invalidate(groupMembersProvider(conversationId));
                  ref.invalidate(conversationsProvider);
                  messenger.showSnackBar(
                    SnackBar(content: Text('${member.displayName} removed.')),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not remove member: $error')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({
    required this.conversationId,
    required this.existingIds,
  });

  final String conversationId;
  final Set<String> existingIds;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final _controller = TextEditingController();
  final Map<String, ChatProfileResult> _selected = {};
  Timer? _debounce;
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(chatSearchProvider(_query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              TextField(
                controller: _controller,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _query = value.trim());
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _query.length < 2
                    ? const Center(child: Text('Type at least 2 characters.'))
                    : results.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(child: Text('$error')),
                        data: (items) =>
                            ListView(children: items.map(_resultTile).toList()),
                      ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _confirm,
                child: Text(
                  _saving ? 'Adding...' : 'Add ${_selected.length} Members',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultTile(ChatProfileResult item) {
    final alreadyMember = widget.existingIds.contains(item.id);
    final selected = _selected.containsKey(item.id);
    return CheckboxListTile(
      value: selected || alreadyMember,
      onChanged: alreadyMember
          ? null
          : (_) {
              setState(() {
                if (selected) {
                  _selected.remove(item.id);
                } else {
                  _selected[item.id] = item;
                }
              });
            },
      secondary: ChatAvatar(imageUrl: item.avatarUrl),
      title: Text(item.displayName),
      subtitle: Text(alreadyMember ? 'Already in group' : item.civiqCode ?? ''),
    );
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ref
          .read(chatRepositoryProvider)
          .addGroupMembers(
            conversationId: widget.conversationId,
            memberIds: _selected.keys.toList(growable: false),
          );
      ref.invalidate(groupMembersProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$count member${count == 1 ? '' : 's'} added.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    if (role == 'member') return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          role,
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
