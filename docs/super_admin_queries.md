# SIVIQ Super Admin SQL Queries

Use these in Supabase SQL Editor when you need legal evidence, moderation review, account recovery, or cleanup.

Replace IDs and emails before running action queries.

## 1. Moderation Dashboard Counts

```sql
select 'moderation_actions' as section, count(*)::int as count from public.moderation_actions
union all select 'restricted_accounts', count(*)::int from public.profiles where account_status <> 'active' or muted_until > now()
union all select 'moderated_posts', count(*)::int from public.social_posts where moderation_status <> 'active'
union all select 'deleted_posts', count(*)::int from public.social_posts where deleted_at is not null
union all select 'moderated_projects', count(*)::int from public.projects where moderation_status <> 'active'
union all select 'deleted_projects', count(*)::int from public.projects where deleted_at is not null
union all select 'moderated_social_comments', count(*)::int from public.social_post_comments where moderation_status <> 'active'
union all select 'deleted_social_comments', count(*)::int from public.social_post_comments where deleted_at is not null
union all select 'moderated_project_comments', count(*)::int from public.project_comments where moderation_status <> 'active'
union all select 'deleted_project_comments', count(*)::int from public.project_comments where deleted_at is not null
union all select 'pending_appeals', count(*)::int from public.moderation_appeals where status = 'pending';
```

## 2. Super Admin And Moderator Accounts

```sql
select id, email, username, role, role_label, is_verified, account_status, suspension_until, muted_until, updated_at
from public.profiles
where role in ('super_admin', 'admin', 'moderator')
order by case role when 'super_admin' then 0 when 'admin' then 1 when 'moderator' then 2 else 3 end, email;
```

## 3. Promote Accounts

```sql
update public.profiles
set role = 'super_admin', is_verified = true, verification_type = 'siviq_team',
    role_label = 'SIVIQ Super Admin', verified_at = coalesce(verified_at, now()), updated_at = now()
where lower(email) = lower('adminsiviq@gmail.com');
```

```sql
update public.profiles
set role = 'moderator', is_verified = true, verification_type = 'siviq_team',
    role_label = 'SIVIQ Moderator', verified_at = coalesce(verified_at, now()), updated_at = now()
where lower(email) = lower('gregorystephen2006@gmail.com');
```

## 4. Demote A Moderator

```sql
update public.profiles
set role = 'user', role_label = null, updated_at = now()
where lower(email) = lower('EMAIL_HERE');
```

## 5. Restricted Accounts

```sql
select id, email, username, role, account_status, suspension_until, muted_until, updated_at
from public.profiles
where account_status <> 'active' or muted_until > now()
order by updated_at desc;
```

## 6. Suspend, Ban, Review, Mute, Or Restore Account

Suspend for 7 days:

```sql
select public.moderate_user_account(
  'USER_ID_HERE',
  'suspended',
  'Reason for suspension',
  now() + interval '7 days',
  null
);
```

Ban:

```sql
select public.moderate_user_account('USER_ID_HERE', 'banned', 'Reason for ban', null, null);
```

Put under review:

```sql
select public.moderate_user_account('USER_ID_HERE', 'under_review', 'Reason for review', null, null);
```

Mute for 24 hours:

```sql
select public.moderate_user_account(
  'USER_ID_HERE',
  'active',
  'Muted for harmful comments',
  null,
  now() + interval '24 hours'
);
```

Restore:

```sql
select public.moderate_user_account('USER_ID_HERE', 'active', 'Appeal approved', null, null);
```

## 7. All Moderation Evidence

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

## 8. Evidence For One User

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
  ma.metadata
from public.moderation_actions ma
left join public.profiles moderator on moderator.id = ma.moderator_id
left join public.profiles target on target.id = ma.target_user_id
where target.email = 'EMAIL_HERE'
order by ma.created_at desc;
```

## 9. Removed, Hidden, Or Reviewed Posts

```sql
select
  p.id, p.created_at, p.updated_at, p.deleted_at,
  author.email as author_email,
  author.username as author_username,
  p.body,
  p.image_url,
  p.moderation_status,
  p.moderated_reason,
  p.moderated_at,
  moderator.email as moderator_email
from public.social_posts p
left join public.profiles author on author.id = p.author_id
left join public.profiles moderator on moderator.id = p.moderated_by
where p.moderation_status <> 'active' or p.deleted_at is not null
order by coalesce(p.moderated_at, p.deleted_at, p.created_at) desc;
```

## 10. Moderate Or Restore A Post

Remove post:

```sql
select public.moderate_social_post('POST_ID_HERE', 'removed', 'Reason for removal');
```

Send post to review:

```sql
select public.moderate_social_post('POST_ID_HERE', 'under_review', 'Reason for review');
```

Restore post:

```sql
select public.moderate_social_post('POST_ID_HERE', 'active', 'Appeal approved');
```

## 11. Removed, Hidden, Or Reviewed Projects

```sql
select
  p.id, p.created_at, p.updated_at, p.deleted_at,
  creator.email as creator_email,
  creator.username as creator_username,
  p.title,
  p.description,
  p.image_url,
  p.verification_status,
  p.moderation_status,
  p.moderated_reason,
  p.moderated_at,
  moderator.email as moderator_email
