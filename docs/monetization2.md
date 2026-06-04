# Monetization Analytics Implementation

Implemented on June 4, 2026.

## What Was Implemented

This phase adds privacy-safe monetization foundations without collecting exact age, contacts, SMS history, installed apps, constant GPS, or browsing history outside SIVIQ.

The implemented pieces are:

- Age group collection during onboarding.
- Interest selection during onboarding, limited to 5 interests.
- Supabase storage for `age_group`, `interests`, and `user_interests`.
- Global search analytics in `search_history`.
- Recent search UX backed by both local device JSON and Supabase.
- Weekly analytics snapshot tables for searches, interests, and demographics.
- Scheduled Sunday monetization analytics job after the rankings job.
- Admin notification when weekly analytics are ready.
- Real ad system tables: `ads`, `ad_targets`, and `ad_events`.
- Personalized Discover sponsored content from Supabase, not hardcoded ads.
- Ad impression and click tracking.
- Discover sections for Sponsored Content, People You May Know, Trending Searches, and Trending Topics.

## Flutter Files

- `lib/features/onboarding/presentation/screens/profile_setup_screen.dart`
  - Adds the `Age group` dropdown.
  - Adds interest chips from the Supabase `interests` table.
  - Enforces "choose up to 5" in the UI.
  - Saves profile `age_group`.
  - Saves selected interests to `user_interests`.

- `lib/features/profile/data/profile_repository.dart`
  - Adds `ageGroup` to `CiviqProfile`.
  - Adds `ageGroup` to `upsertProfile`.

- `lib/features/monetization/data/monetization_repository.dart`
  - Fetches interests.
  - Saves user interests.
  - Records searches locally and remotely.
  - Reads, removes, and clears recent searches.
  - Fetches personalized ads using `get_personalized_ads`.
  - Records ad impressions/clicks using `record_ad_event`.
  - Fetches public latest trending searches using `get_latest_weekly_search_trends`.

- `lib/features/home/presentation/screens/app_shell.dart`
  - Records global searches after a short pause.
  - Shows Recent Searches when the search field is focused and empty.
  - Supports removing one recent search or clearing all.

- `lib/features/home/presentation/screens/home_feed_screen.dart`
  - Discover now shows sponsored content, people, trending searches, and trending topics.
  - Sponsored ads open real destination URLs and record clicks.
  - Ad cards record impressions when rendered.

## Migration

Migration added:

`supabase/migrations/20260604140000_monetization_analytics_ads.sql`

## Database Changes

### Profiles

Adds:

```sql
alter table public.profiles
  add column if not exists age_group text;
```

Allowed values:

- `under_18`
- `18_24`
- `25_34`
- `35_44`
- `45_54`
- `55_64`
- `65_plus`
- `prefer_not_to_say`

Exact age and date of birth are not collected.

### Interests

```sql
create table public.interests (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  created_at timestamptz not null default now()
);
```

Seeded interests:

- Infrastructure
- Roads
- Education
- Healthcare
- Agriculture
- Technology
- Business
- Environment
- Governance
- Jobs & Youth
- Sports
- Community Projects

### User Interests

```sql
create table public.user_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  interest_id uuid not null references public.interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, interest_id)
);
```

Users can manage only their own interest rows. Admins can read all.

### Search History

```sql
create table public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  search_term text not null,
  search_type text,
  created_at timestamptz not null default now()
);
```

The app records global searches with `search_type = 'global'`.

### Weekly Snapshot Tables

Admin-only tables:

- `weekly_search_trends`
- `weekly_interest_trends`
- `weekly_demographics`

The app does not directly read these tables for normal users. It uses:

```sql
select * from public.get_latest_weekly_search_trends(10);
```

This keeps admin analytics private while allowing Discover to show latest public trending searches.

### Ads

```sql
create table public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  image_url text,
  destination_url text,
  category text,
  minimum_age_group text not null default 'under_18',
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Ad Targeting

```sql
create table public.ad_targets (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads(id) on delete cascade,
  age_group text,
  county text,
  interest text,
  created_at timestamptz not null default now()
);
```

Target rows are optional. Ads with no target rows can be shown broadly, still respecting active state and minimum age rules.

### Ad Events

```sql
create table public.ad_events (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('impression', 'click')),
  created_at timestamptz not null default now()
);
```

## Minor Protection

`get_personalized_ads` blocks categories for `under_18` users:

- betting
- alcohol
- adult
- adult products
- loans

It also respects `minimum_age_group`.

## Weekly Job

Existing rankings run at Saturday 21:00 UTC, which is Sunday 00:00 in Africa/Nairobi.

This migration schedules monetization analytics at Saturday 21:20 UTC, which is Sunday 00:20 Africa/Nairobi:

```sql
select cron.schedule(
  'siviq_weekly_monetization_analytics_job',
  '20 21 * * 6',
  'select public.execute_weekly_monetization_analytics();'
);
```

The function snapshots:

- Top 100 searches from the last 7 days.
- Top selected interests.
- Demographics by age group and county.

It also creates admin notifications:

```text
Weekly Analytics Report Ready
Top Search: ...
Top Age Group: ...
Fastest Growing Interest: ...
```

## Useful Admin Queries

Top weekly searches:

```sql
select *
from public.weekly_search_trends
where snapshot_week = (
  select max(snapshot_week) from public.weekly_search_trends
)
order by rank;
```

Top weekly interests:

```sql
select *
from public.weekly_interest_trends
where snapshot_week = (
  select max(snapshot_week) from public.weekly_interest_trends
)
order by rank;
```

Weekly demographics:

```sql
select *
from public.weekly_demographics
where snapshot_week = (
  select max(snapshot_week) from public.weekly_demographics
)
order by user_count desc;
```

Ad performance:

```sql
select
  a.id,
  a.title,
  count(*) filter (where e.event_type = 'impression') as impressions,
  count(*) filter (where e.event_type = 'click') as clicks,
  round(
    100.0 * count(*) filter (where e.event_type = 'click')
    / nullif(count(*) filter (where e.event_type = 'impression'), 0),
    2
  ) as ctr_percent
from public.ads a
left join public.ad_events e on e.ad_id = a.id
group by a.id, a.title
order by impressions desc;
```

Create a real ad:

```sql
insert into public.ads (
  title,
  description,
  image_url,
  destination_url,
  category,
  minimum_age_group,
  is_active
)
values (
  'County Innovation Forum',
  'Register for a civic technology and youth jobs forum.',
  'https://example.com/forum.jpg',
  'https://example.com/register',
  'technology',
  '18_24',
  true
);
```

Target that ad:

```sql
insert into public.ad_targets (ad_id, age_group, county, interest)
values
  ('AD_UUID_HERE', '18_24', 'Nairobi', 'Technology'),
  ('AD_UUID_HERE', '25_34', 'Nairobi', 'Business');
```

Run weekly analytics manually:

```sql
select public.execute_weekly_monetization_analytics();
```

## RLS Summary

- Users can read and manage only their own `user_interests`.
- Users can insert/read/delete their own `search_history`.
- Weekly admin analytics tables are visible only to `admin` and `super_admin`.
- Active ads are readable by authenticated users.
- Ad targeting rows are admin-managed.
- Ad events are inserted by authenticated users and read by admins.
- Personalized ad matching runs through security-definer RPCs.

## Privacy Notes

This implementation intentionally does not collect:

- exact age
- date of birth
- contacts
- SMS history
- installed apps
- constant precise GPS
- browsing history outside SIVIQ

The monetization foundation is built from transparent first-party signals:

- age group
- selected interests
- county/subcounty already collected for civic features
- in-app search terms
- ad impressions and clicks
