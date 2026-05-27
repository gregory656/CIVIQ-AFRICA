begin;

create or replace function public.generate_unique_civiq_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text;
begin
  loop
    result := 'SQ-' ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1) ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1) ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1) ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1) ||
      '-' ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1) ||
      substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1);

    exit when not exists (
      select 1 from public.profiles where civiq_code = result
    );
  end loop;

  return result;
end;
$$;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, civiq_code)
  values (new.id, coalesce(new.email, ''), public.generate_unique_civiq_code())
  on conflict (id) do nothing;

  insert into public.notifications (user_id, title, body, category)
  values (
    new.id,
    'Welcome to SIVIQ.',
    'Read our guidelines and help improve your community responsibly.',
    'general'
  )
  on conflict do nothing;

  insert into public.notifications (user_id, title, body, category)
  values (
    new.id,
    'Create your first SIVIQ project report.',
    'Engage your local leadership and track development near you.',
    'projects'
  )
  on conflict do nothing;

  return new;
end;
$$;

update public.profiles profile
set civiq_code = 'SQ-' || substring(profile.civiq_code from 4)
where profile.civiq_code like 'CQ-%'
  and not exists (
    select 1
    from public.profiles other
    where other.civiq_code = 'SQ-' || substring(profile.civiq_code from 4)
  );

update public.notifications
set
  title = replace(replace(title, 'CIVIQ Africa', 'SIVIQ'), 'CIVIQ', 'SIVIQ'),
  body = replace(replace(body, 'CIVIQ Africa', 'SIVIQ'), 'CIVIQ', 'SIVIQ')
where title like '%CIVIQ%'
   or body like '%CIVIQ%';

commit;
