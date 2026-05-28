begin;

alter table public.profiles
  add column if not exists role text not null default 'user'
    check (role in ('user', 'moderator', 'admin', 'super_admin')),
  add column if not exists account_status text not null default 'active'
    check (account_status in ('active', 'suspended', 'banned', 'under_review')),
  add column if not exists suspension_until timestamptz,
  add column if not exists muted_until timestamptz;

alter table public.social_posts
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'hidden', 'removed', 'under_review')),
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists moderated_reason text,
  add column if not exists moderated_at timestamptz;

alter table public.projects
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'hidden', 'removed', 'under_review')),
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists moderated_reason text,
  add column if not exists moderated_at timestamptz;

alter table public.social_post_comments
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'hidden', 'removed', 'under_review')),
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists moderated_reason text,
  add column if not exists moderated_at timestamptz;

alter table public.project_comments
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'hidden', 'removed', 'under_review')),
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists moderated_reason text,
  add column if not exists moderated_at timestamptz;

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid not null references public.profiles(id) on delete restrict,
  target_user_id uuid references public.profiles(id) on delete set null,
  target_project_id uuid references public.projects(id) on delete set null,
  target_post_id uuid references public.social_posts(id) on delete set null,
  target_comment_id uuid,
  target_comment_table text,
  action_type text not null,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  post_id uuid references public.social_posts(id) on delete set null,
  action_id uuid references public.moderation_actions(id) on delete set null,
  reason text not null,
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz
);

create index if not exists idx_profiles_role_status
  on public.profiles (role, account_status);

create index if not exists idx_profiles_status_suspension
  on public.profiles (account_status, suspension_until);

create index if not exists idx_social_posts_moderation
  on public.social_posts (moderation_status, deleted_at, created_at desc);

create index if not exists idx_projects_moderation
  on public.projects (moderation_status, deleted_at, created_at desc);

create index if not exists idx_moderation_actions_moderator
  on public.moderation_actions (moderator_id, created_at desc);

create index if not exists idx_moderation_actions_target_user
  on public.moderation_actions (target_user_id, created_at desc);

create index if not exists idx_moderation_appeals_user
  on public.moderation_appeals (user_id, created_at desc);

create index if not exists idx_moderation_appeals_status
  on public.moderation_appeals (status, created_at desc);

alter table public.moderation_actions enable row level security;
alter table public.moderation_appeals enable row level security;

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()),
    'user'
  );
$$;

create or replace function public.is_siviq_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_profile_role() in ('moderator', 'admin', 'super_admin')
    or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'service_role');
$$;

create or replace function public.is_siviq_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_profile_role() in ('admin', 'super_admin')
    or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'service_role');
$$;

create or replace function public.prevent_profile_verification_self_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;

  if public.is_siviq_admin() then
    return new;
  end if;

  if new.is_verified is distinct from old.is_verified
    or new.verified_at is distinct from old.verified_at
    or new.verified_by is distinct from old.verified_by
    or new.verification_type is distinct from old.verification_type
    or new.role_label is distinct from old.role_label
    or new.role is distinct from old.role
    or new.account_status is distinct from old.account_status
    or new.suspension_until is distinct from old.suspension_until
    or new.muted_until is distinct from old.muted_until then
    raise exception 'Only SIVIQ admins can update protected profile fields.';
  end if;

  return new;
end;
$$;

drop policy if exists "Moderators can read moderation actions" on public.moderation_actions;
create policy "Moderators can read moderation actions"
  on public.moderation_actions for select
  to authenticated
  using (
    public.is_siviq_moderator()
    or moderator_id = auth.uid()
    or target_user_id = auth.uid()
  );

drop policy if exists "Users can create own moderation appeals" on public.moderation_appeals;
create policy "Users can create own moderation appeals"
  on public.moderation_appeals for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own moderation appeals" on public.moderation_appeals;
create policy "Users can read own moderation appeals"
  on public.moderation_appeals for select
  to authenticated
  using (auth.uid() = user_id or public.is_siviq_moderator());

