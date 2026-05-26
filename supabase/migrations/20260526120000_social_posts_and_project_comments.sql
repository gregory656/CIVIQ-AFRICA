begin;

create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles(id) on delete set null,
  body text not null,
  image_url text,
  like_count int not null default 0,
  comment_count int not null default 0,
  share_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.social_post_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.social_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.social_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.project_comments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_social_posts_feed
  on public.social_posts (deleted_at, created_at desc);

create index if not exists idx_social_post_comments_lookup
  on public.social_post_comments (post_id, deleted_at, created_at desc);

create index if not exists idx_project_comments_lookup
  on public.project_comments (project_id, deleted_at, created_at desc);

alter table public.social_posts enable row level security;
alter table public.social_post_likes enable row level security;
alter table public.social_post_comments enable row level security;
alter table public.project_comments enable row level security;

drop policy if exists "Social posts are readable by authenticated users" on public.social_posts;
create policy "Social posts are readable by authenticated users"
  on public.social_posts for select
  to authenticated
  using (deleted_at is null);

drop policy if exists "Users can create social posts" on public.social_posts;
create policy "Users can create social posts"
  on public.social_posts for insert
  to authenticated
  with check (auth.uid() = author_id);

drop policy if exists "Users can edit own social posts" on public.social_posts;
create policy "Users can edit own social posts"
  on public.social_posts for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists "Social post likes are readable by owners" on public.social_post_likes;
create policy "Social post likes are readable by owners"
  on public.social_post_likes for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can like social posts" on public.social_post_likes;
create policy "Users can like social posts"
  on public.social_post_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can unlike social posts" on public.social_post_likes;
create policy "Users can unlike social posts"
  on public.social_post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Social post comments are readable" on public.social_post_comments;
create policy "Social post comments are readable"
  on public.social_post_comments for select
  to authenticated
  using (deleted_at is null);

drop policy if exists "Users can comment on social posts" on public.social_post_comments;
create policy "Users can comment on social posts"
  on public.social_post_comments for insert
  to authenticated
  with check (auth.uid() = author_id);

drop policy if exists "Project comments are readable" on public.project_comments;
create policy "Project comments are readable"
  on public.project_comments for select
  to authenticated
  using (deleted_at is null);

drop policy if exists "Users can comment on projects" on public.project_comments;
create policy "Users can comment on projects"
  on public.project_comments for insert
  to authenticated
  with check (auth.uid() = author_id);

create or replace function public.recalculate_social_post_counts(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.social_posts
  set
    like_count = (
      select count(*)::int
      from public.social_post_likes
      where post_id = target_post_id
    ),
    comment_count = (
      select count(*)::int
      from public.social_post_comments
      where post_id = target_post_id and deleted_at is null
    ),
    updated_at = now()
  where id = target_post_id;
end;
$$;

create or replace function public.toggle_social_post_like(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.social_post_likes
    where user_id = auth.uid() and post_id = target_post_id
  ) then
    delete from public.social_post_likes
    where user_id = auth.uid() and post_id = target_post_id;
  else
    insert into public.social_post_likes (user_id, post_id)
    values (auth.uid(), target_post_id);
  end if;

  perform public.recalculate_social_post_counts(target_post_id);
end;
$$;

create or replace function public.increment_social_post_share(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.social_posts
  set share_count = share_count + 1, updated_at = now()
  where id = target_post_id;
end;
$$;

create or replace function public.refresh_social_post_counts_after_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post_id uuid;
begin
  target_post_id := case
    when tg_op = 'DELETE' then old.post_id
    else new.post_id
  end;
  perform public.recalculate_social_post_counts(target_post_id);
  return null;
end;
$$;

drop trigger if exists refresh_social_post_counts_on_comment
  on public.social_post_comments;

create trigger refresh_social_post_counts_on_comment
  after insert or update or delete on public.social_post_comments
  for each row execute function public.refresh_social_post_counts_after_comment();

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
  ) as viewer_has_liked
from public.social_posts p
left join public.profiles profile on profile.id = p.author_id
where p.deleted_at is null;

drop view if exists public.v_project_feed;

create view public.v_project_feed as
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
    where pc.project_id = p.id and pc.deleted_at is null
  ) as comment_count,
  p.score,
  p.created_at,
  pr.username as creator_username,
  pr.avatar_url as creator_avatar_url,
  pr.is_verified as creator_is_verified
from public.projects p
left join public.counties c on c.id = p.county_id
left join public.subcounties s on s.id = p.subcounty_id
left join public.profiles pr on pr.id = p.creator_id
where p.deleted_at is null
  and p.verification_status <> 'flagged';

grant select, insert, update on public.social_posts to authenticated;
grant select, insert, delete on public.social_post_likes to authenticated;
grant select, insert on public.social_post_comments to authenticated;
grant select, insert on public.project_comments to authenticated;
grant select on public.v_social_post_feed to authenticated;
grant select on public.v_project_feed to authenticated;
grant execute on function public.toggle_social_post_like(uuid) to authenticated;
grant execute on function public.increment_social_post_share(uuid) to authenticated;

commit;
