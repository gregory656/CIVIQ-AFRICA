# Phase 2 - Realtime Messaging And Social Graph

## Priority

Phase 2 stabilizes the foundation before rich media:

1. conversation architecture
2. presence system
3. message delivery states
4. moderation and security
5. media, calls, disappearing messages, and voice notes later

Animations, stickers, and calling should wait until RLS, pagination, receipts, and realtime refresh are dependable.

## Implemented Foundation

Database:

- `conversations`
- `conversation_participants`
- `messages`
- `message_reads`
- `favorite_messages`
- `blocked_users` safety creation if missing

RPCs:

- `ensure_self_conversation`
- `create_direct_conversation`
- `create_group_conversation`
- `send_message`
- `mark_conversation_read`
- `toggle_favorite_message`
- `search_chat_profiles`
- `list_conversations`
- `list_conversation_messages`
- `update_profile_presence`

Flutter:

- `features/chats/` clean feature structure
- Chats tab with All, Unread, Favorites, Groups filters
- global chat profile search by CIVIQ code or username
- Saved Messages/self chat
- direct conversation creation
- realtime active-room refresh
- read receipt marking
- ephemeral typing broadcast
- favorite messages by long press
- pinned Saved Messages with the profile avatar
- real online/last-seen status from profile presence
- chat message notifications through notification rows
- auth-change cache invalidation for account switching
- chat-list polish: verified badge sits directly after the username, and outgoing delivery ticks sit directly after the `You:` message preview
- optimistic sending: outgoing text appears immediately with a clock icon, stays visible until the confirmed server message is present, and retries queued sends instead of disappearing during network gaps
- call, video, media, voice, disappearing messages, theme, and group controls as placeholders

## Tables

`conversations`

- id
- conversation_type: `direct`, `group`, `self`
- title
- created_by
- created_at
- updated_at

`conversation_participants`

- conversation_id
- user_id
- joined_at
- last_read_message_id
- is_muted
- is_archived
- is_favorite

`messages`

- id
- conversation_id
- sender_id
- message_type
- content
- media_url
- reply_to_message_id
- is_edited
- created_at
- updated_at
- deleted_at

`message_reads`

- message_id
- user_id
- delivered_at
- read_at

`favorite_messages`

- user_id
- message_id
- created_at

## Build Order

Current status:

1. Database tables: implemented
2. Conversation creation: implemented for self/direct, guarded group RPC added
3. 1-to-1 messaging: implemented
4. Realtime updates: implemented for active rooms and conversation refresh
5. Read receipts: implemented with privacy guard
6. Typing indicators: implemented as ephemeral broadcast
7. Favorites: implemented
8. Presence and last seen: implemented
9. Message notifications: implemented through database trigger and local listener
10. Chat-list delivery previews: implemented for sent, delivered, and read states
11. Optimistic message send state: implemented with pending clock icon
12. Groups: database/RPC foundation only
13. Media uploads: deferred
14. Disappearing messages: deferred

## Moderation And Security

Phase 2 security must remain server-owned:

- blocked users cannot create new direct/group conversations together
- blocked users cannot send messages to each other inside existing conversations
- participants cannot read conversations they do not belong to
- message sending is rate-limited by RPC
- read receipts respect `profiles.show_read_receipts`
- message search must remain indexed and paginated

Future moderation:

- report message
- report user from room menu
- moderator review queue
- abuse heuristics for repeated message failures and spam reports
- evidence-preserving clear/delete semantics

## Scaling Plan

Near term:

- add paginated older-message loading with `before_message_created_at`
- add conversation title and message-content search via indexed RPC
- move message notification fanout to an Edge Function queue before full push rollout
- add archived chats screen
- add small private group UI

Later:

- media bucket with file-size and MIME validation
- virus/NSFW scanning pipeline
- voice notes with duration metadata
- disappearing messages with retention jobs
- WebRTC calls as a separate architecture project
- county/community channels after private groups are stable