drop policy if exists "Moderators can review moderation appeals" on public.moderation_appeals;
create policy "Moderators can review moderation appeals"
  on public.moderation_appeals for update
  to authenticated
  using (public.is_siviq_moderator())
  with check (public.is_siviq_moderator());

drop policy if exists "Social posts are readable by authenticated users" on public.social_posts;
create policy "Social posts are readable by authenticated users"
  on public.social_posts for select
  to authenticated
  using (
    deleted_at is null
    and (
      moderation_status = 'active'
      or auth.uid() = author_id
      or public.is_siviq_moderator()
    )
  );

drop policy if exists "Projects are readable by authenticated users" on public.projects;
create policy "Projects are readable by authenticated users"
  on public.projects for select
  to authenticated
  using (
    deleted_at is null
    and verification_status <> 'flagged'
    and (
      moderation_status = 'active'
      or auth.uid() = creator_id
      or public.is_siviq_moderator()
    )
  );

create or replace function public.ensure_active_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  status text;
  suspension timestamptz;
  mute timestamptz;
begin
  select account_status, suspension_until, muted_until
    into status, suspension, mute
  from public.profiles
  where id = auth.uid();

  if status is null then
    raise exception 'Sign in again to continue.';
  end if;

  if status in ('suspended', 'banned', 'under_review') then
    if status = 'suspended' and suspension is not null and suspension <= now() then
      update public.profiles
      set account_status = 'active', suspension_until = null, updated_at = now()
      where id = auth.uid();
    else
      raise exception 'Your SIVIQ account is currently restricted.';
    end if;
  end if;

  if mute is not null and mute > now() then
    raise exception 'Your SIVIQ account is temporarily muted.';
  end if;

  return new;
end;
$$;

drop trigger if exists ensure_active_social_post_author on public.social_posts;
create trigger ensure_active_social_post_author
  before insert on public.social_posts
  for each row execute function public.ensure_active_account();

drop trigger if exists ensure_active_project_creator on public.projects;
create trigger ensure_active_project_creator
  before insert on public.projects
  for each row execute function public.ensure_active_account();

drop trigger if exists ensure_active_social_comment_author on public.social_post_comments;
create trigger ensure_active_social_comment_author
  before insert on public.social_post_comments
  for each row execute function public.ensure_active_account();

drop trigger if exists ensure_active_project_comment_author on public.project_comments;
create trigger ensure_active_project_comment_author
  before insert on public.project_comments
  for each row execute function public.ensure_active_account();

