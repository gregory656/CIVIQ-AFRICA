# SIVIQ Lightweight Moderator Guide

This is the launch-ready moderation guide for the current SIVIQ app.

## Create Your Moderator Login

Current launch roles:

- `adminsiviq@gmail.com` is `super_admin` and receives the gold SIVIQ badge.
- `gregorystephen2006@gmail.com` is `moderator` and receives the red SIVIQ badge.
- Other verified users keep the normal blue verified badge.

1. Sign up or log in normally in the SIVIQ app using the account you want to control moderation from.
2. Open Supabase Dashboard.
3. Go to SQL Editor.
4. Run this, replacing the email:

```sql
update public.profiles
set role = 'super_admin'
where lower(email) = lower('your-email@example.com');
```

Use `super_admin` for the platform owner. Use `moderator` for trusted helpers.

## How To Log In

After setting the role:

1. Open the SIVIQ app.
2. Log in with the same email/password.
3. Open a home post or project post.
4. Tap the three-dot menu.
5. Moderator-only actions will appear.

If the menu does not change, fully close and reopen the app so the profile reloads.

## What Moderators Can Do Now

From post/project three-dot menus:

- Remove as moderator
- Send to review
- Suspend author/creator for 7 days

The app records every moderation action in `moderation_actions`.

## Evidence Queries

Fetch all moderation actions:

```sql
select
  ma.id,
  ma.created_at,
  moderator.email as moderator_email,
  target.email as target_email,
  ma.action_type,
  ma.reason,
  ma.target_post_id,
  ma.target_project_id,
  ma.target_comment_id,
  ma.target_comment_table,
  ma.metadata
from public.moderation_actions ma
left join public.profiles moderator on moderator.id = ma.moderator_id
left join public.profiles target on target.id = ma.target_user_id
order by ma.created_at desc;
```

Fetch suspended, banned, or reviewed accounts:

```sql
select
  id,
  email,
  username,
  role,
  account_status,
  suspension_until,
  muted_until,
  updated_at
from public.profiles
where account_status <> 'active'
   or muted_until > now()
order by updated_at desc;
```

Fetch removed or reviewed posts:

```sql
select
  p.id,
  p.created_at,
  p.author_id,
  author.email as author_email,
  p.body,
  p.moderation_status,
  p.moderated_reason,
  p.moderated_at,
  moderator.email as moderator_email
from public.social_posts p
left join public.profiles author on author.id = p.author_id
left join public.profiles moderator on moderator.id = p.moderated_by
where p.moderation_status <> 'active'
order by p.moderated_at desc;
```

Fetch removed or reviewed projects:

```sql
select
  p.id,
  p.created_at,
  p.creator_id,
  creator.email as creator_email,
  p.title,
  p.description,
  p.moderation_status,
  p.moderated_reason,
  p.moderated_at,
  moderator.email as moderator_email
from public.projects p
left join public.profiles creator on creator.id = p.creator_id
left join public.profiles moderator on moderator.id = p.moderated_by
where p.moderation_status <> 'active'
order by p.moderated_at desc;
```

Fetch appeals:

```sql
select
  a.id,
  a.created_at,
  user_profile.email,
  user_profile.username,
  a.reason,
  a.status,
  a.post_id,
  a.project_id,
  a.action_id
from public.moderation_appeals a
join public.profiles user_profile on user_profile.id = a.user_id
order by a.created_at desc;
```

## Restore Content Or Accounts

Restore a social post:

```sql
select public.moderate_social_post(
  'POST_ID_HERE',
  'active',
  'Appeal approved'
);
```

Restore a project:

```sql
select public.moderate_project(
  'PROJECT_ID_HERE',
  'active',
  'Appeal approved'
);
```

Restore an account:

```sql
select public.moderate_user_account(
  'USER_ID_HERE',
  'active',
  'Appeal approved',
  null,
  null
);
```

## Important Rules

- Do not hard-delete harmful content during launch unless legally required.
- Use soft moderation so SIVIQ keeps evidence.
- Always choose a reason.
- Use calm wording with users.
- Do not give moderator access to people you do not fully trust.
- Never put Supabase service-role keys in the Flutter app.
