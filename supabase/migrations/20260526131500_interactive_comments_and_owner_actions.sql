begin;

alter table public.social_posts
  add column if not exists edited_at timestamptz;

alter table public.social_post_comments
  add column if not exists parent_comment_id uuid references public.social_post_comments(id) on delete cascade,
  add column if not exists edited_at timestamptz;

alter table public.project_comments
  add column if not exists parent_comment_id uuid references public.project_comments(id) on delete cascade,
  add column if not exists edited_at timestamptz;

create table if not exists public.social_post_comment_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  comment_id uuid not null references public.social_post_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, comment_id)
);

create table if not exists public.project_comment_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  comment_id uuid not null references public.project_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, comment_id)
);

create table if not exists public.social_post_comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.social_post_comments(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'reported',
  created_at timestamptz not null default now(),
  unique (comment_id, reporter_id)
);

create table if not exists public.project_comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.project_comments(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'reported',
  created_at timestamptz not null default now(),
  unique (comment_id, reporter_id)
);

alter table public.social_post_comment_likes enable row level security;
alter table public.project_comment_likes enable row level security;
alter table public.social_post_comment_reports enable row level security;
alter table public.project_comment_reports enable row level security;

drop policy if exists "Users can edit own social posts" on public.social_posts;
create policy "Users can edit own social posts"
  on public.social_posts for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists "Users can edit own social post comments" on public.social_post_comments;
create policy "Users can edit own social post comments"
  on public.social_post_comments for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists "Users can edit own project comments" on public.project_comments;
create policy "Users can edit own project comments"
  on public.project_comments for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists "Users can read social comment likes" on public.social_post_comment_likes;
create policy "Users can read social comment likes"
  on public.social_post_comment_likes for select
  to authenticated
  using (true);

drop policy if exists "Users can like social comments" on public.social_post_comment_likes;
create policy "Users can like social comments"
  on public.social_post_comment_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can unlike social comments" on public.social_post_comment_likes;
create policy "Users can unlike social comments"
  on public.social_post_comment_likes for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read project comment likes" on public.project_comment_likes;
create policy "Users can read project comment likes"
  on public.project_comment_likes for select
  to authenticated
  using (true);

drop policy if exists "Users can like project comments" on public.project_comment_likes;
create policy "Users can like project comments"
  on public.project_comment_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can unlike project comments" on public.project_comment_likes;
create policy "Users can unlike project comments"
  on public.project_comment_likes for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can report social comments" on public.social_post_comment_reports;
create policy "Users can report social comments"
  on public.social_post_comment_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "Users can report project comments" on public.project_comment_reports;
create policy "Users can report project comments"
  on public.project_comment_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create or replace function public.toggle_social_comment_like(target_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.social_post_comment_likes
    where user_id = auth.uid() and comment_id = target_comment_id
  ) then
    delete from public.social_post_comment_likes
    where user_id = auth.uid() and comment_id = target_comment_id;
  else
    insert into public.social_post_comment_likes (user_id, comment_id)
    values (auth.uid(), target_comment_id);
  end if;
end;
$$;

create or replace function public.toggle_project_comment_like(target_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.project_comment_likes
    where user_id = auth.uid() and comment_id = target_comment_id
  ) then
    delete from public.project_comment_likes
    where user_id = auth.uid() and comment_id = target_comment_id;
  else
    insert into public.project_comment_likes (user_id, comment_id)
    values (auth.uid(), target_comment_id);
  end if;
end;
$$;

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
    where r.parent_comment_id = c.id and r.deleted_at is null
  ) as reply_count,
  exists (
    select 1
    from public.social_post_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked
from public.social_post_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null;

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
    where r.parent_comment_id = c.id and r.deleted_at is null
  ) as reply_count,
  exists (
    select 1
    from public.project_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked
from public.project_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null;

grant select on public.v_social_post_comments to authenticated;
grant select on public.v_project_comments to authenticated;
grant select, insert, delete on public.social_post_comment_likes to authenticated;
grant select, insert, delete on public.project_comment_likes to authenticated;
grant insert on public.social_post_comment_reports to authenticated;
grant insert on public.project_comment_reports to authenticated;
grant execute on function public.toggle_social_comment_like(uuid) to authenticated;
grant execute on function public.toggle_project_comment_like(uuid) to authenticated;

commit;