create or replace function public.notify_moderation_action(
  target_user_id uuid,
  action_title text,
  action_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_user_id is null then
    return;
  end if;

  insert into public.notifications (user_id, title, body, category, action_route)
  values (
    target_user_id,
    action_title,
    action_body,
    'moderation_action',
    '/legal/appeals'
  );
end;
$$;

create or replace function public.moderate_social_post(
  target_post_id uuid,
  new_status text,
  reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  target_author uuid;
  action_id uuid;
begin
  if not public.is_siviq_moderator() then
    raise exception 'Only SIVIQ moderators can moderate posts.';
  end if;

  if new_status not in ('hidden', 'removed', 'under_review', 'active') then
    raise exception 'Invalid moderation status.';
  end if;

  select author_id into target_author
  from public.social_posts
  where id = target_post_id;

  update public.social_posts
  set
    moderation_status = new_status,
    moderated_by = actor,
    moderated_reason = reason,
    moderated_at = now(),
    updated_at = now()
  where id = target_post_id;

  insert into public.moderation_actions (
    moderator_id, target_user_id, target_post_id, action_type, reason
  )
  values (actor, target_author, target_post_id, 'moderate_social_post', reason)
  returning id into action_id;

  perform public.notify_moderation_action(
    target_author,
    'Your SIVIQ post was reviewed',
    'Your post was marked ' || new_status || ' after review. If you believe this was a mistake, you may submit an appeal.'
  );

  return action_id;
end;
$$;

create or replace function public.moderate_project(
  target_project_id uuid,
  new_status text,
  reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  target_creator uuid;
  action_id uuid;
begin
  if not public.is_siviq_moderator() then
    raise exception 'Only SIVIQ moderators can moderate projects.';
  end if;

  if new_status not in ('hidden', 'removed', 'under_review', 'active') then
    raise exception 'Invalid moderation status.';
  end if;

  select creator_id into target_creator
  from public.projects
  where id = target_project_id;

  update public.projects
  set
    moderation_status = new_status,
    moderated_by = actor,
    moderated_reason = reason,
    moderated_at = now(),
    updated_at = now()
  where id = target_project_id;

  insert into public.moderation_actions (
    moderator_id, target_user_id, target_project_id, action_type, reason
  )
  values (actor, target_creator, target_project_id, 'moderate_project', reason)
  returning id into action_id;

  perform public.notify_moderation_action(
    target_creator,
    'Your SIVIQ project report was reviewed',
    'Your project report was marked ' || new_status || ' after review. If you believe this was a mistake, you may submit an appeal.'
  );

  return action_id;
end;
$$;

create or replace function public.moderate_social_comment(
  target_comment_id uuid,
  new_status text,
  reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  target_author uuid;
  action_id uuid;
begin
  if not public.is_siviq_moderator() then
    raise exception 'Only SIVIQ moderators can moderate comments.';
  end if;

  if new_status not in ('hidden', 'removed', 'under_review', 'active') then
    raise exception 'Invalid moderation status.';
  end if;

  select author_id into target_author
  from public.social_post_comments
  where id = target_comment_id;

  update public.social_post_comments
  set
    moderation_status = new_status,
    moderated_by = actor,
    moderated_reason = reason,
    moderated_at = now()
  where id = target_comment_id;

  insert into public.moderation_actions (
    moderator_id, target_user_id, target_comment_id, target_comment_table, action_type, reason
  )
  values (actor, target_author, target_comment_id, 'social_post_comments', 'moderate_social_comment', reason)
  returning id into action_id;

  perform public.notify_moderation_action(
    target_author,
    'Your SIVIQ comment was reviewed',
    'Your comment was marked ' || new_status || ' after review. If you believe this was a mistake, you may submit an appeal.'
  );

  return action_id;
end;
$$;

create or replace function public.moderate_project_comment(
  target_comment_id uuid,
  new_status text,
  reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  target_author uuid;
  action_id uuid;
begin
  if not public.is_siviq_moderator() then
    raise exception 'Only SIVIQ moderators can moderate comments.';
  end if;

  if new_status not in ('hidden', 'removed', 'under_review', 'active') then
    raise exception 'Invalid moderation status.';
  end if;

  select author_id into target_author
  from public.project_comments
  where id = target_comment_id;

  update public.project_comments
  set
    moderation_status = new_status,
    moderated_by = actor,
    moderated_reason = reason,
    moderated_at = now()
  where id = target_comment_id;

  insert into public.moderation_actions (
    moderator_id, target_user_id, target_comment_id, target_comment_table, action_type, reason
  )
  values (actor, target_author, target_comment_id, 'project_comments', 'moderate_project_comment', reason)
  returning id into action_id;

  perform public.notify_moderation_action(
    target_author,
    'Your SIVIQ comment was reviewed',
    'Your comment was marked ' || new_status || ' after review. If you believe this was a mistake, you may submit an appeal.'
  );

  return action_id;
end;
$$;

create or replace function public.moderate_user_account(
  target_user_id uuid,
  new_status text,
  reason text,
  until_at timestamptz default null,
  mute_until_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  action_id uuid;
begin
  if not public.is_siviq_moderator() then
    raise exception 'Only SIVIQ moderators can restrict accounts.';
  end if;

  if target_user_id = actor then
    raise exception 'Moderators cannot restrict their own account.';
  end if;

  if new_status not in ('active', 'suspended', 'banned', 'under_review') then
    raise exception 'Invalid account status.';
  end if;

  update public.profiles
  set
    account_status = new_status,
    suspension_until = case when new_status = 'suspended' then until_at else null end,
    muted_until = mute_until_at,
    updated_at = now()
  where id = target_user_id;

  insert into public.moderation_actions (
    moderator_id, target_user_id, action_type, reason,
    metadata
  )
  values (
    actor,
    target_user_id,
    'moderate_user_account',
    reason,
    jsonb_build_object(
      'account_status', new_status,
      'suspension_until', until_at,
      'muted_until', mute_until_at
    )
  )
  returning id into action_id;

  perform public.notify_moderation_action(
    target_user_id,
    'Your SIVIQ account status changed',
    'Your account was marked ' || new_status || ' after review. If you believe this was a mistake, you may submit an appeal.'
  );

  return action_id;
end;
$$;

create or replace function public.submit_moderation_appeal(
  appeal_reason text,
  target_project_id uuid default null,
  target_post_id uuid default null,
  target_action_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  appeal_id uuid;
begin
  insert into public.moderation_appeals (
    user_id, project_id, post_id, action_id, reason
  )
  values (
    auth.uid(), target_project_id, target_post_id, target_action_id, appeal_reason
  )
  returning id into appeal_id;

  return appeal_id;
end;
$$;

create or replace function public.refresh_project_rankings_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.moderation_status <> 'active'
    or new.deleted_at is not null
    or new.verification_status = 'flagged' then
    delete from public.leader_projects where project_id = new.id;
    return new;
  end if;

  delete from public.leader_projects where project_id = new.id;

  insert into public.leader_projects (leader_id, project_id, relationship_type)
  select l.id, new.id, 'jurisdiction'
  from public.leaders l
  where l.role = 'Governor'
    and l.county_id = new.county_id
  on conflict do nothing;

  insert into public.leader_projects (leader_id, project_id, relationship_type)
  select l.id, new.id, 'jurisdiction'
  from public.leaders l
  where l.role = 'MP'
    and l.subcounty_id = new.subcounty_id
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists refresh_project_rankings_visibility_after_moderation
  on public.projects;

create trigger refresh_project_rankings_visibility_after_moderation
  after update of moderation_status, deleted_at, verification_status, county_id, subcounty_id
  on public.projects
  for each row execute function public.refresh_project_rankings_visibility();

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
  p.moderation_status
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
  p.moderation_status
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
  c.moderation_status
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
  c.moderation_status
from public.project_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null
  and c.moderation_status = 'active';

create or replace view public.v_leader_project_links as
select
  lp.leader_id,
  lp.relationship_type,
  p.id as project_id,
  p.title,
  p.project_type,
  p.verification_status,
  p.approval_count,
  p.disapproval_count,
  p.score,
  p.county_id,
  c.name as county_name,
  p.subcounty_id,
  sc.name as subcounty_name,
  p.created_at
from public.leader_projects lp
join public.projects p on p.id = lp.project_id
left join public.counties c on c.id = p.county_id
left join public.subcounties sc on sc.id = p.subcounty_id
where p.deleted_at is null
  and p.verification_status <> 'flagged'
  and p.moderation_status = 'active';

grant select on public.moderation_actions to authenticated;
grant select, insert, update on public.moderation_appeals to authenticated;
grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.is_siviq_moderator() to authenticated;
grant execute on function public.moderate_social_post(uuid, text, text) to authenticated;
grant execute on function public.moderate_project(uuid, text, text) to authenticated;
grant execute on function public.moderate_social_comment(uuid, text, text) to authenticated;
grant execute on function public.moderate_project_comment(uuid, text, text) to authenticated;
grant execute on function public.moderate_user_account(uuid, text, text, timestamptz, timestamptz) to authenticated;
grant execute on function public.submit_moderation_appeal(text, uuid, uuid, uuid) to authenticated;
grant select on public.v_social_post_feed to authenticated;
grant select on public.v_project_feed to authenticated;
grant select on public.v_social_post_comments to authenticated;
grant select on public.v_project_comments to authenticated;
grant select on public.v_leader_project_links to authenticated;

commit;
