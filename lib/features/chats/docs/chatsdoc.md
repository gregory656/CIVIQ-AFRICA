# SIVIQ Chat Architecture

## Domain Boundaries

Chats own conversation actions, message search, message state, presence, and chat-specific privacy shortcuts.

Chats do not own profile editing, bio editing, account security, app-wide settings, or legal policy management. Those remain in Profile, Settings, Security, and Legal routes.

## Chat Tab

The Chats tab top bar contains:

- SIVIQ title
- global chat search
- chat menu with New Group, Archived Chats, Starred Messages, Privacy Shortcuts, and Chat Settings

The tab menu intentionally excludes profile photo, bio, and edit-profile actions.

Search supports SIVIQ code and username now. Conversation title, group, and message-content search are planned, but message search must use indexed/paginated queries rather than live scanning the full `messages` table.

## Conversation Types

`conversations.conversation_type` supports:

- `self`: Saved Messages for the current user
- `direct`: one-to-one private conversations
- `group`: small private groups

Every profile gets a `self` conversation from the `create_self_conversation_after_profile` trigger. Existing users are backfilled by the Phase 2 migration.

## Realtime Flow

Messages are persisted in `messages`. The client subscribes to:

- `messages` changes for the active conversation
- `message_reads` changes for delivery/read state refresh
- `conversation_participants` changes for archive, mute, and favorite state

Typing is ephemeral and sent through Supabase Realtime broadcast channels. Typing is not stored in Postgres.

Online presence is planned for Supabase Realtime Presence. The database already has `profiles.show_online_status` and `profiles.last_seen`; UI should respect the privacy setting before showing last-seen text.

## Delivery States

The UI maps message state as:

- Sent: message row exists on the server
- Delivered: at least one recipient has a `message_reads.delivered_at`
- Read: at least one recipient has a `message_reads.read_at`

`read_at` is only set when the reader has `profiles.show_read_receipts = true`. If disabled, delivery may still be recorded but read receipts remain hidden.

## Security Rules

Core RLS and RPC rules:

- users can only read conversations where they are participants
- users can only read messages in their conversations
- users can only update their own participant state
- direct/group creation checks `blocked_users`
- direct/group creation checks `profiles.allow_message_requests`
- `send_message` rate-limits short bursts
- media fields exist but uploads are deferred until validation policy is built

Message creation should go through `send_message` instead of direct table inserts, because the function centralizes rate limits, block checks, and participant validation.

## Room Menus

The room menu contains:

- View Profile
- Search Messages
- Disappearing Messages
- Change Chat Theme
- Mute Notifications
- Block User
- Report User
- Clear Chat

Permanent conversation deletion is intentionally not included in Phase 2.
