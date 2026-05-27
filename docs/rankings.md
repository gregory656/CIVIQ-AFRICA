# SIVIQ Rankings Engine Implementation Blueprint

This document defines how SIVIQ Africa should implement rankings safely, transparently, and incrementally. Rankings are the intelligence layer of the app, but they are also the most politically sensitive surface, so the MVP must be snapshot-based, explainable, abuse-resistant, and legally careful.

The core question rankings answer is:

> How effectively is a leader associated with successful public projects in their jurisdiction?

They must not answer:

> Who is most popular this week?

For launch, rankings should behave as SIVIQ sentiment analytics from project evidence, not as official truth.

## Current App Context

The existing database already has the important foundations:

- `profiles` with county/subcounty identity
- `counties` and `subcounties`
- `leaders` seeded for Governors and MPs
- `projects` with `project_type`, `verification_status`, county, and subcounty
- `project_votes` for approval/disapproval
- `project_reports` for moderation input
- `notifications` for in-app alerts

Because the app is still fresh and may only have 2 to 5 active accounts at first, the first release should not over-claim score accuracy. The Rankings tab should initially list leaders and allow filtering by county, constituency/subcounty, and leader name. Scores can be shown only after a leader has enough linked projects and eligible engagement.

## MVP Ranking Strategy

Phase 4 should be implemented in three controlled layers:

1. Data model and server calculation in Supabase.
2. Weekly immutable snapshot generation through `pg_cron`.
3. Frontend display that reads snapshots, never recalculates rankings live.

The app must never compute leaderboards on screen open. The Flutter client only queries a view or RPC backed by `leaderboard_snapshots`.

## Geographic and Legal Philosophy

Rankings must be normalized so Nairobi or any other high-density region cannot drown out smaller constituencies. Every score must include public metadata explaining the geography and data used.

Use log-dampened normalization:

```text
Wgeo = 1 / ln(e + eligible_local_users)
```

This reduces the marginal power of very large user populations while still allowing active communities to influence their own leaders.

Use jurisdiction weighting:

```text
local vote weight    = 1.00
external vote weight = 0.15
flagged user weight  = 0.00
```

Every public ranking screen must include this disclaimer:

```text
Rankings are generated from user-submitted SIVIQ reports and community engagement data. SIVIQ Africa is not affiliated with any government institution.
```

Do not market rankings as truth. Market them as community SIVIQ sentiment analytics.

## Required Database Additions

Do not create a separate project table. The app already uses `public.projects`. Add the relationship and snapshot tables around the existing model.

### Leader Projects

Projects can involve multiple leaders: an MP, a Governor, a Senator, county-national cooperation, or joint funding. Avoid hardcoding `1 project = 1 leader`.

```sql
create table if not exists public.leader_projects (
  leader_id uuid not null references public.leaders(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  relationship_type text not null default 'associated'
    check (relationship_type in ('associated', 'primary', 'supporting', 'oversight')),
  created_at timestamptz not null default now(),
  primary key (leader_id, project_id)
);
```

### Leaderboard Snapshots

Snapshots are insert-only weekly records. They freeze the score, formula version, coefficients, rank, movement, and metadata for auditability.

```sql
create table if not exists public.leaderboard_snapshots (
  id uuid primary key default gen_random_uuid(),
  leader_id uuid not null references public.leaders(id) on delete cascade,
  role text not null,
  county_id int not null references public.counties(id),
  subcounty_id int references public.subcounties(id),
  score numeric(12, 4) not null default 0,
  rank int not null,
  total_projects int not null default 0,
  completed_projects int not null default 0,
  stalled_projects int not null default 0,
  approval_count int not null default 0,
  disapproval_count int not null default 0,
  movement numeric(12, 4) not null default 0,
  is_top_twenty boolean not null default false,
  snapshot_week date not null,
  formula_version text not null default 'rankings_v1',
  demographic_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (leader_id, snapshot_week)
);
```

### Abuse and Audit Tables

Use a small server-side table for suspicious voting patterns. This lets the weekly job zero out abusive influence without deleting history.

```sql
create table if not exists public.ranking_security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  severity text not null default 'medium'
    check (severity in ('low', 'medium', 'high')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
```

### Indexes

```sql
create index if not exists idx_leader_projects_project
  on public.leader_projects(project_id);

create index if not exists idx_project_votes_project_created
  on public.project_votes(project_id, created_at desc);

create index if not exists idx_project_votes_user_created
  on public.project_votes(user_id, created_at desc);

create index if not exists idx_snapshots_region_week_rank
  on public.leaderboard_snapshots(role, county_id, subcounty_id, snapshot_week desc, rank);

create index if not exists idx_snapshots_leader_week
  on public.leaderboard_snapshots(leader_id, snapshot_week desc);
```

