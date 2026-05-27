begin;

alter table public.profiles
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references auth.users(id),
  add column if not exists verification_type text,
  add column if not exists role_label text;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    civiq_code,
    is_verified,
    verified_at,
    verification_type
  )
  values (
    new.id,
    coalesce(new.email, ''),
    public.generate_unique_civiq_code(),
    true,
    now(),
    'launch_preview'
  )
  on conflict (id) do update
    set is_verified = true,
        verified_at = coalesce(public.profiles.verified_at, now()),
        verification_type = coalesce(
          nullif(public.profiles.verification_type, ''),
          'launch_preview'
        );

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

update public.profiles
set
  is_verified = true,
  verified_at = coalesce(verified_at, now()),
  verification_type = coalesce(nullif(verification_type, ''), 'launch_preview')
where is_verified is distinct from true;

commit;
