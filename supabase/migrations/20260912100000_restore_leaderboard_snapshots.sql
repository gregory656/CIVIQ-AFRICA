begin;

select public.execute_weekly_rankings_snapshot();

create or replace function public.validate_profile_governance_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.county_id is not null and new.subcounty_id is not null
    and not exists (
      select 1
      from public.subcounties
      where id = new.subcounty_id and county_id = new.county_id
    ) then
    raise exception using
      errcode = '23514',
      message = 'The selected constituency does not belong to the selected county.';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_profile_governance_location on public.profiles;
create trigger validate_profile_governance_location
before insert or update of county_id, subcounty_id on public.profiles
for each row execute function public.validate_profile_governance_location();

commit;
