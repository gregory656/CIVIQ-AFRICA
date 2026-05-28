begin;

drop function if exists public.list_group_members(uuid, int);

create or replace function public.list_group_members(
  target_conversation_id uuid,
  result_limit int default 100
)
returns table (
  user_id uuid,
  username text,
  avatar_url text,
  is_verified boolean,
  role_label text,
  role text,
  member_role text,
  joined_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.avatar_url,
    p.is_verified,
    p.role_label,
    p.role,
    cp.role,
    cp.joined_at
  from public.conversation_participants cp
  join public.profiles p on p.id = cp.user_id
  join public.conversations c on c.id = cp.conversation_id
  where cp.conversation_id = target_conversation_id
    and c.conversation_type = 'group'
    and public.is_conversation_participant(target_conversation_id)
    and p.deleted_at is null
  order by
    case cp.role when 'owner' then 0 when 'admin' then 1 else 2 end,
    case p.role when 'super_admin' then 0 when 'admin' then 1 when 'moderator' then 2 else 3 end,
    cp.joined_at,
    p.username nulls last
  limit least(greatest(coalesce(result_limit, 100), 1), 200);
$$;

drop function if exists public.list_conversations();

create or replace function public.list_conversations()
returns table (
  id uuid,
  conversation_type text,
  title text,
  group_photo_url text,
  group_description text,
  group_member_count bigint,
  group_member_summary text,
  current_user_role text,
  created_at timestamptz,
  updated_at timestamptz,
  is_muted boolean,
  is_archived boolean,
  is_favorite boolean,
  last_message_id uuid,
  last_message_content text,
  last_message_sender_id uuid,
  last_message_created_at timestamptz,
  last_message_delivered_count bigint,
  last_message_read_count bigint,
  unread_count bigint,
  peer_id uuid,
  peer_username text,
  peer_avatar_url text,
  peer_is_verified boolean,
  peer_is_online boolean,
  peer_last_seen timestamptz,
  peer_show_online_status boolean,
  peer_role_label text,
  peer_role text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.conversation_type,
    c.title,
    c.group_photo_url,
    c.group_description,
    group_meta.member_count,
    group_meta.member_summary,
    mine.role as current_user_role,
    c.created_at,
    c.updated_at,
    mine.is_muted,
    mine.is_archived,
    mine.is_favorite,
    lm.id as last_message_id,
    case when lm.deleted_at is null then lm.content else 'Message deleted' end as last_message_content,
    lm.sender_id as last_message_sender_id,
    lm.created_at as last_message_created_at,
    case
      when lm.sender_id = auth.uid() then (
        select count(*)
        from public.message_reads mr
        where mr.message_id = lm.id
          and mr.user_id <> lm.sender_id
          and mr.delivered_at is not null
      )
      else 0
    end as last_message_delivered_count,
    case
      when lm.sender_id = auth.uid() then (
        select count(*)
        from public.message_reads mr
        join public.profiles reader on reader.id = mr.user_id
        where mr.message_id = lm.id
          and mr.user_id <> lm.sender_id
          and mr.read_at is not null
          and coalesce(reader.show_read_receipts, true)
      )
      else 0
    end as last_message_read_count,
    (
      select count(*)
      from public.messages unread
      left join public.message_reads mr
        on mr.message_id = unread.id
       and mr.user_id = auth.uid()
      where unread.conversation_id = c.id
        and unread.sender_id is distinct from auth.uid()
        and unread.deleted_at is null
        and mr.read_at is null
        and not exists (
          select 1 from public.message_hidden_users hidden
          where hidden.message_id = unread.id and hidden.user_id = auth.uid()
        )
    ) as unread_count,
    peer.id as peer_id,
    peer.username as peer_username,
    peer.avatar_url as peer_avatar_url,
    peer.is_verified as peer_is_verified,
    case
      when c.conversation_type = 'group' then false
      when coalesce(peer.show_online_status, true)
      then coalesce(peer.is_online, false)
        and peer.last_seen > now() - interval '2 minutes'
      else false
    end as peer_is_online,
    case
      when c.conversation_type = 'group' then null
      when coalesce(peer.show_online_status, true) then peer.last_seen
      else null
    end as peer_last_seen,
    coalesce(peer.show_online_status, true) as peer_show_online_status,
    peer.role_label as peer_role_label,
    coalesce(peer.role, 'user') as peer_role
  from public.conversation_participants mine
  join public.conversations c on c.id = mine.conversation_id
  left join lateral (
    select m.*
    from public.messages m
    where m.conversation_id = c.id
      and not exists (
        select 1 from public.message_hidden_users hidden
        where hidden.message_id = m.id and hidden.user_id = auth.uid()
      )
    order by m.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select
      p.id,
      p.username,
      p.avatar_url,
      p.is_verified,
      p.is_online,
      p.last_seen,
      p.show_online_status,
      p.role_label,
      p.role
    from public.conversation_participants cp
    join public.profiles p on p.id = cp.user_id
    where cp.conversation_id = c.id
      and cp.user_id <> auth.uid()
    order by
      case p.role when 'super_admin' then 0 when 'admin' then 1 when 'moderator' then 2 else 3 end,
      cp.joined_at
    limit 1
  ) peer on true
  left join lateral (
    with members as (
      select p.username, cp.joined_at
      from public.conversation_participants cp
      join public.profiles p on p.id = cp.user_id
      where cp.conversation_id = c.id
        and cp.user_id <> auth.uid()
      order by cp.joined_at
      limit 3
    )
    select
      count(*)::bigint as member_count,
      string_agg(coalesce('@' || nullif(username, ''), 'SIVIQ Member'), ', ' order by joined_at) as member_summary
    from members
  ) group_meta on true
  where mine.user_id = auth.uid()
    and mine.deleted_at is null
  order by c.updated_at desc;
$$;

grant execute on function public.list_group_members(uuid, int) to authenticated;
grant execute on function public.list_conversations() to authenticated;

commit;
