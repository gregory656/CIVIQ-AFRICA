# SIVIQ Vulnerabilities, Scaling Risks, And Fix Plan

This document is a launch-readiness scan of the current SIVIQ app, Supabase schema, Edge Functions, assets, and runtime patterns.

Filename note: this file intentionally uses `vulnaribilities.md` because that was the requested filename.

## Executive Summary

SIVIQ is in a good MVP shape for a small launch, but it is not yet ready for heavy public traffic. The biggest risks are not one single bug. They are a group of scaling and abuse issues:

- Client-side Cloudinary uploads can be abused if the unsigned preset is not tightly locked.
- Some views and RPCs need a security review before broad public use.
- Several screens still expose raw technical errors.
- Multiple lists fetch all rows with no pagination.
- Search uses wildcard `ilike` patterns that will become slow without indexes or full-text search.
- Realtime invalidations can cause too many database refreshes as users increase.
- Data export builds a full ZIP in memory, which can become CPU and memory heavy.
- Feed, notification, chat, comment, and profile list queries need pagination before real scale.

The app can likely survive a small Play Store launch, but should be hardened before aggressive promotion.

## Current Capacity Estimate

This estimate assumes the current architecture:

- Flutter app talks directly to Supabase.
- Supabase Auth, Postgres, Realtime, Edge Functions, and Cloudinary are the main backend services.
- Most feed/search/profile data is loaded directly from views or RPCs.
- Realtime is used for notifications and chat.

Supabase Realtime official limits as of this scan:

- Free: 200 concurrent realtime connections, 100 messages per second.
- Pro: 500 concurrent realtime connections, 500 messages per second.
- Pro without spend cap / Team: up to 10,000 concurrent realtime connections and 2,500 messages per second.

Source: https://supabase.com/docs/guides/realtime/limits

Important meaning: Supabase defines concurrent peak connections as simultaneous Realtime connections. One logged-in app user with Realtime enabled usually counts as one concurrent connection, even if they join multiple channels.

Source: https://supabase.com/docs/guides/troubleshooting/realtime-concurrent-peak-connections-quota-jdDqcp

### Practical Estimate For This App Today

If the app is on Supabase Free:

- Safe active concurrent users: about 50 to 150.
- Hard realtime ceiling: about 200 connected users.
- Daily active users with light usage: about 500 to 2,000.
- Risk starts quickly if many users are chatting at the same time.

If the app is on Supabase Pro:

- Safe active concurrent users: about 250 to 500.
- Hard realtime ceiling: about 500 connected users unless limits are increased.
- Daily active users with light usage: about 3,000 to 10,000.
- Feed/search can become the bottleneck before Realtime if posts grow fast.

If upgraded to Pro without spend cap or custom limits, after fixing pagination/indexing:

- Reasonable target: 1,000 to 3,000 active concurrent users.
- Higher is possible, but only after load testing and query optimization.

These are not guarantees. Real capacity depends on Supabase plan, compute size, database rows, media size, chat intensity, indexes, and cache behavior.

## Critical Findings

### 1. Cloudinary Unsigned Upload Abuse

Evidence:

- `lib/core/services/cloudinary_service.dart` uploads directly from the client.
- `.env.client` includes `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`, and `CLOUDINARY_API_KEY`.
- The upload preset is `ml_default`, which is commonly an unsigned preset unless Cloudinary is locked down.

Risk:

- Attackers can extract the app bundle, find the Cloudinary cloud name and preset, then upload unwanted media.
- This can create storage bills, moderation risk, illegal content risk, and bandwidth costs.
- Client-side file size/type checks alone are not enough because a modified client can bypass them.

Fix:

- Replace direct unsigned uploads with a Supabase Edge Function that creates signed Cloudinary upload parameters.
- Lock the Cloudinary preset to specific folders, allowed formats, max file size, and moderation if available.
- Remove `CLOUDINARY_API_KEY` from `.env.client`; it is not needed in the app.
- Add server-side checks for MIME type, file size, user ID, and upload frequency.
- Add upload rate limits per user and per IP.

Priority: Critical before broad launch.

### 2. View Security Needs Explicit Review

Evidence:

- Public views include `v_social_post_feed`, `v_project_feed`, leaderboard views, comment views, and chat-related RPC outputs.
- Supabase/Postgres views can accidentally bypass table RLS depending on ownership and `security_invoker` behavior.

