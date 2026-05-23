create or replace function public.discover_civiq_profiles()
returns table (
  id uuid,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.civiq_code,
    p.avatar_url,
    p.is_verified,
    p.role_label
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and not exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = p.id
    )
  order by
    p.is_verified desc,
    p.username nulls last,
    p.created_at desc;
$$;

grant execute on function public.discover_civiq_profiles() to authenticated;
