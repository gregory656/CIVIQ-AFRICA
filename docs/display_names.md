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
- Group chat names do not show verified/admin/moderator badges. Badges belong to user profiles only.
- Post headers now include a compact relationship button before the three-dot menu.
- Public profiles include relationship actions and a message button.
- Followers/following list rows are clickable and include a relationship button on the far right.

## Rules

- Display name is optional for existing users.
- Existing users without display name fall back to `@username`.
- Username remains the stable handle and should stay unique.
- Display name is not unique and can contain spaces.
- Badges attach to display name, not username.
- Badges should not attach to groups, even if a group contains a moderator or super admin.

## Relationship Button Logic

The same relationship logic is used on post headers, public profiles, and profile lists:

- Self profile/post: hide the relationship button.
- Already following: show `Following` or `Unfollow` with an outlined green style depending on the surface.
- The other user follows you, but you do not follow them: show `Follow Back`.
- No relationship: show `Follow`.

Post card placement:

- Avatar, display name, and username stay on the left.
- The relationship button appears on the right before the three-dot menu.
- The three-dot menu remains the final action in the row.

## Future Improvements

- Add display name to notification wording.
- Add display name to message bubble sender labels.
- Add full-text/trigram search indexes for `display_name`.
- Optionally sync `display_name` into Supabase Auth user metadata later for dashboard convenience.
