begin;

alter table public.profiles
  add column if not exists age_group text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_age_group_check'
  ) then
    alter table public.profiles
      add constraint profiles_age_group_check
      check (
        age_group is null
        or age_group in (
          'under_18',
          '18_24',
          '25_34',
          '35_44',
          '45_54',
          '55_64',
          '65_plus',
          'prefer_not_to_say'
        )
      );
  end if;
end $$;

create table if not exists public.interests (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  interest_id uuid not null references public.interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, interest_id)
);

create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  search_term text not null,
  search_type text,
  created_at timestamptz not null default now()
);

create table if not exists public.weekly_search_trends (
  snapshot_week date not null,
  rank int not null,
  search_term text not null,
  search_type text,
  search_count int not null,
  created_at timestamptz not null default now(),
  primary key (snapshot_week, rank)
);

create table if not exists public.weekly_interest_trends (
  snapshot_week date not null,
  rank int not null,
  interest_id uuid references public.interests(id) on delete set null,
  interest_name text not null,
  selected_count int not null,
  created_at timestamptz not null default now(),
  primary key (snapshot_week, rank)
);

create table if not exists public.weekly_demographics (
  id uuid primary key default gen_random_uuid(),
  snapshot_week date not null,
  age_group text not null,
  county_id int references public.counties(id) on delete set null,
  county_name text,
  user_count int not null,
  active_searches int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  image_url text,
  destination_url text,
  category text,
  minimum_age_group text not null default 'under_18'
    check (minimum_age_group in (
      'under_18',
      '18_24',
      '25_34',
      '35_44',
      '45_54',
      '55_64',
      '65_plus',
      'prefer_not_to_say'
    )),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ad_targets (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads(id) on delete cascade,
  age_group text check (age_group in (
    'under_18',
    '18_24',
    '25_34',
    '35_44',
    '45_54',
    '55_64',
    '65_plus',
    'prefer_not_to_say'
  )),
  county text,
  interest text,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_events (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('impression', 'click')),
  created_at timestamptz not null default now()
);

create index if not exists idx_profiles_age_group
  on public.profiles (age_group);
create index if not exists idx_user_interests_user
  on public.user_interests (user_id);
create index if not exists idx_search_history_user_created
  on public.search_history (user_id, created_at desc);
create index if not exists idx_search_history_term_created
  on public.search_history (lower(search_term), created_at desc);
create index if not exists idx_ads_active_created
  on public.ads (is_active, created_at desc);
create index if not exists idx_ad_targets_ad
  on public.ad_targets (ad_id);
create index if not exists idx_ad_targets_lookup
  on public.ad_targets (age_group, county, interest);
create index if not exists idx_ad_events_ad_type_created
  on public.ad_events (ad_id, event_type, created_at desc);
create index if not exists idx_weekly_demographics_snapshot
  on public.weekly_demographics (snapshot_week, age_group, county_id);

alter table public.interests enable row level security;
alter table public.user_interests enable row level security;
alter table public.search_history enable row level security;
alter table public.weekly_search_trends enable row level security;
alter table public.weekly_interest_trends enable row level security;
alter table public.weekly_demographics enable row level security;
alter table public.ads enable row level security;
alter table public.ad_targets enable row level security;
alter table public.ad_events enable row level security;

drop policy if exists "Interests are readable by authenticated users" on public.interests;
create policy "Interests are readable by authenticated users"
  on public.interests for select
  to authenticated
  using (true);

drop policy if exists "Admins can manage interests" on public.interests;
create policy "Admins can manage interests"
  on public.interests for all
  to authenticated
  using (public.is_siviq_admin())
  with check (public.is_siviq_admin());

drop policy if exists "Users can read own interests" on public.user_interests;
create policy "Users can read own interests"
  on public.user_interests for select
  to authenticated
  using (user_id = auth.uid() or public.is_siviq_admin());

drop policy if exists "Users can manage own interests" on public.user_interests;
create policy "Users can manage own interests"
  on public.user_interests for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users can read own search history" on public.search_history;
create policy "Users can read own search history"
  on public.search_history for select
  to authenticated
  using (user_id = auth.uid() or public.is_siviq_admin());

drop policy if exists "Users can insert own searches" on public.search_history;
create policy "Users can insert own searches"
  on public.search_history for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users can delete own searches" on public.search_history;
create policy "Users can delete own searches"
  on public.search_history for delete
  to authenticated
  using (user_id = auth.uid() or public.is_siviq_admin());

drop policy if exists "Admins can read weekly search trends" on public.weekly_search_trends;
create policy "Admins can read weekly search trends"
  on public.weekly_search_trends for select
  to authenticated
  using (public.is_siviq_admin());

drop policy if exists "Admins can read weekly interest trends" on public.weekly_interest_trends;
create policy "Admins can read weekly interest trends"
  on public.weekly_interest_trends for select
  to authenticated
  using (public.is_siviq_admin());

drop policy if exists "Admins can read weekly demographics" on public.weekly_demographics;
create policy "Admins can read weekly demographics"
  on public.weekly_demographics for select
  to authenticated
  using (public.is_siviq_admin());

drop policy if exists "Active ads are readable by authenticated users" on public.ads;
create policy "Active ads are readable by authenticated users"
  on public.ads for select
  to authenticated
  using (is_active or public.is_siviq_admin());

drop policy if exists "Admins can manage ads" on public.ads;
create policy "Admins can manage ads"
  on public.ads for all
  to authenticated
  using (public.is_siviq_admin())
  with check (public.is_siviq_admin());

drop policy if exists "Ad targets are admin readable" on public.ad_targets;
create policy "Ad targets are admin readable"
  on public.ad_targets for select
  to authenticated
  using (public.is_siviq_admin());

drop policy if exists "Admins can manage ad targets" on public.ad_targets;
create policy "Admins can manage ad targets"
  on public.ad_targets for all
  to authenticated
  using (public.is_siviq_admin())
  with check (public.is_siviq_admin());

drop policy if exists "Admins can read ad events" on public.ad_events;
create policy "Admins can read ad events"
  on public.ad_events for select
  to authenticated
  using (public.is_siviq_admin());

drop policy if exists "Users can insert own ad events" on public.ad_events;
create policy "Users can insert own ad events"
  on public.ad_events for insert
  to authenticated
  with check (user_id = auth.uid());

insert into public.interests (name)
values
  ('Infrastructure'),
  ('Roads'),
  ('Education'),
  ('Healthcare'),
  ('Agriculture'),
  ('Technology'),
  ('Business'),
  ('Environment'),
  ('Governance'),
  ('Jobs & Youth'),
  ('Sports'),
  ('Community Projects')
on conflict (name) do nothing;

create or replace function public.age_group_rank(group_value text)
returns int
language sql
immutable
set search_path = public
as $$
  select case group_value
    when 'under_18' then 0
    when '18_24' then 18
    when '25_34' then 25
    when '35_44' then 35
    when '45_54' then 45
    when '55_64' then 55
    when '65_plus' then 65
    else null
  end;
$$;

create or replace function public.get_personalized_ads(page_limit int default 5)
returns table (
  id uuid,
  title text,
  description text,
  image_url text,
  destination_url text,
  category text
)
language sql
stable
security definer
set search_path = public
as $$
  with viewer as (
    select
      p.id,
      p.age_group,
      c.name as county_name
    from public.profiles p
    left join public.counties c on c.id = p.county_id
    where p.id = auth.uid()
  ),
  viewer_interests as (
    select i.name
    from public.user_interests ui
    join public.interests i on i.id = ui.interest_id
    where ui.user_id = auth.uid()
  )
  select
    a.id,
    a.title,
    a.description,
    a.image_url,
    a.destination_url,
    a.category
  from public.ads a
  cross join viewer v
  where a.is_active
    and (
      v.age_group = 'prefer_not_to_say'
      or public.age_group_rank(v.age_group) is null
      or public.age_group_rank(a.minimum_age_group) is null
      or public.age_group_rank(v.age_group) >= public.age_group_rank(a.minimum_age_group)
    )
    and not (
      v.age_group = 'under_18'
      and lower(coalesce(a.category, '')) in ('betting', 'alcohol', 'adult', 'adult products', 'loans')
    )
    and (
      not exists (select 1 from public.ad_targets at where at.ad_id = a.id)
      or exists (
        select 1
        from public.ad_targets at
        where at.ad_id = a.id
          and (at.age_group is null or at.age_group = v.age_group)
          and (at.county is null or lower(at.county) = lower(coalesce(v.county_name, '')))
          and (
            at.interest is null
            or exists (
              select 1
              from viewer_interests vi
              where lower(vi.name) = lower(at.interest)
            )
          )
      )
    )
  order by a.created_at desc
  limit greatest(1, least(coalesce(page_limit, 5), 20));
$$;

create or replace function public.record_ad_event(target_ad_id uuid, event_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if event_kind not in ('impression', 'click') then
    raise exception 'Invalid ad event.';
  end if;

  if not exists (
    select 1 from public.ads
    where id = target_ad_id
      and is_active
  ) then
    raise exception 'Ad is not active.';
  end if;

  insert into public.ad_events (ad_id, user_id, event_type)
  values (target_ad_id, auth.uid(), event_kind);
end;
$$;

create or replace function public.get_latest_weekly_search_trends(page_limit int default 10)
returns table (
  search_term text,
  search_count int,
  rank int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    w.search_term,
    w.search_count,
    w.rank
  from public.weekly_search_trends w
  where w.snapshot_week = (
    select max(snapshot_week)
    from public.weekly_search_trends
  )
  order by w.rank
  limit greatest(1, least(coalesce(page_limit, 10), 25));
$$;

drop function if exists public.get_profile_summary(uuid);
create or replace function public.get_profile_summary(target_user_id uuid)
returns table (
  id uuid,
  email text,
  display_name text,
  username text,
  civiq_code text,
  bio text,
  avatar_url text,
  county_id int,
  subcounty_id int,
  age_group text,
  is_public boolean,
  show_online_status boolean,
  show_read_receipts boolean,
  allow_message_requests boolean,
  show_activity boolean,
  is_verified boolean,
  verification_type text,
  role_label text,
  role text,
  account_status text,
  suspension_until timestamptz,
  muted_until timestamptz,
  followers_count int,
  following_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.email,
    p.display_name,
    p.username,
    p.civiq_code,
    p.bio,
    p.avatar_url,
    p.county_id,
    p.subcounty_id,
    p.age_group,
    p.is_public,
    p.show_online_status,
    p.show_read_receipts,
    p.allow_message_requests,
    p.show_activity,
    p.is_verified,
    p.verification_type,
    p.role_label,
    p.role,
    p.account_status,
    p.suspension_until,
    p.muted_until,
    (
      select count(*)::int
      from public.follows f
      where f.following_id = p.id
    ) as followers_count,
    (
      select count(*)::int
      from public.follows f
      where f.follower_id = p.id
    ) as following_count
  from public.profiles p
  where auth.uid() is not null
    and p.id = target_user_id
    and p.deleted_at is null;
$$;

create or replace function public.execute_weekly_monetization_analytics()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_week date := (now() at time zone 'Africa/Nairobi')::date;
  top_search text;
  top_age text;
  top_interest text;
begin
  delete from public.weekly_search_trends where snapshot_week = target_week;
  delete from public.weekly_interest_trends where snapshot_week = target_week;
  delete from public.weekly_demographics where snapshot_week = target_week;

  insert into public.weekly_search_trends (
    snapshot_week,
    rank,
    search_term,
    search_type,
    search_count
  )
  select
    target_week,
    row_number() over (order by count(*) desc, lower(search_term))::int,
    search_term,
    search_type,
    count(*)::int
  from public.search_history
  where created_at >= now() - interval '7 days'
  group by search_term, search_type
  order by count(*) desc, lower(search_term)
  limit 100;

  insert into public.weekly_interest_trends (
    snapshot_week,
    rank,
    interest_id,
    interest_name,
    selected_count
  )
  select
    target_week,
    row_number() over (order by count(*) desc, i.name)::int,
    i.id,
    i.name,
    count(*)::int
  from public.user_interests ui
  join public.interests i on i.id = ui.interest_id
  group by i.id, i.name
  order by count(*) desc, i.name
  limit 100;

  insert into public.weekly_demographics (
    snapshot_week,
    age_group,
    county_id,
    county_name,
    user_count,
    active_searches
  )
  select
    target_week,
    coalesce(p.age_group, 'prefer_not_to_say'),
    p.county_id,
    c.name,
    count(distinct p.id)::int,
    count(sh.id)::int
  from public.profiles p
  left join public.counties c on c.id = p.county_id
  left join public.search_history sh
    on sh.user_id = p.id
    and sh.created_at >= now() - interval '7 days'
  where p.deleted_at is null
  group by coalesce(p.age_group, 'prefer_not_to_say'), p.county_id, c.name;

  select search_term into top_search
  from public.weekly_search_trends
  where snapshot_week = target_week
  order by rank
  limit 1;

  select age_group into top_age
  from public.weekly_demographics
  where snapshot_week = target_week
  order by user_count desc
  limit 1;

  select interest_name into top_interest
  from public.weekly_interest_trends
  where snapshot_week = target_week
  order by rank
  limit 1;

  insert into public.notifications (user_id, title, body, category, action_route)
  select
    p.id,
    'Weekly Analytics Report Ready',
    'Top Search: ' || coalesce(top_search, 'None yet') ||
      E'\nTop Age Group: ' || coalesce(top_age, 'None yet') ||
      E'\nFastest Growing Interest: ' || coalesce(top_interest, 'None yet'),
    'admin_analytics',
    '/home'
  from public.profiles p
  where p.role in ('admin', 'super_admin')
    and p.deleted_at is null;
end;
$$;

grant select on public.interests to authenticated;
grant select, insert, delete on public.user_interests to authenticated;
grant select, insert, delete on public.search_history to authenticated;
grant select on public.weekly_search_trends to authenticated;
grant select on public.weekly_interest_trends to authenticated;
grant select on public.weekly_demographics to authenticated;
grant select on public.ads to authenticated;
grant select on public.ad_targets to authenticated;
grant select, insert on public.ad_events to authenticated;
grant execute on function public.get_personalized_ads(int) to authenticated;
grant execute on function public.record_ad_event(uuid, text) to authenticated;
grant execute on function public.get_latest_weekly_search_trends(int) to authenticated;
revoke execute on function public.execute_weekly_monetization_analytics() from anon, authenticated;

select cron.unschedule('siviq_weekly_monetization_analytics_job')
where exists (
  select 1 from cron.job where jobname = 'siviq_weekly_monetization_analytics_job'
);

select cron.schedule(
  'siviq_weekly_monetization_analytics_job',
  '20 21 * * 6',
  'select public.execute_weekly_monetization_analytics();'
);

commit;
