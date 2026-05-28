# SIVIQ Display Names

Date: 2026-05-28

## What Was Added

SIVIQ now supports a human-readable `display_name` on `profiles`.

Identity now has three public pieces:

- `display_name`: human name shown first, for example `Gregory Steve`.
- `username`: stable handle shown underneath, for example `@gregory_steve`.
- `civiq_code`: SIVIQ account code, for identity/support/reference.

## Why This Was Done

Supabase Auth shows a display name area, but SIVIQ’s app identity is managed through the public `profiles` table. Adding `profiles.display_name` keeps app identity queryable, searchable, and available in feeds, chats, profiles, groups, and moderation evidence.

## Database Changes

Migration:

```text
supabase/migrations/20260528123000_display_names.sql
```

It adds:

```sql
alter table public.profiles
add column if not exists display_name text;
```

It also updates the main profile/feed/chat RPCs and views so `display_name` is returned with:

- `get_profile_summary`
- `discover_civiq_profiles`
- `search_chat_profiles`
- `list_group_members`
- `list_conversations`
- `v_social_post_feed`
- `v_project_feed`
- `v_social_post_comments`
- `v_project_comments`

## App Behavior

- Profile setup now asks for display name.
- Edit Profile now lets existing users add or update display name.
- Public profile shows display name first, badge beside display name, and username underneath.
- App drawer/profile header shows display name first and username underneath.
- Home search shows display name first and username underneath.
- Feed posts use display name first and username beside the timestamp line.
- Chats and group members use display name first, while username remains visible in secondary text.

## Rules

- Display name is optional for existing users.
- Existing users without display name fall back to `@username`.
- Username remains the stable handle and should stay unique.
- Display name is not unique and can contain spaces.
- Badges attach to display name, not username.

## Future Improvements

- Add display name to notification wording.
- Add display name to message bubble sender labels.
- Add full-text/trigram search indexes for `display_name`.
- Optionally sync `display_name` into Supabase Auth user metadata later for dashboard convenience.