## Score Formula

### Per-Vote Trust Weight

Each vote starts with a user trust weight:

```text
new account under 7 days = 0.20
account 7-29 days        = 0.50
account 30+ days         = 1.00
velocity flagged account = 0.00
```

Then apply geography:

```text
same subcounty/county as project jurisdiction = 1.00
outside jurisdiction                          = 0.15
```

For MVP, the project jurisdiction should come from `projects.subcounty_id` when present, then `projects.county_id`.

### Project Sentiment Score

Use log normalization so large vote counts do not explode the score.

```text
weighted_approvals    = sum(approval vote trust x geography weight)
weighted_disapprovals = sum(disapproval vote trust x geography weight)

Wp = ln(1 + weighted_approvals) - ln(1 + weighted_disapprovals)
```

### Project Status Multiplier

Use the existing `projects.project_type` values:

```text
completed = 1.5
ongoing   = 1.0
stalled   = -2.0
excellent = 2.0
```

### Verification Multiplier

Use the existing `projects.verification_status` values:

```text
unverified           = 1.00
community_verified   = 1.25
officially_verified  = 1.50
flagged              = 0.00 and excluded from public rankings
```

### Geographic Dampening

```text
eligible_local_users = count(profiles in the leader/project jurisdiction)
Wgeo = 1 / ln(e + eligible_local_users)
```

When the user base is tiny, this prevents one or two accounts from creating a misleading national score. The frontend should show metadata such as:

```text
County active SIVIQ users: 300
Sub-county active SIVIQ users: 23
Log-dampened scaling factor: 0.2581
```

### Final Leader Score

```text
LeaderScore =
  sum(ProjectSentimentScore x StatusMultiplier x VerificationMultiplier x Wgeo)
  / greatest(total_linked_projects, 1)
```

This keeps leaders with many projects from automatically beating leaders with fewer but higher-quality projects.

## Weekly Supabase Runtime

Use Supabase Postgres as the trusted runtime. The client must not provide ranking scores.

### Cron Timing

The product requirement says Sunday at `00:00 EAT`. `pg_cron` uses the database/server timezone, and Supabase cron is normally easiest to reason about in UTC.

Kenya is `UTC+03:00`, so:

```text
Sunday 00:00 EAT = Saturday 21:00 UTC
```

Schedule:

```sql
select cron.schedule(
  'siviq_weekly_rankings_job',
  '0 21 * * 6',
  'select public.execute_weekly_rankings_snapshot();'
);
```

If the team decides to run at Sunday `00:00 UTC` instead, use:

```sql
'0 0 * * 0'
```

But the app should choose one and label it clearly in the UI.

### Weekly Job Flow

The function `public.execute_weekly_rankings_snapshot()` should:

1. Set `snapshot_week` to the EAT Sunday date.
2. Detect high-velocity voters and insert `ranking_security_events`.
3. Fetch all active leaders.
4. Fetch projects through `leader_projects`.
5. Calculate weighted project scores inside Postgres.
6. Average project scores into leader scores.
7. Rank leaders per role and region.
8. Compare with the previous snapshot to compute `movement`.
9. Insert immutable rows into `leaderboard_snapshots`.
10. Insert notifications for major rank events.

The function may safely delete and rerun only the same `snapshot_week` during development. Before production, lock this down to insert-only plus a privileged repair function, so historical weeks cannot be silently rewritten.

## Notification Triggers

Notifications should be generated by the weekly snapshot job, not the client.

Trigger notifications when:

- a leader enters the national top 20
- a leader enters the county top 10
- a leader has a major positive movement, for example `movement >= 5`
- a leader drops sharply, for example `movement <= -5`, but this should usually be internal/moderator-only at first
- suspicious voting activity is detected

For MVP, do not notify every user. Start with:

- project creators whose linked project helped a leader enter top 20
- moderators/admins for suspicious activity
- optionally users in the same county for positive top-20 changes later

Use the existing `notifications` table with category `rankings` or add the category if the current constraint does not allow it.

Example insert inside the weekly job:

```sql
insert into public.notifications (user_id, title, body, category, action_route)
select
  p.creator_id,
  'Ranking milestone',
  l.name || ' entered the SIVIQ top 20 this week.',
  'rankings',
  '/rankings/leaders/' || l.id::text
from public.leader_projects lp
join public.projects p on p.id = lp.project_id
join public.leaders l on l.id = lp.leader_id
join public.leaderboard_snapshots s on s.leader_id = l.id
where s.snapshot_week = target_week
  and s.is_top_twenty = true
  and p.creator_id is not null;
```

