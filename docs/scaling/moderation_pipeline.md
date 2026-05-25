# Moderation Pipeline

Phase 2 keeps moderation hooks server-owned:

- blocked users cannot create or use shared conversations
- message sending is guarded by RPC
- message deletion is soft delete through `deleted_at`
- notifications can be archived, deleted, or spam-reported

Next server tasks:

- report-message RPC
- report-user RPC
- moderation queue table
- Edge Function spam scoring
- background cleanup for stale notification and presence data
- abuse heuristics for message bursts, mass follows, and repeated reports