from public.projects p
left join public.profiles creator on creator.id = p.creator_id
left join public.profiles moderator on moderator.id = p.moderated_by
where p.moderation_status <> 'active' or p.deleted_at is not null
order by coalesce(p.moderated_at, p.deleted_at, p.created_at) desc;
```

## 12. Moderate Or Restore A Project

Remove project:

```sql
select public.moderate_project('PROJECT_ID_HERE', 'removed', 'Reason for removal');
```

Send project to review:

```sql
select public.moderate_project('PROJECT_ID_HERE', 'under_review', 'Reason for review');
```

Restore project:

```sql
select public.moderate_project('PROJECT_ID_HERE', 'active', 'Appeal approved');
```

## 13. Removed Or Reviewed Social Comments

```sql
select
  c.id, c.post_id, c.created_at, c.deleted_at,
  author.email as author_email,
  c.body,
  c.moderation_status,
  c.moderated_reason,
  c.moderated_at,
  moderator.email as moderator_email
from public.social_post_comments c
left join public.profiles author on author.id = c.author_id
left join public.profiles moderator on moderator.id = c.moderated_by
where c.moderation_status <> 'active' or c.deleted_at is not null
order by coalesce(c.moderated_at, c.deleted_at, c.created_at) desc;
```

## 14. Moderate Or Restore Social Comment

```sql
select public.moderate_social_comment('COMMENT_ID_HERE', 'removed', 'Reason for removal');
```

```sql
select public.moderate_social_comment('COMMENT_ID_HERE', 'active', 'Appeal approved');
```

## 15. Removed Or Reviewed Project Comments

```sql
select
  c.id, c.project_id, c.created_at, c.deleted_at,
  author.email as author_email,
  c.body,
  c.moderation_status,
  c.moderated_reason,
  c.moderated_at,
  moderator.email as moderator_email
from public.project_comments c
left join public.profiles author on author.id = c.author_id
left join public.profiles moderator on moderator.id = c.moderated_by
where c.moderation_status <> 'active' or c.deleted_at is not null
order by coalesce(c.moderated_at, c.deleted_at, c.created_at) desc;
```

## 16. Moderate Or Restore Project Comment

```sql
select public.moderate_project_comment('COMMENT_ID_HERE', 'removed', 'Reason for removal');
```

```sql
select public.moderate_project_comment('COMMENT_ID_HERE', 'active', 'Appeal approved');
```

## 17. Pending Appeals

```sql
select
  a.id, a.created_at, a.status,
  p.email, p.username,
  a.reason,
  a.post_id,
  a.project_id,
  a.action_id,
  reviewer.email as reviewed_by_email,
  a.reviewed_at
from public.moderation_appeals a
join public.profiles p on p.id = a.user_id
left join public.profiles reviewer on reviewer.id = a.reviewed_by
where a.status = 'pending'
order by a.created_at desc;
```

## 18. Review Appeal

Approve:

```sql
update public.moderation_appeals
set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
where id = 'APPEAL_ID_HERE';
```

Reject:

```sql
update public.moderation_appeals
set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
where id = 'APPEAL_ID_HERE';
```

## 19. Reports Queue

Social post reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email, author.email as author_email,
       r.reason, p.id as post_id, p.body, p.image_url
from public.social_post_reports r
join public.social_posts p on p.id = r.post_id
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles author on author.id = p.author_id
order by r.created_at desc;
```

Project reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email, creator.email as creator_email,
       r.reason, p.id as project_id, p.title, p.description
from public.project_reports r
join public.projects p on p.id = r.project_id
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles creator on creator.id = p.creator_id
order by r.created_at desc;
```

Message reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email, sender.email as sender_email,
       r.reason, m.id as message_id, m.conversation_id, m.content
from public.message_reports r
join public.messages m on m.id = r.message_id
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles sender on sender.id = m.sender_id
order by r.created_at desc;
```

Group reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email,
       r.reason, c.id as conversation_id, c.title
from public.group_reports r
join public.conversations c on c.id = r.conversation_id
left join public.profiles reporter on reporter.id = r.reporter_id
order by r.created_at desc;
```

Social comment reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email, author.email as author_email,
       r.reason, c.id as comment_id, c.post_id, c.body
from public.social_post_comment_reports r
join public.social_post_comments c on c.id = r.comment_id
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles author on author.id = c.author_id
order by r.created_at desc;
```

Project comment reports:

```sql
select r.id, r.created_at, reporter.email as reporter_email, author.email as author_email,
       r.reason, c.id as comment_id, c.project_id, c.body
from public.project_comment_reports r
join public.project_comments c on c.id = r.comment_id
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles author on author.id = c.author_id
order by r.created_at desc;
```