## Public Query Layer

Expose a read-only view for the Flutter app:

```sql
create or replace view public.v_leaderboard_snapshots as
select
  s.snapshot_week,
  s.rank,
  s.score,
  s.movement,
  s.role,
  s.total_projects,
  s.completed_projects,
  s.stalled_projects,
  s.approval_count,
  s.disapproval_count,
  s.is_top_twenty,
  s.demographic_metadata,
  l.id as leader_id,
  l.name as leader_name,
  l.party_name,
  c.id as county_id,
  c.name as county_name,
  sc.id as subcounty_id,
  sc.name as subcounty_name
from public.leaderboard_snapshots s
join public.leaders l on l.id = s.leader_id
join public.counties c on c.id = s.county_id
left join public.subcounties sc on sc.id = s.subcounty_id;
```

The frontend filters this view by:

- scope: National, County, Subcounty
- position: Governors, MPs, later MCAs/Senators
- time: This Week first, later monthly/yearly/all-time
- search: leader name

## Frontend Rankings Tab

The bottom tab should be named `Rankings`.

Top layout:

```text
SIVIQ Rankings

[ National ] [ County ] [ Subcounty ]
[ Governors ] [ MPs ] [ MCAs ] [ Senators ]
[ This Week ]
```

For the fresh app, if there is no snapshot yet:

- show leader directory results from `leaders`
- filter by county/subcounty/name
- display `Pending weekly score`
- explain that rankings update after the Sunday snapshot

Leaderboard card:

```text
#1  Governor Name
78.4 SIVIQ Score
↑ +3.2 this week

Completed Projects: 21
Stalled Projects: 4
County: Kakamega
```

Movement color:

- green for positive
- red for negative
- gray for neutral

If `is_top_twenty = true`, show a restrained trophy badge. Celebration animation should be used sparingly and only on leader details, not on every list card.

## Leader Detail Screen

Clicking a ranking card opens a leader detail screen with:

- photo/avatar placeholder
- name, role, party, county, subcounty
- SIVIQ score and rank
- approval ratio
- project completion percentage
- weekly movement
- linked projects from `leader_projects`
- demographic transparency metadata
- legal disclaimer

Historical charting is future work. Store the snapshots now so charts can be built later without changing the data model.

## Moderation Gate Before Public Launch

Rankings should not be publicly promoted until these controls exist:

- report project
- moderation queue
- suspicious activity flags
- duplicate project detection
- flagged project exclusion
- admin ability to unlink a project from a leader

The app already has `project_reports`. The next backend step should add a moderation review surface and a duplicate-check strategy.

## Implementation Order

1. Add the database migration for `leader_projects`, `leaderboard_snapshots`, indexes, and security events.
2. Add `execute_weekly_rankings_snapshot()` in PL/pgSQL.
3. Add the read-only leaderboard view.
4. Schedule `pg_cron` for Saturday `21:00 UTC`, which is Sunday `00:00 EAT`.
5. Add a manual admin-only RPC to run the snapshot during QA.
6. Add basic seed links between current leaders and a few test projects.
7. Build the Flutter Rankings tab as a snapshot reader plus leader directory fallback.
8. Add notification inserts for top-20 and abuse events.
9. QA with 2 to 5 accounts and verify the formula metadata is visible.
10. Only then expose the tab broadly.

## MVP Position Support

The current seeded `leaders` table supports:

- Governors
- MPs

MCAs and Senators should appear as disabled filters or hidden filters until the `leaders.role` constraint and seed data are expanded. Do not fake missing offices.

## Future Analytics

Architect for these, but do not build them in the MVP:

- monthly, yearly, and all-time snapshots
- trend charts
- constituency comparisons
- historical decay
- county scorecards
- corruption heatmaps
- precomputed top 100 cache table
- stronger identity verification weighting

## Decision Summary

Rankings will be implemented as a Supabase-owned weekly snapshot engine. The formulas live in Postgres functions, scheduled by `pg_cron`, with immutable results stored in `leaderboard_snapshots`. The Flutter app reads those results and displays the score, rank, movement, linked projects, and geographic transparency metadata.

For the fresh app stage, the Rankings tab should mostly behave as a leader directory with filters by county, subcounty, and name, while the scoring engine starts collecting weekly snapshots quietly. As project volume and moderation quality increase, the score becomes more prominent.
