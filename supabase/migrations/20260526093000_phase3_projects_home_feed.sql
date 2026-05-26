begin;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  project_type text not null check (
    project_type in ('ongoing', 'completed', 'stalled', 'excellent')
  ),
  county_id int references public.counties(id) on delete set null,
  subcounty_id int references public.subcounties(id) on delete set null,
  location_name text,
  image_url text,
  verification_status text not null default 'unverified' check (
    verification_status in (
      'unverified',
      'community_verified',
      'officially_verified',
      'flagged'
    )
  ),
  approval_count int not null default 0,
  disapproval_count int not null default 0,
  score numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.project_votes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  is_approval boolean not null,
  created_at timestamptz not null default now(),
  primary key (user_id, project_id)
);

create table if not exists public.project_reports (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (project_id, reporter_id)
);

create index if not exists idx_projects_feed
  on public.projects (deleted_at, verification_status, county_id, subcounty_id, created_at desc);

create index if not exists idx_projects_score
  on public.projects (score desc, created_at desc)
  where deleted_at is null and verification_status <> 'flagged';

alter table public.projects enable row level security;
alter table public.project_votes enable row level security;
alter table public.project_reports enable row level security;

drop policy if exists "Projects are readable by authenticated users" on public.projects;
create policy "Projects are readable by authenticated users"
  on public.projects for select
  to authenticated
  using (deleted_at is null and verification_status <> 'flagged');

drop policy if exists "Users can create projects" on public.projects;
create policy "Users can create projects"
  on public.projects for insert
  to authenticated
  with check (auth.uid() = creator_id);

drop policy if exists "Users can edit own projects before moderation" on public.projects;
create policy "Users can edit own projects before moderation"
  on public.projects for update
  to authenticated
  using (auth.uid() = creator_id and deleted_at is null)
  with check (auth.uid() = creator_id);

drop policy if exists "Users can read own project votes" on public.project_votes;
create policy "Users can read own project votes"
  on public.project_votes for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can vote once per project" on public.project_votes;
create policy "Users can vote once per project"
  on public.project_votes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own project vote" on public.project_votes;
create policy "Users can update own project vote"
  on public.project_votes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can report projects" on public.project_reports;
create policy "Users can report projects"
  on public.project_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create or replace function public.recalculate_project_score(target_project_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  approvals int;
  disapprovals int;
begin
  select
    count(*) filter (where is_approval),
    count(*) filter (where not is_approval)
  into approvals, disapprovals
  from public.project_votes
  where project_id = target_project_id;

  update public.projects
  set
    approval_count = coalesce(approvals, 0),
    disapproval_count = coalesce(disapprovals, 0),
    score = coalesce(approvals, 0) - coalesce(disapprovals, 0),
    verification_status = case
      when coalesce(approvals, 0) >= 5
        and coalesce(approvals, 0) >= coalesce(disapprovals, 0) * 2
      then 'community_verified'
      else verification_status
    end,
    updated_at = now()
  where id = target_project_id;
end;
$$;

create or replace function public.vote_project(
  target_project_id uuid,
  vote_is_approval boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.project_votes (user_id, project_id, is_approval)
  values (auth.uid(), target_project_id, vote_is_approval)
  on conflict (user_id, project_id)
  do update set
    is_approval = excluded.is_approval,
    created_at = now();

  perform public.recalculate_project_score(target_project_id);
end;
$$;

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

grant select on public.projects to authenticated;
grant select on public.project_votes to authenticated;
grant select on public.v_project_feed to authenticated;
grant insert on public.projects to authenticated;
grant insert, update on public.project_votes to authenticated;
grant insert on public.project_reports to authenticated;
grant execute on function public.vote_project(uuid, boolean) to authenticated;

commit;
