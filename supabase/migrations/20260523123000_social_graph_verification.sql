alter table public.profiles
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references auth.users(id),
  add column if not exists verification_type text,
  add column if not exists role_label text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_username_format_check'
  ) then
    alter table public.profiles
      add constraint profiles_username_format_check
      check (username is null or username ~ '^[A-Za-z0-9_]{3,30}$')
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_username_reserved_check'
  ) then
    alter table public.profiles
      add constraint profiles_username_reserved_check
      check (
        username is null or lower(username) not in (
          'admin',
          'administrator',
          'civiq',
          'civiqafrica',
          'support',
          'help',
          'moderator',
          'official',
          'verified',
          'president',
          'deputypresident',
          'governor',
          'senator',
          'mp',
          'mca',
          'county',
          'government',
          'iebc',
          'police'
        )
      )
      not valid;
  end if;
end $$;

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_role text,
  proof_document_url text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'more_info')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function public.is_civiq_admin()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in (
    'admin',
    'service_role'
  );
$$;

create or replace function public.prevent_profile_verification_self_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;

  if public.is_civiq_admin() then
    return new;
  end if;

  if new.is_verified is distinct from old.is_verified
    or new.verified_at is distinct from old.verified_at
    or new.verified_by is distinct from old.verified_by
    or new.verification_type is distinct from old.verification_type
    or new.role_label is distinct from old.role_label then
    raise exception 'Only CIVIQ admins can update verification fields.';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_verification_fields on public.profiles;
create trigger protect_profile_verification_fields
  before update on public.profiles
  for each row execute function public.prevent_profile_verification_self_update();

alter table public.follows enable row level security;
alter table public.verification_requests enable row level security;

drop policy if exists "Authenticated users can read follows" on public.follows;
create policy "Authenticated users can read follows"
  on public.follows for select
  to authenticated
  using (true);

drop policy if exists "Users can follow from own account" on public.follows;
create policy "Users can follow from own account"
  on public.follows for insert
  to authenticated
  with check (auth.uid() = follower_id);

drop policy if exists "Users can unfollow from own account" on public.follows;
create policy "Users can unfollow from own account"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

drop policy if exists "Users can create own verification requests" on public.verification_requests;
create policy "Users can create own verification requests"
  on public.verification_requests for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own verification requests" on public.verification_requests;
create policy "Users can read own verification requests"
  on public.verification_requests for select
  to authenticated
  using (auth.uid() = user_id or public.is_civiq_admin());

drop policy if exists "Admins can review verification requests" on public.verification_requests;
create policy "Admins can review verification requests"
  on public.verification_requests for update
  to authenticated
  using (public.is_civiq_admin())
  with check (public.is_civiq_admin());

drop policy if exists "Admins can update profile verification" on public.profiles;
create policy "Admins can update profile verification"
  on public.profiles for update
  to authenticated
  using (public.is_civiq_admin())
  with check (public.is_civiq_admin());

create index if not exists idx_follows_following_created
  on public.follows (following_id, created_at desc);

create index if not exists idx_follows_follower_created
  on public.follows (follower_id, created_at desc);

create index if not exists idx_verification_requests_user_created
  on public.verification_requests (user_id, created_at desc);

create index if not exists idx_verification_requests_status_created
  on public.verification_requests (status, created_at desc);

update public.profiles
set
  is_verified = true,
  verification_type = coalesce(verification_type, 'preview'),
  verified_at = coalesce(verified_at, now())
where is_verified is distinct from true;
