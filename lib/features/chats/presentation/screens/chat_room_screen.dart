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
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _typingChannel;
  Set<String> _typingUserIds = const {};
  final List<_PendingChatMessage> _pendingMessages = [];
  Timer? _typingThrottle;
  Timer? _pendingRetryTimer;
  bool _sending = false;
  ChatMessage? _replyToMessage;
  ChatMessage? _editingMessage;

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
    _pendingRetryTimer?.cancel();
    final repository = ref.read(chatRepositoryProvider);
    final messagesChannel = _messagesChannel;
    final typingChannel = _typingChannel;
    if (messagesChannel != null) repository.removeChannel(messagesChannel);
    if (typingChannel != null) repository.removeChannel(typingChannel);
    _messageFocusNode.dispose();
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
    final selfChat = headerConversation?.type == ConversationType.self;
    final groupChat = headerConversation?.type == ConversationType.group;
    final peerOnline = headerConversation?.peerIsOnline ?? false;
    final subtitle = _typingUserIds.isNotEmpty
        ? 'typing...'
        : headerConversation?.type == ConversationType.self
        ? '${currentProfile?.handle ?? 'You'} (You)'
        : headerConversation?.type == ConversationType.direct
        ? [
            headerConversation?.peerHandle ?? '',
            _statusLabel(headerConversation),
          ].where((item) => item.isNotEmpty).join(' | ')
        : _statusLabel(headerConversation);
    final avatarUrl = selfChat
        ? currentProfile?.avatarUrl
        : groupChat
        ? headerConversation?.groupPhotoUrl
        : headerConversation?.peerAvatarUrl;

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                ChatAvatar(
                  imageUrl: avatarUrl,
                  radius: 18,
                  icon: headerConversation?.type == ConversationType.group
                      ? Icons.groups_outlined
                      : selfChat
                      ? Icons.bookmark_outline
                      : Icons.person_outline,
                ),
                if (selfChat)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: _StatusBadge(icon: Icons.push_pin),
                  )
                else if (peerOnline)
                  const Positioned(
                    right: -1,
                    bottom: -1,
                    child: _OnlineDot(size: 10),
                  ),
              ],
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
                      if (headerConversation?.type != ConversationType.group &&
                          headerConversation?.peerIsVerified == true) ...[
                        const SizedBox(width: 4),
                        CiviqVerifiedBadge(
                          size: 14,
                          role: headerConversation?.peerRole,
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (_typingUserIds.isNotEmpty) ...[
                        const _OnlineDot(size: 8),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _typingUserIds.isNotEmpty
                                ? AppColors.success
                                : AppColors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
              PopupMenuItem(value: 'profile', child: Text('View Info')),
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
      body: ColoredBox(
        color: const Color(0xFFF2F5F3),
        child: Column(
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
                  final visibleItems = _visibleMessages(items, currentUserId);
                  _pruneConfirmedPending(items, currentUserId);
                  if (visibleItems.isEmpty) {
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
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return switch (item) {
                        ChatMessage message => _MessageBubble(
                          message: message,
                          currentUserId: currentUserId,
                          showSender: groupChat,
                          onReply: () => _startReply(message),
                          onLongPress: () => _showMessageActions(
                            message,
                            groupChat: groupChat,
                          ),
                        ),
                        _PendingChatMessage pending => _PendingMessageBubble(
                          message: pending,
                        ),
                        _ => const SizedBox.shrink(),
                      };
                    },
                  );
                },
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              focusNode: _messageFocusNode,
              sending: _sending,
              onChanged: (_) => _sendTyping(),
              onSend: _sendMessage,
              onFutureAction: _comingSoon,
              replyTo: _replyToMessage,
              editingMessage: _editingMessage,
              onCancelContext: _clearComposerContext,
            ),
          ],
        ),
      ),
    );
  }

  List<Object> _visibleMessages(
    List<ChatMessage> messages,
    String? currentUserId,
  ) {
    if (_pendingMessages.isEmpty) return messages;
    final pending = _pendingMessages.where((item) {
      return !messages.any((message) {
        final sameSender = message.senderId == currentUserId;
        final sameContent = message.content == item.content;
        final closeTime =
            message.createdAt.difference(item.createdAt).inMinutes.abs() < 2;
        return sameSender && sameContent && closeTime;
      });
    });
    return [...messages, ...pending];
  }

  void _pruneConfirmedPending(
    List<ChatMessage> messages,
    String? currentUserId,
  ) {
    if (_pendingMessages.isEmpty) return;
    final confirmedIds = _pendingMessages
        .where(
          (pending) =>
              _hasMatchingServerMessage(pending, messages, currentUserId),
        )
        .map((pending) => pending.id)
        .toSet();
    if (confirmedIds.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((item) => confirmedIds.contains(item.id));
      });
    });
  }

  bool _hasMatchingServerMessage(
    _PendingChatMessage pending,
    List<ChatMessage> messages,
    String? currentUserId,
  ) {
    return messages.any((message) {
      final sameSender = message.senderId == currentUserId;
      final sameContent = message.content == pending.content;
      final closeTime =
          message.createdAt.difference(pending.createdAt).inMinutes.abs() < 2;
      return sameSender && sameContent && closeTime;
    });
  }

  String _statusLabel(ChatConversation? conversation) {
    if (conversation == null) return '';
    if (conversation.type == ConversationType.group) {
      final summary = conversation.groupMemberSummary;
      if (summary?.isNotEmpty == true) return summary!;
      if (conversation.groupMemberCount > 0) {
        return '${conversation.groupMemberCount} members';
      }
      return 'Group chat';
    }
    if (!conversation.peerShowOnlineStatus) return 'Last seen hidden';
    if (conversation.peerIsOnline) return 'Online';
    final lastSeen = conversation.peerLastSeen;
    if (lastSeen == null) return 'Offline';
    return 'Last seen ${_relativeLastSeen(lastSeen)}';
  }

  String _relativeLastSeen(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'yesterday';
    return '${difference.inDays}d ago';
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
    final editing = _editingMessage;
    if (editing != null) {
      setState(() => _sending = true);
      try {
        await ref
            .read(chatRepositoryProvider)
            .editMessage(messageId: editing.id, content: text);
        _messageController.clear();
        _clearComposerContext();
        ref.invalidate(chatMessagesProvider(widget.conversationId));
        ref.invalidate(conversationsProvider);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not edit message: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }
    final pending = _PendingChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: text,
      createdAt: DateTime.now(),
      replyToMessageId: _replyToMessage?.id,
      replyToContent: _replyToMessage?.content,
      replyToSenderUsername: _replyToMessage?.senderUsername,
    );
    setState(() {
      _sending = true;
      _pendingMessages.add(pending);
    });
    _messageController.clear();
    _clearComposerContext();
    await _sendPendingMessage(pending);
  }

  Future<void> _sendPendingMessage(
    _PendingChatMessage pending, {
    bool showError = true,
  }) async {
    if (!_pendingMessages.any((item) => item.id == pending.id)) return;
    if (mounted) setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: widget.conversationId,
            content: pending.content,
            replyToMessageId: pending.replyToMessageId,
          );
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      _schedulePendingRetry();
      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message is queued and will retry: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _schedulePendingRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted || _pendingMessages.isEmpty || _sending) return;
      final next = _pendingMessages.first;
      await _sendPendingMessage(next, showError: false);
      if (mounted && _pendingMessages.isNotEmpty) _schedulePendingRetry();
    });
  }

  void _sendTyping() {
    _typingThrottle ??= Timer(const Duration(milliseconds: 900), () {
      _typingThrottle = null;
    });
    if (_typingThrottle?.isActive == true) {
      ref.read(chatRepositoryProvider).sendTyping(widget.conversationId);
    }
  }

  void _startReply(ChatMessage message) {
    if (message.deletedAt != null) return;
    setState(() {
      _replyToMessage = message;
      _editingMessage = null;
    });
    _messageFocusNode.requestFocus();
  }

  void _startEdit(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyToMessage = null;
      _messageController.text = message.content ?? '';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
    _messageFocusNode.requestFocus();
  }

  void _clearComposerContext() {
    if (!mounted) return;
    setState(() {
      _replyToMessage = null;
      _editingMessage = null;
    });
  }

  Future<void> _showMessageActions(
    ChatMessage message, {
    required bool groupChat,
  }) async {
    if (message.deletedAt != null) return;
    final currentUserId = ref.read(currentAuthUserIdProvider);
    final mine = message.senderId == currentUserId;
    final canEdit =
        mine &&
        DateTime.now().difference(message.createdAt.toLocal()).inMinutes < 5;
    final action = await _showCenteredActionSheet(
      context,
      title: mine ? 'Your message' : _senderLabel(message),
      actions: [
        _CenteredAction('reply', Icons.reply, 'Reply'),
        if (mine && canEdit)
          _CenteredAction('edit', Icons.edit_outlined, 'Edit'),
        if (mine && !canEdit)
          _CenteredAction(
            'edit_expired',
            Icons.lock_clock_outlined,
            'Edit expired',
          ),
        _CenteredAction('favorite', Icons.star_border, 'Star'),
        _CenteredAction(
          'delete_me',
          Icons.delete_sweep_outlined,
          'Delete for me',
        ),
        if (mine)
          _CenteredAction(
            'delete_all',
            Icons.delete_outline,
            groupChat ? 'Delete for everyone' : 'Delete for everyone',
            danger: true,
          ),
        if (!mine)
          _CenteredAction(
            'report',
            Icons.report_gmailerrorred_outlined,
            'Report spam',
            danger: true,
          ),
      ],
    );
    if (action == null) return;
    final repository = ref.read(chatRepositoryProvider);
    try {
      switch (action) {
        case 'reply':
          _startReply(message);
          break;
        case 'edit':
          _startEdit(message);
          break;
        case 'favorite':
          await repository.toggleFavoriteMessage(message.id);
          break;
        case 'delete_me':
          await repository.deleteMessageForMe(message.id);
          break;
        case 'delete_all':
          await repository.deleteMessageForEveryone(message.id);
          break;
        case 'report':
          await repository.reportMessageSpam(message.id);
          break;
        case 'edit_expired':
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Messages can only be edited for 5 minutes.'),
              ),
            );
          }
          break;
      }
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
      }
    }
  }

  String _senderLabel(ChatMessage message) {
    final username = message.senderUsername;
    return username?.isNotEmpty == true ? '@$username' : 'Message';
  }

  void _handleRoomMenu(String value) {
    final conversation = widget.initialConversation ?? _conversationFromList();
    switch (value) {
      case 'profile':
        if (conversation?.type == ConversationType.group) {
          context.push(
            '/chats/${widget.conversationId}/info',
            extra: conversation,
          );
          return;
        }
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
    required this.showSender,
    required this.onReply,
    required this.onLongPress,
  });

  final ChatMessage message;
  final String? currentUserId;
  final bool showSender;
  final VoidCallback onReply;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == currentUserId;
    final delivery = message.deliveryStateFor(currentUserId);
    final bubbleColor = mine ? AppColors.primaryGreen : AppColors.white;
    final textColor = mine ? AppColors.white : AppColors.black;
    final metaColor = mine
        ? AppColors.white.withValues(alpha: 0.78)
        : AppColors.grey;
    final senderName = message.senderUsername;

    return Dismissible(
      key: ValueKey('message-${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onReply();
        return false;
      },
      background: const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 18),
          child: Icon(Icons.reply, color: AppColors.primaryGreen),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (showSender && !mine) ...[
              ChatAvatar(imageUrl: message.senderAvatarUrl, radius: 14),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: _bubbleRadius(mine),
                  onLongPress: onLongPress,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: _bubbleRadius(mine),
                      border: mine
                          ? null
                          : Border.all(
                              color: AppColors.border.withValues(alpha: 0.8),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.05),
                          blurRadius: 7,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 9, 10, 7),
                    child: Column(
                      crossAxisAlignment: mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showSender &&
                            !mine &&
                            senderName?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '@$senderName',
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (message.replyToMessageId != null)
                          _ReplyPreview(
                            senderUsername: message.replyToSenderUsername,
                            content: message.replyToContent,
                            mine: mine,
                          ),
                        Text(
                          message.deletedAt == null
                              ? message.content ?? ''
                              : 'Message deleted',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isFavorite)
                              Icon(
                                Icons.star,
                                size: 13,
                                color: mine
                                    ? AppColors.white.withValues(alpha: 0.9)
                                    : AppColors.warning,
                              ),
                            if (message.isFavorite) const SizedBox(width: 4),
                            if (message.isEdited) ...[
                              Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: metaColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _time(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: metaColor,
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
          ],
        ),
      ),
    );
  }

  BorderRadius _bubbleRadius(bool mine) {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 3),
      bottomRight: Radius.circular(mine ? 3 : 16),
    );
  }

  String _time(DateTime value) {
    return _formatTime(value);
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _PendingChatMessage {
  const _PendingChatMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderUsername,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderUsername;
}

class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({required this.message});

  final _PendingChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.05),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 10, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyToMessageId != null)
                      _ReplyPreview(
                        senderUsername: message.replyToSenderUsername,
                        content: message.replyToContent,
                        mine: true,
                      ),
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.white.withValues(alpha: 0.82),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.senderUsername,
    required this.content,
    required this.mine,
  });

  final String? senderUsername;
  final String? content;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? AppColors.white : AppColors.primaryGreen;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.black.withValues(alpha: 0.12)
            : AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: fg, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderUsername?.isNotEmpty == true
                ? '@$senderUsername'
                : 'Replied message',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content?.isNotEmpty == true ? content! : 'Message',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mine
                  ? AppColors.white.withValues(alpha: 0.86)
                  : AppColors.black,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onFutureAction,
    required this.replyTo,
    required this.editingMessage,
    required this.onCancelContext,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onFutureAction;
  final ChatMessage? replyTo;
  final ChatMessage? editingMessage;
  final VoidCallback onCancelContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTo != null || editingMessage != null)
              _ComposerContextBar(
                message: replyTo ?? editingMessage!,
                editing: editingMessage != null,
                onCancel: onCancelContext,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'More message tools',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFutureAction('Message tools'),
                    icon: const Icon(Icons.add),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Voice note',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFutureAction('Voice notes'),
                    icon: const Icon(Icons.mic_none),
                  ),
                  IconButton(
                    tooltip: 'Attach',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFutureAction('Attachments'),
                    icon: const Icon(Icons.attach_file),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
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
          ],
        ),
      ),
    );
  }
}