Risk:

- A view can expose rows that base-table RLS would otherwise hide if it is not configured correctly.
- This is especially important for profile data, hidden posts, deleted rows, reports, messages, and moderation fields.

Fix:

- Audit every `create view` migration.
- Where supported, recreate user-facing views with `with (security_invoker = true)`.
- Keep explicit `auth.uid()` checks inside views/RPCs where user-specific filtering is required.
- Add SQL tests for “user A cannot see user B private/deleted/hidden data.”

Priority: Critical before large public traffic.

### 3. Raw Backend Errors Still Leak In Some Screens

Evidence:

- Several screens still use `error.toString()` or `Could not ...: $error`.
- Examples appear in auth, profile setup, avatar upload, export, notifications, privacy, security, chats, and rankings screens.

Risk:

- Users may see Supabase URLs, table names, policy errors, stack traces, or developer wording.
- This hurts trust and can expose backend structure.

Fix:

- Use the shared `friendlyErrorMessage()` helper app-wide.
- Log technical details only to a server-side or developer-only error log.
- Show user-facing messages like offline, retry, permission denied, or “Something went wrong.”

Priority: High before Play Store review and public launch.

## High-Risk Scaling Findings

### 4. Search Will Slow Down As Data Grows

Evidence:

- Global search uses wildcard `ilike '%query%'` on profiles, posts, and projects.
- This is good for MVP but can table-scan as rows grow.

Risk:

- Search can become slow after thousands of posts/profiles.
- Slow search can raise database CPU and make the whole app feel broken.

Fix:

- Add `pg_trgm` indexes for `username`, `bio`, `civiq_code`, post body, project title, description, and location.
- Move global search into a single RPC with limits, ranking, and safety checks.
- Later upgrade to full-text search with `tsvector` columns.

Priority: High before marketing.

### 5. Offset Pagination Will Become Expensive

Evidence:

- Home feed now uses `.range(offset, offset + limit - 1)`.

Risk:

- Offset pagination gets slower as the offset grows because the database still scans/skips earlier rows.
- Users can see duplicates or missing rows when new posts arrive while paging.

Fix:

- Use keyset pagination: `created_at < last_seen_created_at`, with `id` as a tie-breaker.
- Add an index on `(deleted_at, created_at desc, id desc)`.
- Return a cursor from the repository/RPC.

Priority: High.

### 6. Many Lists Still Fetch Everything

Evidence:

- Notifications fetch all non-archived rows.
- Archived notifications fetch all rows.
- Security events, legal history, followers, following, comments, and some project/profile lists fetch without clear page limits.

Risk:

- Old accounts become slow.
- Supabase egress and database CPU grow unnecessarily.
- Long lists can cause UI jank and memory pressure.

Fix:

- Add limits and keyset pagination to every historical list.
- Use count RPCs only where needed.
- Add “load more” UI for notifications, comments, followers, following, security history, and legal history.

Priority: High.

### 7. Realtime Invalidations Are Too Broad

Evidence:

- `NotificationRealtimeListener` invalidates notifications, unread count, conversations, and home feed for every inserted notification.
- Chat message channels listen to `message_reads` without a conversation filter.
- Typing broadcasts use realtime channels and should be carefully reused/debounced.

Risk:

- A notification can trigger unnecessary feed and chat refetches.
- Message read events from unrelated conversations may refresh open chat screens.
- At scale this creates extra database load and battery/network drain.

Fix:

- Only invalidate providers related to the notification category.
- Filter `message_reads` by conversation where possible.
- Keep one typing channel per open room and reuse it.
- Debounce realtime-triggered refetches.
- Prefer small targeted state updates over full provider invalidation.

Priority: High before chat-heavy launch.

## Security And Abuse Findings

### 8. Missing Rate Limits For Social Posts, Comments, Reports, Follows, And Votes

Evidence:

- Chat messages have server-side rate limiting.
- Social posts, social comments, project comments, follows, project votes, post reports, and project reports mostly rely on normal inserts/RPCs.

Risk:

- A single user can spam content, reports, votes, follows, or comments.
- Moderation queues can be flooded.
- Project rankings and feed quality can be manipulated.

Fix:

