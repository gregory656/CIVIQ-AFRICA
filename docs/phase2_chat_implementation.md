# Phase 2 Chat Implementation

Date: 2026-05-25

## Implemented

- Saved Messages is pinned at the top of the All chats list with a pin badge.
- Saved Messages uses the signed-in user's `profiles.avatar_url` as the display picture.
- Direct chats show real online status from `profiles.is_online` and `profiles.last_seen`.
- Typing state remains ephemeral through Supabase realtime broadcast channels and displays a green typing indicator.
- Chat providers are invalidated on auth changes so logout/login does not reuse stale conversations from the previous account.
- The chat list owns a narrow realtime subscription on the signed-in user's `conversation_participants` rows.
- Message notification inserts refresh notifications and chat lists through the existing realtime notification listener.
- Message bubbles now have directional tails: sent messages tail from the top edge, received messages tail from the bottom edge.
- Unread counts remain the green badge in All and Unread filters; read conversations fall back to the chevron.
- Logout marks the user offline on a best-effort RPC before clearing the Supabase session.
- Chat-list verified badges render directly after usernames instead of at the far edge.
- Chat-list delivery ticks render directly after the latest outgoing `You:` preview.

## Migration

`supabase/migrations/20260525120000_phase2_chat_presence_notifications.sql`

Adds:

- `profiles.is_online`
- `profiles.last_seen` if missing
- presence, username, CIVIQ code, and notification indexes
- `update_profile_presence(online_now boolean)`
- `handle_message_delivery_and_notification()`
- `message_delivery_and_notification_after_insert`
- updated `list_conversations()` return shape with peer presence fields

## Notification Flow

1. `send_message()` inserts a row into `messages`.
2. `message_delivery_and_notification_after_insert` creates recipient delivery rows in `message_reads`.
3. The trigger inserts a `chat_message` notification for unmuted recipients.
4. The Flutter notification realtime listener receives the insert for the current user.
5. Local notification displays: `Unread message from {username}` with `Open your messages to read and reply.`
6. Notification listener invalidates notifications, unread notification count, and conversations.

This keeps push/local notification work outside the send RPC path from Flutter's perspective. A future Edge Function worker can replace direct notification inserts with a queued push fanout without changing the app UI.

## Policies

Phase 2 continues to rely on existing RLS policies from `20260523190000_phase2_realtime_messaging.sql`:

- participants can read only conversations they belong to
- participants can read only messages in their conversations
- users can update only their own participant state
- users can read their own favorite messages
- users can read their own notification rows

The new presence RPC is `security definer` and only updates `auth.uid()`.

## Scale Constraints

- Message fetch is paginated through `list_conversation_messages(... result_limit)`.
- Conversation list is server-owned through `list_conversations()` and indexed.
- Realtime room updates subscribe only to the active `messages` conversation.
- Typing indicators are broadcast-only and never stored in Postgres.
- Presence updates are throttled to roughly once per minute while the chat tab is active.
- Groups remain capped at 50 members by RPC.
- Media remains URL-only in message rows; raw files stay outside Postgres.
