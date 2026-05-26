# Chat Interactions and Reply Notifications

Implemented: May 26, 2026

## Message Actions

Long pressing a message opens a centered action dialog.

Own messages:
- Reply
- Edit
- Star
- Delete for me
- Delete for everyone

Other users' messages:
- Reply
- Star
- Delete for me
- Report spam

Editing is limited to the first 5 minutes after the message is sent. After that window the UI shows "Edit expired" and the database function also rejects the edit.

Swipe right on any visible message starts a reply without deleting or moving the message.

## Reply Behavior

Replies store `reply_to_message_id` on `public.messages`.

The message list RPC returns reply preview fields:
- `reply_to_content`
- `reply_to_sender_id`
- `reply_to_sender_username`

Direct chats show the reply context inline only.

Group chats also create a notification for the owner of the replied-to message:

`{username} replied to your message`

Self replies do not notify the sender.

## Delete and Report Behavior

Delete for me:
- Calls `delete_message_for_me(message_id)`.
- Stores a per-user hidden row in `public.message_hidden_users`.
- The message disappears only for that user.

Delete for everyone:
- Calls `delete_message_for_everyone(message_id)`.
- Soft deletes the message with `messages.deleted_at`.
- Other users see a "Message deleted" placeholder.

Report spam:
- Calls `report_message_spam(message_id, 'spam')`.
- Stores one report per user/message in `public.message_reports`.

## Chat List Actions

Long pressing a chat list item opens a centered action dialog.

Available actions:
- Archive or unarchive
- Delete chat with `{username/group name}`

Delete chat is per-user. It sets `conversation_participants.deleted_at` and removes the conversation from that user's chat list without deleting the other participant's copy.

## Comment Notifications

Social posts:
- New top-level comment: `{username} commented on your post`
- Reply to comment: `{username} replied to your comment`

Projects:
- New top-level comment: `{username} commented on your project`
- Reply to comment: `{username} replied to your comment`

These are database triggers, so notifications fire from any client path that inserts comments.

## Notification Badges

Unread badges now show numbers instead of a plain red dot.

Display rule:
- `1` through `9`
- `9+` for anything above 9

This applies to the app shell notification indicator and chat unread bubbles.

## Later Enforcement

When moderation is ready, enforce stricter behavior in these places:
- Review `public.message_reports` and comment report tables for spam tooling.
- Add admin review queues and automatic thresholds.
- Add irreversible conversation deletion only for legal/admin flows.
- Tighten edit/delete windows if abuse appears.
- Add push notification delivery on top of the existing in-app notification rows.
