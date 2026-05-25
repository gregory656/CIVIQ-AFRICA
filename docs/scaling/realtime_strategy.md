# Realtime Strategy

- Subscribe to active conversation messages only while the room is open.
- Subscribe to the current user's `conversation_participants` rows for chat-list membership/state changes.
- Use notification inserts to refresh chats when a new message arrives for an inactive conversation.
- Keep typing indicators on Supabase broadcast channels, not database rows.
- Keep presence coarse: update on resume, pause, logout, and about once per minute while active.
- Avoid global `messages` subscriptions.
