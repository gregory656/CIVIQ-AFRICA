enum ConversationType {
  direct,
  group,
  self;

  static ConversationType fromValue(String? value) {
    return ConversationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ConversationType.direct,
    );
  }
}

enum MessageDeliveryState { sent, delivered, read }

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.isMuted,
    required this.isArchived,
    required this.isFavorite,
    required this.unreadCount,
    this.title,
    this.lastMessageId,
    this.lastMessageContent,
    this.lastMessageSenderId,
    this.lastMessageCreatedAt,
    this.lastMessageDeliveredCount = 0,
    this.lastMessageReadCount = 0,
    this.groupPhotoUrl,
    this.groupDescription,
    this.groupMemberCount = 0,
    this.groupMemberSummary,
    this.currentUserRole,
    this.peerId,
    this.peerDisplayName,
    this.peerUsername,
    this.peerAvatarUrl,
    this.peerIsVerified = false,
    this.peerIsOnline = false,
    this.peerLastSeen,
    this.peerShowOnlineStatus = true,
    this.peerRoleLabel,
    this.peerRole = 'user',
  });

  final String id;
  final ConversationType type;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMuted;
  final bool isArchived;
  final bool isFavorite;
  final int unreadCount;
  final String? lastMessageId;
  final String? lastMessageContent;
  final String? lastMessageSenderId;
  final DateTime? lastMessageCreatedAt;
  final int lastMessageDeliveredCount;
  final int lastMessageReadCount;
  final String? groupPhotoUrl;
  final String? groupDescription;
  final int groupMemberCount;
  final String? groupMemberSummary;
  final String? currentUserRole;
  final String? peerId;
  final String? peerDisplayName;
  final String? peerUsername;
  final String? peerAvatarUrl;
  final bool peerIsVerified;
  final bool peerIsOnline;
  final DateTime? peerLastSeen;
  final bool peerShowOnlineStatus;
  final String? peerRoleLabel;
  final String peerRole;

  String displayTitle(String? currentUsername) {
    if (type == ConversationType.self) return 'Saved Messages';
    if (type == ConversationType.group) {
      return title?.isNotEmpty == true ? title! : 'Group chat';
    }
    final name = peerDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = peerUsername;
    return username?.isNotEmpty == true ? '@$username' : 'SIVIQ Member';
  }

  String get peerHandle {
    final value = peerUsername?.trim();
    return value == null || value.isEmpty ? '' : '@$value';
  }

  String displaySubtitle(String? currentUsername) {
    if (type == ConversationType.self) {
      final username = currentUsername;
      return username?.isNotEmpty == true ? '@$username (You)' : 'You';
    }
    if (type == ConversationType.group) {
      final summary = groupMemberSummary;
      if (summary?.isNotEmpty == true) return summary!;
      if (groupMemberCount > 0) return '$groupMemberCount members';
      return 'Group chat';
    }
    return lastMessageContent?.isNotEmpty == true
        ? lastMessageContent!
        : 'No messages yet';
  }

  String displayHandle(String? currentUsername) {
    if (type == ConversationType.self) {
      final username = currentUsername?.trim();
      return username == null || username.isEmpty ? 'You' : '@$username';
    }
    return peerHandle;
  }

  MessageDeliveryState lastMessageDeliveryStateFor(String? currentUserId) {
    if (lastMessageSenderId != currentUserId) return MessageDeliveryState.read;
    if (lastMessageReadCount > 0) return MessageDeliveryState.read;
    if (lastMessageDeliveredCount > 0) return MessageDeliveryState.delivered;
    return MessageDeliveryState.sent;
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      type: ConversationType.fromValue(json['conversation_type'] as String?),
      title: json['title'] as String?,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageId: json['last_message_id'] as String?,
      lastMessageContent: json['last_message_content'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageCreatedAt: json['last_message_created_at'] == null
          ? null
          : _date(json['last_message_created_at']),
      lastMessageDeliveredCount:
          (json['last_message_delivered_count'] as num?)?.toInt() ?? 0,
      lastMessageReadCount:
          (json['last_message_read_count'] as num?)?.toInt() ?? 0,
      groupPhotoUrl: json['group_photo_url'] as String?,
      groupDescription: json['group_description'] as String?,
      groupMemberCount: (json['group_member_count'] as num?)?.toInt() ?? 0,
      groupMemberSummary: json['group_member_summary'] as String?,
      currentUserRole: json['current_user_role'] as String?,
      peerId: json['peer_id'] as String?,
      peerDisplayName: json['peer_display_name'] as String?,
      peerUsername: json['peer_username'] as String?,
      peerAvatarUrl: json['peer_avatar_url'] as String?,
      peerIsVerified: json['peer_is_verified'] as bool? ?? false,
      peerIsOnline: json['peer_is_online'] as bool? ?? false,
      peerLastSeen: json['peer_last_seen'] == null
          ? null
          : _date(json['peer_last_seen']),
      peerShowOnlineStatus: json['peer_show_online_status'] as bool? ?? true,
      peerRoleLabel: json['peer_role_label'] as String?,
      peerRole: json['peer_role'] as String? ?? 'user',
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.isVerified,
    required this.memberRole,
    required this.joinedAt,
    this.displayNameText,
    this.username,
    this.avatarUrl,
    this.roleLabel,
    this.role = 'user',
  });

  final String userId;
  final String? displayNameText;
  final String? username;
  final String? avatarUrl;
  final bool isVerified;
  final String? roleLabel;
  final String role;
  final String memberRole;
  final DateTime joinedAt;

  String get displayName {
    final name = displayNameText?.trim();
    if (name != null && name.isNotEmpty) return name;
    final value = username;
    return value?.isNotEmpty == true ? '@$value' : 'SIVIQ Member';
  }

  String get handle {
    final value = username?.trim();
    return value == null || value.isEmpty ? 'No username' : '@$value';
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] as String,
      displayNameText: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      roleLabel: json['role_label'] as String?,
      role: json['role'] as String? ?? 'user',
      memberRole: json['member_role'] as String? ?? 'member',
      joinedAt: _date(json['joined_at']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    required this.createdAt,
    required this.isEdited,
    required this.isFavorite,
    required this.deliveredCount,
    required this.readCount,
    this.content,
    this.mediaUrl,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderId,
    this.replyToSenderUsername,
    this.editedAt,
    this.deletedAt,
    this.senderUsername,
    this.senderAvatarUrl,
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String messageType;
  final String? content;
  final String? mediaUrl;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderId;
  final String? replyToSenderUsername;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final String? senderUsername;
  final String? senderAvatarUrl;
  final bool isFavorite;
  final int deliveredCount;
  final int readCount;

  MessageDeliveryState deliveryStateFor(String? currentUserId) {
    if (senderId != currentUserId) return MessageDeliveryState.read;
    if (readCount > 0) return MessageDeliveryState.read;
    if (deliveredCount > 0) return MessageDeliveryState.delivered;
    return MessageDeliveryState.sent;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToSenderId: json['reply_to_sender_id'] as String?,
      replyToSenderUsername: json['reply_to_sender_username'] as String?,
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] == null ? null : _date(json['edited_at']),
      createdAt: _date(json['created_at']),
      deletedAt: json['deleted_at'] == null ? null : _date(json['deleted_at']),
      senderUsername: json['sender_username'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
      readCount: (json['read_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatProfileResult {
  const ChatProfileResult({
    required this.id,
    required this.isVerified,
    this.displayNameText,
    this.username,
    this.civiqCode,
    this.avatarUrl,
    this.roleLabel,
    this.role = 'user',
  });

  final String id;
  final String? displayNameText;
  final String? username;
  final String? civiqCode;
  final String? avatarUrl;
  final bool isVerified;
  final String? roleLabel;
  final String role;

  String get displayName {
    final name = displayNameText?.trim();
    if (name != null && name.isNotEmpty) return name;
    final value = username;
    return value?.isNotEmpty == true ? '@$value' : 'SIVIQ Member';
  }

  String get handle {
    final value = username?.trim();
    return value == null || value.isEmpty ? 'No username' : '@$value';
  }

  factory ChatProfileResult.fromJson(Map<String, dynamic> json) {
    return ChatProfileResult(
      id: json['id'] as String,
      displayNameText: json['display_name'] as String?,
      username: json['username'] as String?,
      civiqCode: json['civiq_code'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      roleLabel: json['role_label'] as String?,
      role: json['role'] as String? ?? 'user',
    );
  }
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