class _ComposerContextBar extends StatelessWidget {
  const _ComposerContextBar({
    required this.message,
    required this.editing,
    required this.onCancel,
  });

  final ChatMessage message;
  final bool editing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: AppColors.background,
      child: Row(
        children: [
          Icon(
            editing ? Icons.edit_outlined : Icons.reply,
            size: 18,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              editing
                  ? 'Editing message'
                  : 'Replying to ${message.senderUsername?.isNotEmpty == true ? '@${message.senderUsername}' : 'message'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        border: Border.all(color: AppColors.white, width: 2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.white, size: 9),
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
        border: Border.all(color: AppColors.white, width: 1.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.state});

  final MessageDeliveryState state;
  static const _seenBlue = Color(0xFF34B7F1);

  @override
  Widget build(BuildContext context) {
    final read = state == MessageDeliveryState.read;
    return Icon(
      state == MessageDeliveryState.sent ? Icons.check : Icons.done_all,
      size: 15,
      color: read ? _seenBlue : AppColors.white.withValues(alpha: 0.82),
    );
  }
}

class _CenteredAction {
  const _CenteredAction(
    this.value,
    this.icon,
    this.label, {
    this.danger = false,
  });

  final String value;
  final IconData icon;
  final String label;
  final bool danger;
}

Future<String?> _showCenteredActionSheet(
  BuildContext context, {
  required String title,
  required List<_CenteredAction> actions,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppColors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Material(
              color: AppColors.white,
              elevation: 10,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    for (final action in actions)
                      ListTile(
                        leading: Icon(
                          action.icon,
                          color: action.danger
                              ? AppColors.dangerRed
                              : AppColors.black,
                        ),
                        title: Text(
                          action.label,
                          style: TextStyle(
                            color: action.danger
                                ? AppColors.dangerRed
                                : AppColors.black,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(dialogContext).pop(action.value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
