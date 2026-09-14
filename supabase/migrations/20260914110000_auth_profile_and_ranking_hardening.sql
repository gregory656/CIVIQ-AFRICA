begin;

-- Preserve the county/constituency invariant while allowing every user in a
-- constituency to have a profile. This trigger validates an atomic update.
create or replace function public.validate_profile_governance_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.county_id is not null and new.subcounty_id is not null
    and not exists (
      select 1 from public.subcounties
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

-- Replacing interests is all-or-nothing and never trusts a supplied user ID.
create or replace function public.replace_user_interests(selected_interest_ids uuid[] default '{}')
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  selected_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(cardinality(selected_interest_ids), 0) > 5 then
    raise exception 'Choose up to five interests.';
  end if;
  select count(*) into selected_count
  from public.interests where id = any(coalesce(selected_interest_ids, '{}'));
  if selected_count <> coalesce(cardinality(selected_interest_ids), 0) then
    raise exception 'One or more selected interests are unavailable.';
  end if;
  delete from public.user_interests where user_id = auth.uid();
  insert into public.user_interests (user_id, interest_id)
  select auth.uid(), interest_id from unnest(coalesce(selected_interest_ids, '{}')) as interest_id;
end;
$$;

grant execute on function public.replace_user_interests(uuid[]) to authenticated;

-- Backfill immediately; the existing Nairobi-time Sunday cron remains the
-- source of future snapshots. Rankings are readable only, never client-written.
select public.execute_weekly_rankings_snapshot();
grant select on public.v_latest_leaderboard to authenticated;

commit;
