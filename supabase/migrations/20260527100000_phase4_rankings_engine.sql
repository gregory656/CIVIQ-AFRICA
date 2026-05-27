begin;

create extension if not exists pg_cron;

create table if not exists public.leader_projects (
  leader_id uuid not null references public.leaders(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  relationship_type text not null default 'associated'
    check (relationship_type in ('associated', 'primary', 'supporting', 'oversight')),
  created_at timestamptz not null default now(),
  primary key (leader_id, project_id)
);

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

create table if not exists public.ranking_security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  severity text not null default 'medium'
    check (severity in ('low', 'medium', 'high')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

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

alter table public.leader_projects enable row level security;
alter table public.leaderboard_snapshots enable row level security;
alter table public.ranking_security_events enable row level security;

drop policy if exists "Leader projects are readable by authenticated users" on public.leader_projects;
create policy "Leader projects are readable by authenticated users"
  on public.leader_projects for select
  to authenticated
  using (true);

drop policy if exists "Leaderboard snapshots are readable by authenticated users" on public.leaderboard_snapshots;
create policy "Leaderboard snapshots are readable by authenticated users"
  on public.leaderboard_snapshots for select
  to authenticated
  using (true);

drop policy if exists "Ranking security events stay server-side" on public.ranking_security_events;
create policy "Ranking security events stay server-side"
  on public.ranking_security_events for select
  to authenticated
  using (false);

create or replace function public.execute_weekly_rankings_snapshot()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_week date := ((now() at time zone 'Africa/Nairobi')::date
    - extract(dow from (now() at time zone 'Africa/Nairobi')::date)::int);
begin
  create temporary table tmp_ranking_flagged_users (
    user_id uuid primary key,
    vote_count int not null
  ) on commit drop;

  insert into tmp_ranking_flagged_users (user_id, vote_count)
  select user_id, count(*)::int
  from public.project_votes
  where created_at >= now() - interval '1 hour'
  group by user_id
  having count(*) > 40
  on conflict (user_id) do update set vote_count = excluded.vote_count;

  insert into public.ranking_security_events (user_id, event_type, severity, metadata)
  select
    user_id,
    'project_vote_velocity',
    'high',
    jsonb_build_object('vote_count_last_hour', vote_count, 'snapshot_week', target_week)
  from tmp_ranking_flagged_users flagged
  where not exists (
    select 1
    from public.ranking_security_events existing
    where existing.user_id = flagged.user_id
      and existing.event_type = 'project_vote_velocity'
      and existing.created_at >= now() - interval '1 hour'
  );

  create temporary table tmp_leader_scores (
    leader_id uuid primary key,
    role text not null,
    county_id int not null,
    subcounty_id int,
    score numeric(12, 4) not null,
    total_projects int not null,
    completed_projects int not null,
    stalled_projects int not null,
    approval_count int not null,
    disapproval_count int not null,
    metadata jsonb not null
  ) on commit drop;

  with linked_projects as (
    select
      l.id as leader_id,
      l.role,
      l.county_id as leader_county_id,
      l.subcounty_id as leader_subcounty_id,
      p.id as project_id,
      p.project_type,
      p.verification_status,
      p.county_id as project_county_id,
      p.subcounty_id as project_subcounty_id
    from public.leaders l
    left join public.leader_projects lp on lp.leader_id = l.id
    left join public.projects p on p.id = lp.project_id
      and p.deleted_at is null
      and p.verification_status <> 'flagged'
  ),
  vote_weights as (
    select
      lp.leader_id,
      lp.project_id,
      sum(
        case when pv.is_approval then
          case
            when flagged.user_id is not null then 0.0
            when pr.created_at > now() - interval '7 days' then 0.2
            when pr.created_at > now() - interval '30 days' then 0.5
            else 1.0
          end *
          case
            when lp.project_subcounty_id is not null and pr.subcounty_id = lp.project_subcounty_id then 1.0
            when lp.project_county_id is not null and pr.county_id = lp.project_county_id then 1.0
            else 0.15
          end
        else 0 end
      ) as weighted_approvals,
      sum(
        case when not pv.is_approval then
          case
            when flagged.user_id is not null then 0.0
            when pr.created_at > now() - interval '7 days' then 0.2
            when pr.created_at > now() - interval '30 days' then 0.5
            else 1.0
          end *
          case
            when lp.project_subcounty_id is not null and pr.subcounty_id = lp.project_subcounty_id then 1.0
            when lp.project_county_id is not null and pr.county_id = lp.project_county_id then 1.0
            else 0.15
          end
        else 0 end
      ) as weighted_disapprovals,
      count(*) filter (where pv.is_approval) as approval_count,
      count(*) filter (where not pv.is_approval) as disapproval_count
    from linked_projects lp
    left join public.project_votes pv on pv.project_id = lp.project_id
    left join public.profiles pr on pr.id = pv.user_id
    left join tmp_ranking_flagged_users flagged on flagged.user_id = pv.user_id
    where lp.project_id is not null
    group by lp.leader_id, lp.project_id
  ),
  project_scores as (
    select
      lp.leader_id,
      lp.role,
      lp.leader_county_id,
      lp.leader_subcounty_id,
      lp.project_id,
      lp.project_type,
      lp.verification_status,
      coalesce(vw.approval_count, 0)::int as approval_count,
      coalesce(vw.disapproval_count, 0)::int as disapproval_count,
      (
        ln(1 + coalesce(vw.weighted_approvals, 0))
        - ln(1 + coalesce(vw.weighted_disapprovals, 0))
      )
      * case lp.project_type
          when 'completed' then 1.5
          when 'stalled' then -2.0
          when 'excellent' then 2.0
          else 1.0
        end
      * case lp.verification_status
          when 'community_verified' then 1.25
          when 'officially_verified' then 1.50
          else 1.00
        end as project_score
    from linked_projects lp
    left join vote_weights vw on vw.leader_id = lp.leader_id and vw.project_id = lp.project_id
    where lp.project_id is not null
  ),
  local_user_counts as (
    select
      l.id as leader_id,
      count(pr.id)::int as eligible_local_users
    from public.leaders l
    left join public.profiles pr on (
      (l.subcounty_id is not null and pr.subcounty_id = l.subcounty_id)
      or (l.subcounty_id is null and pr.county_id = l.county_id)
    )
    group by l.id
  ),
  aggregated as (
    select
      l.id as leader_id,
      l.role,
      l.county_id,
      l.subcounty_id,
      count(ps.project_id)::int as total_projects,
      count(ps.project_id) filter (where ps.project_type in ('completed', 'excellent'))::int as completed_projects,
      count(ps.project_id) filter (where ps.project_type = 'stalled')::int as stalled_projects,
      coalesce(sum(ps.approval_count), 0)::int as approval_count,
      coalesce(sum(ps.disapproval_count), 0)::int as disapproval_count,
      coalesce(sum(ps.project_score), 0) as summed_score,
      coalesce(luc.eligible_local_users, 0) as eligible_local_users
    from public.leaders l
    left join project_scores ps on ps.leader_id = l.id
    left join local_user_counts luc on luc.leader_id = l.id
    group by l.id, l.role, l.county_id, l.subcounty_id, luc.eligible_local_users
  )
  insert into tmp_leader_scores (
    leader_id,
    role,
    county_id,
    subcounty_id,
    score,
    total_projects,
    completed_projects,
    stalled_projects,
    approval_count,
    disapproval_count,
    metadata
  )
  select
    leader_id,
    role,
    county_id,
    subcounty_id,
    round(
      (
        summed_score
        / greatest(total_projects, 1)
        * (1.0 / ln(exp(1) + greatest(eligible_local_users, 1)))
      )::numeric,
      4
    ) as score,
    total_projects,
    completed_projects,
    stalled_projects,
    approval_count,
    disapproval_count,
    jsonb_build_object(
      'eligible_local_users', eligible_local_users,
      'log_dampened_weight', round((1.0 / ln(exp(1) + greatest(eligible_local_users, 1)))::numeric, 6),
      'formula_version', 'rankings_v1',
      'vote_window', 'all_time_project_votes',
      'snapshot_timezone', 'Africa/Nairobi'
    )
  from aggregated;

  delete from public.leaderboard_snapshots
  where snapshot_week = target_week;

  insert into public.leaderboard_snapshots (
    leader_id,
    role,
    county_id,
    subcounty_id,
    score,
    rank,
    total_projects,
    completed_projects,
    stalled_projects,
    approval_count,
    disapproval_count,
    movement,
    is_top_twenty,
    snapshot_week,
    formula_version,
    demographic_metadata
  )
  select
    ranked.leader_id,
    ranked.role,
    ranked.county_id,
    ranked.subcounty_id,
    ranked.score,
    ranked.rank,
    ranked.total_projects,
    ranked.completed_projects,
    ranked.stalled_projects,
    ranked.approval_count,
    ranked.disapproval_count,
    round((ranked.score - coalesce(prev.score, 0))::numeric, 4) as movement,
    ranked.rank <= 20,
    target_week,
    'rankings_v1',
    ranked.metadata
  from (
    select
      tmp.*,
      (row_number() over (partition by role order by score desc, total_projects desc, leader_id))::int as rank
    from tmp_leader_scores tmp
  ) ranked
  left join lateral (
    select score
    from public.leaderboard_snapshots previous
    where previous.leader_id = ranked.leader_id
      and previous.snapshot_week < target_week
    order by previous.snapshot_week desc
    limit 1
  ) prev on true;

  insert into public.notifications (user_id, title, body, category, action_route)
  select distinct
    p.creator_id,
    'Ranking milestone',
    l.name || ' entered the SIVIQ top 20 this week.',
    'rankings',
    '/home'
  from public.leaderboard_snapshots s
  join public.leaders l on l.id = s.leader_id
  join public.leader_projects lp on lp.leader_id = l.id
  join public.projects p on p.id = lp.project_id
  left join public.notification_settings ns on ns.user_id = p.creator_id
  where s.snapshot_week = target_week
    and s.is_top_twenty
    and s.total_projects > 0
    and p.creator_id is not null
    and coalesce(ns.rankings_enabled, true)
    and not exists (
      select 1
      from public.notifications n
      where n.user_id = p.creator_id
        and n.category = 'rankings'
        and n.action_route = '/home'
        and n.body = l.name || ' entered the SIVIQ top 20 this week.'
        and n.created_at >= now() - interval '7 days'
    );
end;
$$;

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
  s.formula_version,
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

create or replace view public.v_latest_leaderboard as
select *
from public.v_leaderboard_snapshots v
where v.snapshot_week = (
  select max(snapshot_week) from public.leaderboard_snapshots
);

create or replace view public.v_leader_directory as
select
  l.id as leader_id,
  l.name as leader_name,
  l.role,
  l.party_name,
  c.id as county_id,
  c.name as county_name,
  sc.id as subcounty_id,
  sc.name as subcounty_name,
  count(lp.project_id)::int as linked_projects
from public.leaders l
join public.counties c on c.id = l.county_id
left join public.subcounties sc on sc.id = l.subcounty_id
left join public.leader_projects lp on lp.leader_id = l.id
group by l.id, l.name, l.role, l.party_name, c.id, c.name, sc.id, sc.name;

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
  and p.verification_status <> 'flagged';

grant select on public.leader_projects to authenticated;
grant select on public.leaderboard_snapshots to authenticated;
grant select on public.v_leaderboard_snapshots to authenticated;
grant select on public.v_latest_leaderboard to authenticated;
grant select on public.v_leader_directory to authenticated;
grant select on public.v_leader_project_links to authenticated;
revoke execute on function public.execute_weekly_rankings_snapshot() from anon, authenticated;

select cron.unschedule('siviq_weekly_rankings_job')
where exists (
  select 1 from cron.job where jobname = 'siviq_weekly_rankings_job'
);

select cron.schedule(
  'siviq_weekly_rankings_job',
  '0 21 * * 6',
  'select public.execute_weekly_rankings_snapshot();'
);

commit;
