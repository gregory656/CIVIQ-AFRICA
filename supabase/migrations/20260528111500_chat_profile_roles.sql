begin;

drop function if exists public.search_chat_profiles(text, int);

create or replace function public.search_chat_profiles(
  query_text text,
  result_limit int default 20
)
returns table (
  id uuid,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text,
  role text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.civiq_code,
    p.avatar_url,
    p.is_verified,
    p.role_label,
    p.role
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.deleted_at is null
    and public.can_message_profile(p.id)
    and (
      query_text is null
      or query_text = ''
      or p.username ilike '%' || query_text || '%'
      or p.civiq_code ilike '%' || query_text || '%'
    )
  order by
    case p.role
      when 'super_admin' then 0
      when 'admin' then 1
      when 'moderator' then 2
      else 3
    end,
    p.is_verified desc,
    p.username nulls last,
    p.created_at desc
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

grant execute on function public.search_chat_profiles(text, int) to authenticated;

commit;
