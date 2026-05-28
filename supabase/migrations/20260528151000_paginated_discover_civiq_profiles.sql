drop function if exists public.discover_civiq_profiles();

create or replace function public.discover_civiq_profiles(
  page_limit integer default 5,
  page_offset integer default 0
)
returns table (
  id uuid,
  display_name text,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text,
  role text,
  is_followed boolean
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.display_name,
    p.username,
    p.civiq_code,
    p.avatar_url,
    p.is_verified,
    p.role_label,
    p.role::text,
    exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = p.id
    ) as is_followed
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and coalesce(p.account_status, 'active') = 'active'
  order by
    p.is_verified desc,
    p.username nulls last,
    p.created_at desc
  limit least(greatest(page_limit, 1), 50)
  offset greatest(page_offset, 0);
$$;

grant execute on function public.discover_civiq_profiles(integer, integer) to authenticated;
