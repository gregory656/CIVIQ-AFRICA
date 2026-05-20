begin;

create extension if not exists pgcrypto;

create table if not exists public.counties (
  id int primary key,
  name text not null unique
);

create table if not exists public.subcounties (
  id int primary key,
  county_id int not null references public.counties(id) on delete cascade,
  name text not null,
  unique (county_id, name)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text unique,
  civiq_code text unique,
  phone text,
  bio text,
  avatar_url text,
  county_id int references public.counties(id) on delete set null,
  subcounty_id int references public.subcounties(id) on delete set null,
  is_verified boolean not null default false,
  is_public boolean not null default false,
  is_online boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
declare
  county record;
  existing_id int;
begin
  for county in
    select *
    from (
      values
        (30, 'Nairobi'),
        (1, 'Mombasa'),
        (22, 'Kiambu')
    ) as desired(id, name)
  loop
    select id
      into existing_id
      from public.counties
      where lower(name) = lower(county.name)
      limit 1;

    if existing_id is null then
      insert into public.counties (id, name)
      values (county.id, county.name)
      on conflict (id) do update set name = excluded.name;
    elsif existing_id <> county.id then
      insert into public.counties (id, name)
      values (county.id, county.name || ' merge target ' || county.id::text)
      on conflict (id) do nothing;

      update public.subcounties
      set county_id = county.id
      where county_id = existing_id;

      update public.profiles
      set county_id = county.id
      where county_id = existing_id;

      delete from public.counties
      where id = existing_id;
      
      update public.counties
      set name = county.name
      where id = county.id;
    else
      update public.counties
      set name = county.name
      where id = county.id;
    end if;
  end loop;
end;
$$;

do $$
declare
  subcounty record;
  existing_id int;
begin
  for subcounty in
    select *
    from (
      values
        (301, 30, 'Westlands'),
        (302, 30, 'Kasarani'),
        (303, 30, 'Embakasi East'),
        (101, 1, 'Changamwe'),
        (102, 1, 'Likoni'),
        (103, 1, 'Nyali'),
        (221, 22, 'Thika Town'),
        (222, 22, 'Ruiru'),
        (223, 22, 'Kikuyu')
    ) as desired(id, county_id, name)
  loop
    select id
      into existing_id
      from public.subcounties
      where county_id = subcounty.county_id
        and lower(name) = lower(subcounty.name)
      limit 1;

    if existing_id is null then
      insert into public.subcounties (id, county_id, name)
      values (subcounty.id, subcounty.county_id, subcounty.name)
      on conflict (id) do update
      set county_id = excluded.county_id,
          name = excluded.name;
    elsif existing_id <> subcounty.id then
      insert into public.subcounties (id, county_id, name)
      values (
        subcounty.id,
        subcounty.county_id,
        subcounty.name || ' merge target ' || subcounty.id::text
      )
      on conflict (id) do nothing;

      update public.profiles
      set subcounty_id = subcounty.id
      where subcounty_id = existing_id;

      delete from public.subcounties
      where id = existing_id;

      update public.subcounties
      set county_id = subcounty.county_id,
          name = subcounty.name
      where id = subcounty.id;
    else
      update public.subcounties
      set county_id = subcounty.county_id,
          name = subcounty.name
      where id = subcounty.id;
    end if;
  end loop;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user_profile();
drop function if exists public.generate_unique_civiq_code();

create function public.generate_unique_civiq_code()
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
    result := 'CQ-' ||
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

create function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, civiq_code)
  values (new.id, coalesce(new.email, ''), public.generate_unique_civiq_code())
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();

alter table public.profiles enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Profiles are queryable by authenticated users" on public.profiles;
drop policy if exists "Users can create their own profile" on public.profiles;
drop policy if exists "Users can modify their own structural data" on public.profiles;
drop policy if exists "Users can check their notifications" on public.notifications;
drop policy if exists "Users can create their notifications" on public.notifications;
drop policy if exists "Users can modify notification read states" on public.notifications;

create policy "Profiles are queryable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users can create their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Users can modify their own structural data"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users can check their notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can create their notifications"
  on public.notifications for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can modify notification read states"
  on public.notifications for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

commit;