## 20. User Content Evidence Bundle

```sql
select 'profile' as type, to_jsonb(p.*) as evidence
from public.profiles p
where lower(p.email) = lower('EMAIL_HERE')
union all
select 'social_post', to_jsonb(sp.*)
from public.social_posts sp
join public.profiles p on p.id = sp.author_id
where lower(p.email) = lower('EMAIL_HERE')
union all
select 'project', to_jsonb(prj.*)
from public.projects prj
join public.profiles p on p.id = prj.creator_id
where lower(p.email) = lower('EMAIL_HERE')
union all
select 'moderation_action', to_jsonb(ma.*)
from public.moderation_actions ma
join public.profiles p on p.id = ma.target_user_id
where lower(p.email) = lower('EMAIL_HERE')
order by type;
```

## 21. Restore All Test Moderation

Use only after testing, not after real abuse cases.

```sql
with restored_posts as (
  update public.social_posts
  set moderation_status = 'active', moderated_reason = null, moderated_at = null,
      moderated_by = null, deleted_at = null, updated_at = now()
  where moderation_status <> 'active' or deleted_at is not null
  returning id
),
restored_projects as (
  update public.projects
  set moderation_status = 'active', moderated_reason = null, moderated_at = null,
      moderated_by = null, deleted_at = null, updated_at = now()
  where moderation_status <> 'active' or deleted_at is not null
  returning id
),
restored_social_comments as (
  update public.social_post_comments
  set moderation_status = 'active', moderated_reason = null, moderated_at = null,
      moderated_by = null, deleted_at = null
  where moderation_status <> 'active' or deleted_at is not null
  returning id
),
restored_project_comments as (
  update public.project_comments
  set moderation_status = 'active', moderated_reason = null, moderated_at = null,
      moderated_by = null, deleted_at = null
  where moderation_status <> 'active' or deleted_at is not null
  returning id
),
restored_accounts as (
  update public.profiles
  set account_status = 'active', suspension_until = null, muted_until = null, updated_at = now()
  where account_status <> 'active' or muted_until > now()
  returning id, email
)
select
  (select count(*) from restored_posts)::int as restored_posts,
  (select count(*) from restored_projects)::int as restored_projects,
  (select count(*) from restored_social_comments)::int as restored_social_comments,
  (select count(*) from restored_project_comments)::int as restored_project_comments,
  (select count(*) from restored_accounts)::int as restored_accounts,
  (select json_agg(email) from restored_accounts) as restored_account_emails;
```

## 22. Security Events

```sql
select se.*, p.email, p.username
from public.security_events se
left join public.profiles p on p.id = se.user_id
order by se.created_at desc
limit 200;
```

## 23. Blocked Users

```sql
select b.*, blocker.email as blocker_email, blocked.email as blocked_email
from public.blocked_users b
left join public.profiles blocker on blocker.id = b.blocker_id
left join public.profiles blocked on blocked.id = b.blocked_id
order by b.created_at desc;
```

Remove a block:

```sql
delete from public.blocked_users
where blocker_id = 'BLOCKER_USER_ID_HERE'
  and blocked_id = 'BLOCKED_USER_ID_HERE';
```

## 24. Moderation Notifications

```sql
select n.id, n.created_at, p.email, p.username, n.title, n.body, n.category, n.action_route, n.is_read
from public.notifications n
left join public.profiles p on p.id = n.user_id
where n.category = 'moderation_action'
order by n.created_at desc;
```

## 25. Hide A Post For One User

This is personal hiding, not platform moderation.

```sql
insert into public.social_post_hidden_users (post_id, user_id)
values ('POST_ID_HERE', 'USER_ID_HERE')
on conflict (post_id, user_id)
do update set hidden_at = now();
```

Unhide for one user:

```sql
delete from public.social_post_hidden_users
where post_id = 'POST_ID_HERE'
  and user_id = 'USER_ID_HERE';
```

## 26. Delete-Or-Restore Own Soft Deleted Records

Restore one soft-deleted post:

```sql
update public.social_posts
set deleted_at = null, updated_at = now()
where id = 'POST_ID_HERE';
```

Restore one soft-deleted project:

```sql
update public.projects
set deleted_at = null, updated_at = now()
where id = 'PROJECT_ID_HERE';
```

Restore one soft-deleted social comment:

```sql
update public.social_post_comments
set deleted_at = null
where id = 'COMMENT_ID_HERE';
```

Restore one soft-deleted project comment:

```sql
update public.project_comments
set deleted_at = null
where id = 'COMMENT_ID_HERE';
```

## 27. Export Evidence Notes

For legal use:

- Prefer `select` queries first.
- Avoid hard deleting.
- Keep `moderation_actions` untouched.
- Use `removed` or `under_review` for content, not permanent deletes.
- Use `suspended` or `under_review` for accounts while investigating.
