import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../auth/data/auth_repository.dart';
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

class _ChatsScreenState extends ConsumerState<ChatsScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  Timer? _searchDebounce;
  RealtimeChannel? _conversationsChannel;
  Timer? _presenceTimer;
  String? _channelUserId;
  String? _startupError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapForUser());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 55),
      (_) => _updatePresenceSafely(isOnline: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _presenceTimer?.cancel();
    final channel = _conversationsChannel;
    if (channel != null) {
      ref.read(chatRepositoryProvider).removeChannel(channel);
    }
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentAuthUserIdProvider, (previous, next) {
      if (previous == next) return;
      _bootstrapForUser();
    });

    final conversations = ref.watch(conversationsProvider);
    final currentUserId =
        ref.watch(currentAuthUserIdProvider) ??
        ref.watch(chatRepositoryProvider).currentUserId;
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
          if (_startupError != null)
            _ChatStartupNotice(
              message: _startupError!,
              onRetry: _bootstrapForUser,
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
                            currentUserId: currentUserId,
                            currentUsername: currentProfile?.username,
                            currentAvatarUrl: currentProfile?.avatarUrl,
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresenceSafely(isOnline: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updatePresenceSafely(isOnline: false);
    }
  }

  void _subscribe() {
    final userId =
        ref.read(currentAuthUserIdProvider) ??
        ref.read(chatRepositoryProvider).currentUserId;
    if (userId == null) {
      _removeConversationChannel();
      _channelUserId = null;
      return;
    }
    if (_channelUserId == userId && _conversationsChannel != null) return;
    _removeConversationChannel();
    _channelUserId = userId;
    _conversationsChannel = ref
        .read(chatRepositoryProvider)
        .conversationsChannel(
          onChange: () => ref.invalidate(conversationsProvider),
        );
  }

  void _removeConversationChannel() {
    final channel = _conversationsChannel;
    if (channel != null) {
      ref.read(chatRepositoryProvider).removeChannel(channel);
    }
    _conversationsChannel = null;
  }

  Future<void> _bootstrapForUser() async {
    final userId =
        ref.read(currentAuthUserIdProvider) ??
        ref.read(chatRepositoryProvider).currentUserId;
    if (ref.read(currentAuthUserIdProvider) == null && userId != null) {
      ref.read(currentAuthUserIdProvider.notifier).state = userId;
    }
    _subscribe();
    if (userId == null) {
      if (mounted) setState(() => _startupError = null);
      return;
    }
    try {
      await ref.read(chatRepositoryProvider).ensureCurrentProfile();
      await ref.read(chatRepositoryProvider).ensureSelfConversation();
      await ref.read(chatRepositoryProvider).updatePresence(isOnline: true);
      if (!mounted) return;
      setState(() => _startupError = null);
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError =
            'Chat setup needs a retry. If this account is new, finish profile setup first.';
      });
    }
  }

  Future<void> _updatePresenceSafely({required bool isOnline}) async {
    final userId =
        ref.read(currentAuthUserIdProvider) ??
        ref.read(chatRepositoryProvider).currentUserId;
    if (userId == null) return;
    try {
      await ref.read(chatRepositoryProvider).updatePresence(isOnline: isOnline);
    } catch (_) {
      // Presence should never blank or block the chat UI.
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  List<ChatConversation> _filtered(List<ChatConversation> items) {
    final filtered = switch (_filter) {
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
    filtered.sort((a, b) {
      if (_filter == _ChatFilter.all) {
        if (a.type == ConversationType.self) return -1;
        if (b.type == ConversationType.self) return 1;
      }
      final aTime = a.lastMessageCreatedAt ?? a.updatedAt;
      final bTime = b.lastMessageCreatedAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    return filtered;
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
    required this.currentUserId,
    required this.currentUsername,
    required this.currentAvatarUrl,
  });

  final ChatConversation conversation;
  final String? currentUserId;
  final String? currentUsername;
  final String? currentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final title = conversation.displayTitle(currentUsername);
    final subtitle = conversation.displaySubtitle(currentUsername);
    final selfChat = conversation.type == ConversationType.self;
    final mineLast =
        conversation.lastMessageSenderId != null &&
        conversation.lastMessageSenderId == currentUserId;
    final icon = selfChat
        ? Icons.bookmark_outline
        : conversation.type == ConversationType.group
        ? Icons.groups_outlined
        : Icons.person_outline;
    final avatarUrl = selfChat ? currentAvatarUrl : conversation.peerAvatarUrl;

    return ListTile(
      minVerticalPadding: 12,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          ChatAvatar(imageUrl: avatarUrl, icon: icon),
          if (selfChat)
            const Positioned(right: -2, bottom: -2, child: _PinnedBadge())
          else if (conversation.peerIsOnline)
            const Positioned(right: 1, bottom: 1, child: _OnlineDot(size: 11)),
        ],
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
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
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              mineLast ? 'You: $subtitle' : subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grey),
            ),
          ),
          if (mineLast) ...[
            const SizedBox(width: 4),
            _ConversationDeliveryIcon(
              state: conversation.lastMessageDeliveryStateFor(currentUserId),
            ),
          ],
        ],
      ),
      trailing: selfChat
          ? const Icon(Icons.push_pin, color: AppColors.primaryGreen, size: 20)
          : conversation.unreadCount > 0
          ? _UnreadBubble(count: conversation.unreadCount)
          : const Icon(Icons.chevron_right, color: AppColors.grey),
      onTap: () =>
          context.push('/chats/${conversation.id}', extra: conversation),
    );
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        border: Border.all(color: AppColors.white, width: 2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.push_pin, color: AppColors.white, size: 10),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.success,
        border: Border.all(color: AppColors.white, width: 2),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ChatStartupNotice extends StatelessWidget {
  const _ChatStartupNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
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

class _ConversationDeliveryIcon extends StatelessWidget {
  const _ConversationDeliveryIcon({required this.state});

  final MessageDeliveryState state;
  static const _seenBlue = Color(0xFF34B7F1);

  @override
  Widget build(BuildContext context) {
    final read = state == MessageDeliveryState.read;
    return Icon(
      state == MessageDeliveryState.sent ? Icons.check : Icons.done_all,
      size: 19,
      color: read ? _seenBlue : AppColors.grey,
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
