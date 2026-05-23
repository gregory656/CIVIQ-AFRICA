import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';
import '../widgets/chat_avatar.dart';

enum _ChatFilter {
  all('All'),
  unread('Unread'),
  favorites('Favorites'),
  groups('Groups');

  const _ChatFilter(this.label);
  final String label;
}

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _searchController = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatRepositoryProvider).ensureSelfConversation(),
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final currentProfile = ref
        .watch(currentProfileProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);

    return SafeArea(
      child: Column(
        children: [
          _ChatsTopBar(
            searchController: _searchController,
            onMenuSelected: (value) => _handleMenu(context, value),
          ),
          _FilterBar(
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          Expanded(
            child: _searchQuery.trim().length >= 2
                ? _SearchResults(query: _searchQuery)
                : conversations.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _ChatError(
                      message: 'Could not load chats.',
                      detail: error.toString(),
                      onRetry: () => ref.invalidate(conversationsProvider),
                    ),
                    data: (items) {
                      final filtered = _filtered(items);
                      if (filtered.isEmpty) {
                        return _EmptyChats(filter: _filter);
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(conversationsProvider),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) => _ConversationTile(
                            conversation: filtered[index],
                            currentUsername: currentProfile?.username,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<ChatConversation> _filtered(List<ChatConversation> items) {
    return switch (_filter) {
      _ChatFilter.all => items.where((item) => !item.isArchived).toList(),
      _ChatFilter.unread =>
        items
            .where((item) => !item.isArchived && item.unreadCount > 0)
            .toList(),
      _ChatFilter.favorites =>
        items.where((item) => !item.isArchived && item.isFavorite).toList(),
      _ChatFilter.groups =>
        items
            .where(
              (item) => !item.isArchived && item.type == ConversationType.group,
            )
            .toList(),
    };
  }

  void _handleMenu(BuildContext context, String value) {
    switch (value) {
      case 'new_group':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Small private groups are next.')),
        );
      case 'archived':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archived chats view is coming soon.')),
        );
      case 'starred':
        setState(() => _filter = _ChatFilter.favorites);
      case 'privacy':
        context.push('/settings/privacy');
      case 'settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat settings are coming soon.')),
        );
    }
  }
}

class _ChatsTopBar extends StatelessWidget {
  const _ChatsTopBar({
    required this.searchController,
    required this.onMenuSelected,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CIVIQ Africa',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Chat menu',
                onSelected: onMenuSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'new_group', child: Text('New Group')),
                  PopupMenuItem(
                    value: 'archived',
                    child: Text('Archived Chats'),
                  ),
                  PopupMenuItem(
                    value: 'starred',
                    child: Text('Starred Messages'),
                  ),
                  PopupMenuItem(
                    value: 'privacy',
                    child: Text('Privacy Shortcuts'),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text('Chat Settings'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search CIVIQ code/messages...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close),
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _ChatFilter value;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _ChatFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _ChatFilter.values[index];
          final selected = value == filter;
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            onSelected: (_) => onChanged(filter),
            showCheckmark: false,
            selectedColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: selected ? AppColors.primaryGreen : AppColors.black,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selected ? AppColors.primaryGreen : AppColors.border,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUsername,
  });

  final ChatConversation conversation;
  final String? currentUsername;

  @override
  Widget build(BuildContext context) {
    final title = conversation.displayTitle(currentUsername);
    final subtitle = conversation.displaySubtitle(currentUsername);
    final icon = conversation.type == ConversationType.self
        ? Icons.bookmark_outline
        : conversation.type == ConversationType.group
        ? Icons.groups_outlined
        : Icons.person_outline;

    return ListTile(
      minVerticalPadding: 12,
      leading: ChatAvatar(imageUrl: conversation.peerAvatarUrl, icon: icon),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (conversation.peerIsVerified) ...[
            const SizedBox(width: 4),
            const CiviqVerifiedBadge(size: 15),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.grey),
      ),
      trailing: conversation.unreadCount > 0
          ? _UnreadBubble(count: conversation.unreadCount)
          : const Icon(Icons.chevron_right, color: AppColors.grey),
      onTap: () =>
          context.push('/chats/${conversation.id}', extra: conversation),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(chatSearchProvider(query));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ChatError(
        message: 'Could not search chats.',
        detail: error.toString(),
        onRetry: () => ref.invalidate(chatSearchProvider(query)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No CIVIQ profiles found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final result = items[index];
            return ListTile(
              leading: ChatAvatar(imageUrl: result.avatarUrl),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      result.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (result.isVerified) ...[
                    const SizedBox(width: 4),
                    const CiviqVerifiedBadge(size: 15),
                  ],
                ],
              ),
              subtitle: Text(result.civiqCode ?? result.roleLabel ?? ''),
              onTap: () async {
                final router = GoRouter.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final conversationId = await ref
                      .read(chatRepositoryProvider)
                      .createDirectConversation(result.id);
                  if (context.mounted) {
                    router.push('/chats/$conversationId');
                  }
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not open chat: $error')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _UnreadBubble extends StatelessWidget {
  const _UnreadBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.filter});

  final _ChatFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = filter == _ChatFilter.all
        ? 'Search for a CIVIQ code or username to start a chat.'
        : 'No ${filter.label.toLowerCase()} chats yet.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grey),
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.dangerRed),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
