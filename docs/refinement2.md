# SIVIQ Refinement Pass 2

Date: 2026-05-28

## Fixed In This Pass

- Added lightweight role-based moderation in Supabase.
- Added `profiles.role` with `user`, `moderator`, `admin`, and `super_admin`.
- Added `profiles.account_status`, `suspension_until`, and `muted_until`.
- Protected role, account status, suspension, mute, and verification fields from normal user self-update.
- Added evidence-preserving soft moderation fields to:
  - `social_posts`
  - `projects`
  - `social_post_comments`
  - `project_comments`
- Added `moderation_actions` audit log table.
- Added `moderation_appeals` table.
- Added moderator RPCs for:
  - removing/reviewing social posts
  - removing/reviewing project posts
  - removing/reviewing social comments
  - removing/reviewing project comments
  - suspending, banning, reviewing, muting, or restoring accounts
- Added automatic moderation notification rows using category `moderation_action`.
- Updated post, project, and comment feed views so removed/hidden/review content no longer appears in normal feeds.
- Updated project details used in rankings so moderated projects are hidden from ranking project detail lists.
- Added a project moderation trigger that unlinks hidden/removed/reviewed projects from leader ranking inputs, then relinks them if restored to active.
- Added account restriction enforcement before creating posts, projects, and comments.
- Added in-app moderator actions to existing three-dot menus:
  - remove post/project as moderator
  - send post/project to review
  - suspend author/creator for 7 days
- Added app-open account-status check. Suspended, banned, or under-review accounts are routed to Account Status instead of the home screen.
- Updated Account Status screen to show restriction details and appeal/sign-out actions.
- Removed unused `CLOUDINARY_API_KEY` from `.env.client`.
- Removed unused `cloudinaryApiKey` getter from Flutter env config.
- Added role-colored verification badges:
  - gold for SIVIQ `super_admin` / `admin`
  - red for SIVIQ `moderator`
  - blue for normal verified users
- Promoted `adminsiviq@gmail.com` to `super_admin`.
- Promoted `gregorystephen2006@gmail.com` to `moderator`.
- Exposed profile roles in feed/search/chat profile RPC outputs so badges can render correctly.
- Added `profiles.display_name` so users can show a human name such as `Gregory Steve` while keeping `@username` and SIVIQ code for identity.
- Updated profile setup and edit profile so users can create/update display names.
- Updated major profile, search, feed, chat, and group member surfaces to show display name first, badge beside display name, and username underneath or in secondary text.

## What This Means

SIVIQ now has a basic moderation layer, not a full admin dashboard. This is intentional for launch safety.

Moderators can act from the same app, and each action stores:

- moderator ID
- target user ID where available
- target post/project/comment where available
- action type
- reason
- timestamp
- metadata for account restrictions

The platform preserves evidence instead of hard-deleting content immediately.

## Remaining Work

- Apply and test the new Supabase migration in the real Supabase project.
- Promote your chosen account to `super_admin` or `moderator` from Supabase SQL Editor.
- Build a proper moderation dashboard later.
- Add report user and block user buttons on profile pages.
- Add a visible appeal submission form in-app instead of only the legal/appeals instructions.
- Add moderator review UI for pending appeals.
- Add signed Cloudinary uploads through an Edge Function.
- Add server-side rate limits for posts, comments, reports, follows, and votes.
- Audit all views for `security_invoker` behavior and RLS exposure.
- Replace offset pagination with keyset pagination.
- Add search indexes or a global search RPC.
- Add Crashlytics/FCM before a larger public launch.

## Verification

Local code verification still needs to be run after this pass:

```bash
flutter analyze
flutter test
```

Database verification needs Supabase access:

```bash
supabase db push
```

or apply `supabase/migrations/20260528100000_lightweight_moderation.sql` from the Supabase CLI.
