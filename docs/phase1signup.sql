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

grant select on public.counties to anon, authenticated;
grant select on public.subcounties to anon, authenticated;

do $$
begin
  if to_regclass('public.leaders') is not null then
    grant select on public.leaders to anon, authenticated;
  end if;

  if to_regclass('public.v_geographic_governance') is not null then
    grant select on public.v_geographic_governance to anon, authenticated;
  end if;
end;
$$;

commit;