- Add server-side rate limit tables or RPC checks.
- Suggested starter limits:
  - Posts: 10 per hour per user.
  - Comments: 60 per hour per user.
  - Reports: 30 per day per user.
  - Follows: 100 per day per user.
  - Votes: 300 per day per user, with velocity flags.
- Add temporary account age restrictions for brand-new accounts.

Priority: High.

### 9. Duplicate Reports Can Throw User-Facing Errors

Evidence:

- Report tables use unique constraints such as one report per user per target.
- Client report code inserts directly.

Risk:

- Reporting the same item twice may produce a database constraint error.
- If not friendly-mapped, the user sees technical wording.

Fix:

- Use `upsert` for report actions.
- Return “You already reported this” or “Report updated.”

Priority: Medium.

### 10. Edge Functions Return Raw Error Messages

Evidence:

- `export-user-data` and `log-security-event` return `error.message` in 500 responses.

Risk:

- Table names, policy details, storage bucket names, or implementation details may leak.

Fix:

- Return generic user-facing errors.
- Log technical errors server-side.
- Use structured error codes like `export_failed`, `security_event_failed`, `rate_limited`.

Priority: Medium.

### 11. CORS Is Wide Open On Edge Functions

Evidence:

- Edge Functions use `Access-Control-Allow-Origin: *`.

Risk:

- Mobile apps are less affected, but web clients or copied tokens can invoke functions from any origin.
- Combined with stolen auth tokens, this increases abuse surface.

Fix:

- Keep mobile support, but restrict browser origins where web is used.
- Validate auth on every function, which is already being done.
- Add request rate limiting.

Priority: Medium.

### 12. Data Export Can Become CPU And Memory Heavy

Evidence:

- `export-user-data` collects user rows, builds JSON strings, then creates a ZIP in memory.
- Some selected tables have no per-table limit.

Risk:

- A large account can make the function slow or memory-heavy.
- Attackers can request exports repeatedly across many accounts.
- The function currently limits each user to one export per 24 hours, which helps, but large accounts remain expensive.

Fix:

- Move exports to a background job queue.
- Stream data instead of building the whole ZIP in memory.
- Include all current app tables intentionally: `social_posts`, `project_comments`, `social_post_comments`, projects, reports, follows, chats where legally appropriate.
- Keep one export per 24 hours or stricter.

Priority: Medium.

## CPU, Storage, And Temp File Risks

### 13. Large Media Assets Increase App Size

Evidence:

- `assets/real_splash.png` is about 1.2 MB.
- `assets/realicon.png` is about 894 KB.
- The old `assets/splash_screen.png` was removed from the project in this refinement pass.

Risk:

- Large bundled assets increase APK/AAB size and install/update cost.
- Large full-screen PNGs can use more memory at startup.

Fix:

- Compress `real_splash.png` with PNG quantization or convert to WebP if Flutter/Android setup supports it cleanly.
- Keep only one splash asset.
- Use appropriately sized density assets if needed.

Priority: Medium.

### 14. Post “Save To Device” Can Spike Memory

Evidence:

- Home post saving captures the whole widget at `pixelRatio: 3`.

Risk:

- Large posts/images can create a large in-memory bitmap.
- Low-end Android phones can jank or crash during capture.

Fix:

- Lower capture pixel ratio to 2 on low-memory devices.
- Add a max capture dimension.
- Save the media URL directly where possible instead of rendering the whole card.
- Show progress and prevent repeated taps while saving.

Priority: Medium.

### 15. Image Uploads Need Stronger Compression And Size Limits

Evidence:

- Image picker uses `imageQuality: 82`.
- No obvious max width/height or file size guard exists before upload.

Risk:

- Large photos use CPU, memory, data bundles, Cloudinary bandwidth, and user battery.

Fix:

- Set max width/height in `ImagePicker`.
- Reject files above a fixed size before upload.
- Compress client-side, then verify server-side in the signed upload function.

Priority: High for Kenya mobile data friendliness.

### 16. Local Build And Temp Folders Are Correctly Ignored

Evidence:

- `.gitignore` excludes `.dart_tool/`, `build/`, coverage, node_modules, and platform build outputs.

Risk:

- These folders can eat local disk/CPU during development but are not shipped to users.

Fix:

- Keep them ignored.
- Run `flutter clean` before release builds if the workspace gets slow.
- Do not commit generated build folders.

