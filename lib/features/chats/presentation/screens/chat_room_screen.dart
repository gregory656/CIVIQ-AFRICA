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

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  final String conversationId;
  final ChatConversation? initialConversation;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _typingChannel;
  Set<String> _typingUserIds = const {};
  Timer? _typingThrottle;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribe();
      _markRead();
    });
  }

  @override
  void dispose() {
    _typingThrottle?.cancel();
    final repository = ref.read(chatRepositoryProvider);
    final messagesChannel = _messagesChannel;
    final typingChannel = _typingChannel;
    if (messagesChannel != null) repository.removeChannel(messagesChannel);
    if (typingChannel != null) repository.removeChannel(typingChannel);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribe() {
    final repository = ref.read(chatRepositoryProvider);
    _messagesChannel = repository.messagesChannel(
      widget.conversationId,
      onChange: () {
        ref.invalidate(chatMessagesProvider(widget.conversationId));
        ref.invalidate(conversationsProvider);
        _markRead();
      },
    );

    final currentUserId = ref.read(currentAuthUserIdProvider);
    if (currentUserId != null) {
      _typingChannel = repository.typingChannel(
        conversationId: widget.conversationId,
        userId: currentUserId,
        onTypingChanged: (ids) {
          if (mounted) setState(() => _typingUserIds = ids);
        },
      );
    }
  }

  Future<void> _markRead() async {
    await ref
        .read(chatRepositoryProvider)
        .markConversationRead(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    final currentProfile = ref
        .watch(currentProfileProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final conversation = _conversationFromList();
    final headerConversation = conversation ?? widget.initialConversation;
    final title =
        headerConversation?.displayTitle(currentProfile?.username) ?? 'Chat';
    final subtitle = _typingUserIds.isNotEmpty
        ? 'Typing...'
        : headerConversation?.type == ConversationType.self
        ? (currentProfile?.username?.isNotEmpty == true
              ? '@${currentProfile!.username} (You)'
              : 'You')
        : 'Online status coming soon';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(
              imageUrl: headerConversation?.peerAvatarUrl,
              radius: 18,
              icon: headerConversation?.type == ConversationType.group
                  ? Icons.groups_outlined
                  : Icons.person_outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (headerConversation?.peerIsVerified == true) ...[
                        const SizedBox(width: 4),
                        const CiviqVerifiedBadge(size: 14),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            onPressed: () => _comingSoon('Calls'),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _comingSoon('Video calls'),
            icon: const Icon(Icons.videocam_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Conversation menu',
            onSelected: _handleRoomMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('View Profile')),
              PopupMenuItem(value: 'search', child: Text('Search Messages')),
              PopupMenuItem(
                value: 'disappearing',
                child: Text('Disappearing Messages'),
              ),
              PopupMenuItem(value: 'theme', child: Text('Change Chat Theme')),
              PopupMenuItem(value: 'mute', child: Text('Mute Notifications')),
              PopupMenuItem(value: 'block', child: Text('Block User')),
              PopupMenuItem(value: 'report', child: Text('Report User')),
              PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load messages: $error'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start the conversation.',
                      style: TextStyle(color: AppColors.grey),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: items[index],
                    currentUserId: currentUserId,
                    onFavorite: () => _toggleFavorite(items[index].id),
                  ),
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            sending: _sending,
            onChanged: (_) => _sendTyping(),
            onSend: _sendMessage,
            onFutureAction: _comingSoon,
          ),
        ],
      ),
    );
  }

  ChatConversation? _conversationFromList() {
    final conversations = ref
        .watch(conversationsProvider)
        .maybeWhen(data: (items) => items, orElse: () => null);
    if (conversations == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == widget.conversationId) return conversation;
    }
    return null;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(conversationId: widget.conversationId, content: text);
      _messageController.clear();
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _sendTyping() {
    _typingThrottle ??= Timer(const Duration(milliseconds: 900), () {
      _typingThrottle = null;
    });
    if (_typingThrottle?.isActive == true) {
      ref.read(chatRepositoryProvider).sendTyping(widget.conversationId);
    }
  }

  Future<void> _toggleFavorite(String messageId) async {
    await ref.read(chatRepositoryProvider).toggleFavoriteMessage(messageId);
    ref.invalidate(chatMessagesProvider(widget.conversationId));
  }

  void _handleRoomMenu(String value) {
    final conversation = widget.initialConversation ?? _conversationFromList();
    switch (value) {
      case 'profile':
        final peerId = conversation?.peerId;
        if (peerId != null) context.push('/profile/$peerId');
        return;
      case 'mute':
        ref
            .read(chatRepositoryProvider)
            .updateConversationState(
              conversationId: widget.conversationId,
              isMuted: !(conversation?.isMuted ?? false),
            );
        ref.invalidate(conversationsProvider);
        return;
      case 'block':
      case 'report':
      case 'clear':
      case 'search':
      case 'disappearing':
      case 'theme':
        _comingSoon(_roomMenuLabel(value));
        return;
    }
  }

  String _roomMenuLabel(String value) {
    return switch (value) {
      'block' => 'Blocking',
      'report' => 'Reporting',
      'clear' => 'Clear chat',
      'search' => 'Message search',
      'disappearing' => 'Disappearing messages',
      'theme' => 'Chat themes',
      _ => 'This feature',
    };
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will come after messaging is stable.')),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.currentUserId,
    required this.onFavorite,
  });

  final ChatMessage message;
  final String? currentUserId;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == currentUserId;
    final delivery = message.deliveryStateFor(currentUserId);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onLongPress: onFavorite,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mine ? AppColors.primaryGreen : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: mine ? AppColors.primaryGreen : AppColors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.deletedAt == null
                          ? message.content ?? ''
                          : 'Message deleted',
                      style: TextStyle(
                        color: mine ? AppColors.white : AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isFavorite)
                          Icon(
                            Icons.star,
                            size: 13,
                            color: mine ? AppColors.white : AppColors.warning,
                          ),
                        if (message.isFavorite) const SizedBox(width: 4),
                        Text(
                          _time(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: mine
                                ? AppColors.white.withValues(alpha: 0.82)
                                : AppColors.grey,
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          _DeliveryIcon(state: delivery),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.state});

  final MessageDeliveryState state;

  @override
  Widget build(BuildContext context) {
    final read = state == MessageDeliveryState.read;
    return Icon(
      state == MessageDeliveryState.sent ? Icons.check : Icons.done_all,
      size: 15,
      color: read ? AppColors.success : AppColors.white.withValues(alpha: 0.82),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onFutureAction,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onFutureAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'More message tools',
              onPressed: () => onFutureAction('Message tools'),
              icon: const Icon(Icons.add),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Voice note',
              onPressed: () => onFutureAction('Voice notes'),
              icon: const Icon(Icons.mic_none),
            ),
            IconButton(
              tooltip: 'Attach',
              onPressed: () => onFutureAction('Attachments'),
              icon: const Icon(Icons.attach_file),
            ),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
