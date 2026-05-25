# Database Indexes

Phase 2 chat relies on:

- `idx_profiles_username` for username lookup
- `idx_profiles_civiq_code` for CIVIQ code lookup
- `idx_profiles_presence` for online/last-seen checks
- `idx_conversation_participants_user` for listing a user's conversations
- `idx_messages_conversation_created` for message pagination
- `idx_message_reads_user_read` for unread/read receipt checks
- `idx_notifications_user` and `idx_notifications_user_unread` for notification lists and badges
- `idx_favorite_messages_user_created` for saved/starred messages

Queries should stay bounded with limits and cursor parameters. Avoid offset pagination for high-traffic feeds, chat history, followers, notifications, and search.