Priority: Low.

## Database And Query Risks

### 17. Notification Count Fetches Rows Instead Of Count

Evidence:

- `fetchUnreadCount` selects `id` and uses `response.length`.

Risk:

- For users with many notifications, this transfers unnecessary rows.

Fix:

- Use Supabase count with head/exact or an RPC returning `count(*)`.

Priority: Medium.

### 18. Feed Views Need More Index Support

Evidence:

- Home feed filters by `created_at >= archiveCutoff`, orders by `created_at desc`, and excludes hidden posts through a join-like `not exists`.

Risk:

- Feed can slow as posts and hidden-post rows grow.

Fix:

- Add index on `social_posts(deleted_at, created_at desc, id desc)`.
- Add index on `social_post_hidden_users(user_id, post_id)`.
- For project feed, add indexes on searchable text and `created_at`.

Priority: High.

### 19. Rankings Weekly Job Can Become Expensive

Evidence:

- Ranking snapshot function aggregates project votes, profiles, projects, leader links, and snapshots.

Risk:

- Fine for MVP, but expensive when project_votes grows.
- If run manually or accidentally too often, it can load the database.

Fix:

- Keep execution revoked from normal users.
- Add admin-only manual RPC with strict checks.
- Add indexes on vote timestamps and project/leader links.
- Monitor runtime before enabling public rankings.

Priority: Medium.

## UX Reliability Risks

### 20. Offline Handling Is Not Yet App-Wide

Evidence:

- Feed and project areas now use friendly handling in many places.
- Other screens still show raw errors.

Risk:

- Users on unstable mobile data may still see ugly errors.

Fix:

- Apply `friendlyErrorMessage()` everywhere.
- Add one reusable offline/empty/error widget.
- Consider a connectivity banner.

Priority: High.

### 21. Some “Coming Soon” Actions Remain

Evidence:

- Some chat menu actions and export-first UI still show coming-soon messages.

Risk:

- For Play Store, incomplete actions are not security bugs but can feel unfinished.

Fix:

- Hide incomplete actions until implemented.
- Keep only stable launch actions visible.

Priority: Medium.

## Recommended Fix Order

1. Lock Cloudinary uploads behind signed server-side upload.
2. Audit all Supabase views for `security_invoker` and RLS behavior.
3. Replace raw errors app-wide with friendly errors.
4. Add server-side rate limits for posts, comments, reports, follows, and votes.
5. Add pagination to notifications, comments, followers/following, security history, legal history, and project feeds.
6. Replace offset feed pagination with keyset pagination.
7. Add search indexes or a full-text search RPC.
8. Reduce realtime invalidations and filter chat read events.
9. Compress splash/icon assets and limit upload image dimensions.
10. Load test with 50, 100, 250, and 500 concurrent sessions before promotion.

## Suggested Load Test Targets

Before Play Store:

- 25 concurrent users browsing feed.
- 10 concurrent users chatting.
- 10 users posting/commenting/reporting.
- 5 users uploading images.

Before marketing:

- 100 concurrent users browsing.
- 50 concurrent chat users.
- 500 posts, 5,000 comments, 10,000 notifications test dataset.

Before national-scale push:

- 500 to 1,000 concurrent users.
- 100,000 posts/comments combined.
- Realistic media bandwidth testing.
- Supabase Realtime report review.
- Supabase database query performance review.

## Monitoring To Add

- Supabase database slow query logs.
- Supabase Realtime reports.
- Edge Function error counts and latency.
- Cloudinary upload count, bandwidth, storage, and moderation alerts.
- App crash reporting.
- App startup time and memory on low-end Android devices.
- Post/comment/report/follow rate-limit events.

Supabase Realtime reports source: https://supabase.com/docs/guides/realtime/reports

Supabase storage egress source: https://supabase.com/docs/guides/storage/serving/bandwidth

## Final Readiness Call

Current app state:

- Good for controlled beta and small Play Store launch.
- Not ready for a big public campaign yet.
- Most urgent hardening work is backend-side abuse prevention, query pagination, view/RLS review, and media upload control.

Launch recommendation:

- Release quietly after app-wide friendly error handling and Cloudinary upload hardening.
- Promote county by county only after pagination, search indexes, and realtime invalidation fixes are complete.

