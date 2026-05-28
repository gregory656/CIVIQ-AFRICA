begin;

update public.profiles
set
  role = 'super_admin',
  is_verified = true,
  verification_type = 'siviq_team',
  role_label = 'SIVIQ Super Admin',
  verified_at = coalesce(verified_at, now()),
  updated_at = now()
where lower(email) = lower('adminsiviq@gmail.com');

update public.profiles
set
  role = 'moderator',
  is_verified = true,
  verification_type = 'siviq_team',
  role_label = 'SIVIQ Moderator',
  verified_at = coalesce(verified_at, now()),
  updated_at = now()
where lower(email) = lower('gregorystephen2006@gmail.com');

drop function if exists public.discover_civiq_profiles();

create or replace function public.discover_civiq_profiles()
returns table (
  id uuid,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text,
  role text
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.civiq_code,
    p.avatar_url,
    p.is_verified,
    p.role_label,
    p.role
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and not exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = p.id
    )
  order by
    case p.role
      when 'super_admin' then 0
      when 'admin' then 1
      when 'moderator' then 2
      else 3
    end,
    p.is_verified desc,
    p.username nulls last,
    p.created_at desc;
$$;

create or replace view public.v_social_post_feed as
select
  p.id,
  p.author_id,
  p.body,
  p.image_url,
  p.like_count,
  p.comment_count,
  p.share_count,
  p.created_at,
  profile.username as author_username,
  profile.avatar_url as author_avatar_url,
  profile.is_verified as author_is_verified,
  exists (
    select 1
    from public.social_post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  p.moderation_status,
  profile.role as author_role
from public.social_posts p
left join public.profiles profile on profile.id = p.author_id
where p.deleted_at is null
  and p.moderation_status = 'active'
  and not exists (
    select 1
    from public.social_post_hidden_users hidden
    where hidden.post_id = p.id and hidden.user_id = auth.uid()
  );

create or replace view public.v_project_feed as
select
  p.id,
  p.creator_id,
  p.title,
  p.description,
  p.project_type,
  p.county_id,
  c.name as county_name,
  p.subcounty_id,
  s.name as subcounty_name,
  p.location_name,
  p.image_url,
  p.verification_status,
  p.approval_count,
  p.disapproval_count,
  (
    select count(*)::int
    from public.project_comments pc
    where pc.project_id = p.id
      and pc.deleted_at is null
      and pc.moderation_status = 'active'
  ) as comment_count,
  p.score,
  p.created_at,
  pr.username as creator_username,
  pr.avatar_url as creator_avatar_url,
  pr.is_verified as creator_is_verified,
  p.moderation_status,
  pr.role as creator_role
from public.projects p
left join public.counties c on c.id = p.county_id
left join public.subcounties s on s.id = p.subcounty_id
left join public.profiles pr on pr.id = p.creator_id
where p.deleted_at is null
  and p.verification_status <> 'flagged'
  and p.moderation_status = 'active';

create or replace view public.v_social_post_comments as
select
  c.id,
  c.post_id,
  c.parent_comment_id,
  c.author_id,
  c.body,
  c.created_at,
  c.edited_at,
  p.username as author_username,
  p.avatar_url as author_avatar_url,
  p.is_verified as author_is_verified,
  (
    select count(*)::int
    from public.social_post_comment_likes l
    where l.comment_id = c.id
  ) as like_count,
  (
    select count(*)::int
    from public.social_post_comments r
    where r.parent_comment_id = c.id
      and r.deleted_at is null
      and r.moderation_status = 'active'
  ) as reply_count,
  exists (
    select 1
    from public.social_post_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  c.moderation_status,
  p.role as author_role
from public.social_post_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null
  and c.moderation_status = 'active';

create or replace view public.v_project_comments as
select
  c.id,
  c.project_id,
  c.parent_comment_id,
  c.author_id,
  c.body,
  c.created_at,
  c.edited_at,
  p.username as author_username,
  p.avatar_url as author_avatar_url,
  p.is_verified as author_is_verified,
  (
    select count(*)::int
    from public.project_comment_likes l
    where l.comment_id = c.id
  ) as like_count,
  (
    select count(*)::int
    from public.project_comments r
    where r.parent_comment_id = c.id
      and r.deleted_at is null
      and r.moderation_status = 'active'
  ) as reply_count,
  exists (
    select 1
    from public.project_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  c.moderation_status,
  p.role as author_role
from public.project_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null
  and c.moderation_status = 'active';

grant execute on function public.discover_civiq_profiles() to authenticated;
grant select on public.v_social_post_feed to authenticated;
grant select on public.v_project_feed to authenticated;
grant select on public.v_social_post_comments to authenticated;
grant select on public.v_project_comments to authenticated;

commit;
