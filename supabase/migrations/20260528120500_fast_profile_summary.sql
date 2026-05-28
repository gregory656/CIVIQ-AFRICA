begin;

create or replace function public.get_profile_summary(target_user_id uuid)
returns table (
  id uuid,
  email text,
  username text,
  civiq_code text,
  bio text,
  avatar_url text,
  county_id int,
  subcounty_id int,
  is_public boolean,
  show_online_status boolean,
  show_read_receipts boolean,
  allow_message_requests boolean,
  show_activity boolean,
  is_verified boolean,
  verification_type text,
  role_label text,
  role text,
  account_status text,
  suspension_until timestamptz,
  muted_until timestamptz,
  followers_count int,
  following_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.email,
    p.username,
    p.civiq_code,
    p.bio,
    p.avatar_url,
    p.county_id,
    p.subcounty_id,
    p.is_public,
    p.show_online_status,
    p.show_read_receipts,
    p.allow_message_requests,
    p.show_activity,
    p.is_verified,
    p.verification_type,
    p.role_label,
    p.role,
    p.account_status,
    p.suspension_until,
    p.muted_until,
    (
      select count(*)::int
      from public.follows f
      where f.following_id = p.id
    ) as followers_count,
    (
      select count(*)::int
      from public.follows f
      where f.follower_id = p.id
    ) as following_count
  from public.profiles p
  where auth.uid() is not null
    and p.id = target_user_id
    and p.deleted_at is null;
$$;

grant execute on function public.get_profile_summary(uuid) to authenticated;

commit;
