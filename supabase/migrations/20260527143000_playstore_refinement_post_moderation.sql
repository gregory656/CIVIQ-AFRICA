begin;

create table if not exists public.social_post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'reported',
  created_at timestamptz not null default now(),
  unique (post_id, reporter_id)
);

create table if not exists public.social_post_hidden_users (
  post_id uuid not null references public.social_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_social_post_reports_post
  on public.social_post_reports (post_id, created_at desc);

create index if not exists idx_social_post_hidden_user
  on public.social_post_hidden_users (user_id, hidden_at desc);

alter table public.social_post_reports enable row level security;
alter table public.social_post_hidden_users enable row level security;

drop policy if exists "Users can report social posts" on public.social_post_reports;
create policy "Users can report social posts"
  on public.social_post_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "Users can read own hidden social posts" on public.social_post_hidden_users;
create policy "Users can read own hidden social posts"
  on public.social_post_hidden_users for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can hide own social post copies" on public.social_post_hidden_users;
create policy "Users can hide own social post copies"
  on public.social_post_hidden_users for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own hidden social post copies" on public.social_post_hidden_users;
create policy "Users can update own hidden social post copies"
  on public.social_post_hidden_users for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

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
where p.deleted_at is null
  and not exists (
    select 1
    from public.social_post_hidden_users hidden
    where hidden.post_id = p.id and hidden.user_id = auth.uid()
  );

grant insert on public.social_post_reports to authenticated;
grant select, insert, update on public.social_post_hidden_users to authenticated;
grant select on public.v_social_post_feed to authenticated;

commit;

