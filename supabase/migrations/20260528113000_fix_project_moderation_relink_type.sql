begin;

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
  select l.id, new.id, 'associated'
  from public.leaders l
  where l.role = 'Governor'
    and l.county_id = new.county_id
  on conflict do nothing;

  insert into public.leader_projects (leader_id, project_id, relationship_type)
  select l.id, new.id, 'associated'
  from public.leaders l
  where l.role = 'MP'
    and l.subcounty_id = new.subcounty_id
  on conflict do nothing;

  return new;
end;
$$;

commit;
