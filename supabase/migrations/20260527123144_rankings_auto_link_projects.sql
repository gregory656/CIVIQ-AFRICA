begin;

create or replace function public.link_project_to_jurisdiction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null or new.verification_status = 'flagged' then
    delete from public.leader_projects where project_id = new.id;
    return new;
  end if;

  if new.county_id is not null then
    insert into public.leader_projects (leader_id, project_id, relationship_type)
    select l.id, new.id, 'associated'
    from public.leaders l
    where l.role = 'Governor'
      and l.county_id = new.county_id
    on conflict (leader_id, project_id) do nothing;
  end if;

  if new.subcounty_id is not null then
    insert into public.leader_projects (leader_id, project_id, relationship_type)
    select l.id, new.id, 'associated'
    from public.leaders l
    where l.role = 'MP'
      and l.subcounty_id = new.subcounty_id
    on conflict (leader_id, project_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists link_project_to_jurisdiction_after_write on public.projects;
create trigger link_project_to_jurisdiction_after_write
  after insert or update of county_id, subcounty_id, verification_status, deleted_at
  on public.projects
  for each row execute function public.link_project_to_jurisdiction();

insert into public.leader_projects (leader_id, project_id, relationship_type)
select l.id, p.id, 'associated'
from public.projects p
join public.leaders l on l.role = 'Governor' and l.county_id = p.county_id
where p.deleted_at is null
  and p.verification_status <> 'flagged'
  and p.county_id is not null
on conflict (leader_id, project_id) do nothing;

insert into public.leader_projects (leader_id, project_id, relationship_type)
select l.id, p.id, 'associated'
from public.projects p
join public.leaders l on l.role = 'MP' and l.subcounty_id = p.subcounty_id
where p.deleted_at is null
  and p.verification_status <> 'flagged'
  and p.subcounty_id is not null
on conflict (leader_id, project_id) do nothing;

commit;
