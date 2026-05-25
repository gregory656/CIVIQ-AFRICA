alter table public.profiles
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen timestamptz;

create index if not exists idx_profiles_presence
  on public.profiles (is_online, last_seen desc)
  where deleted_at is null;

create index if not exists idx_profiles_username
  on public.profiles (username);

create index if not exists idx_profiles_civiq_code
  on public.profiles (civiq_code);

create index if not exists idx_notifications_user
  on public.notifications (user_id, created_at desc)
  where deleted_at is null;

create or replace function public.update_profile_presence(online_now boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  update public.profiles
  set
    is_online = coalesce(online_now, false),
    last_seen = now(),
    updated_at = now()
  where id = auth.uid()
    and deleted_at is null;
end;
$$;

create or replace function public.handle_message_delivery_and_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient record;
  sender_name text;
begin
  if new.sender_id is null then
    return new;
  end if;

  select coalesce(nullif(username, ''), 'A CIVIQ user')
  into sender_name
  from public.profiles
  where id = new.sender_id;

  for recipient in
    select cp.user_id, cp.is_muted
    from public.conversation_participants cp
    where cp.conversation_id = new.conversation_id
      and cp.user_id <> new.sender_id
  loop
    insert into public.message_reads (message_id, user_id, delivered_at, read_at)
    values (new.id, recipient.user_id, now(), null)
    on conflict (message_id, user_id) do update
      set delivered_at = least(public.message_reads.delivered_at, excluded.delivered_at);

    if not recipient.is_muted then
      insert into public.notifications (
        user_id,
        title,
        body,
        category,
        is_read,
        action_route,
        action_label,
        actor_profile_id
      )
      values (
        recipient.user_id,
        'Unread message from ' || sender_name,
        'Open your messages to read and reply.',
        'chat_message',
        false,
        '/chats/' || new.conversation_id::text,
        'Reply',
        new.sender_id
      );
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists message_delivery_and_notification_after_insert on public.messages;
create trigger message_delivery_and_notification_after_insert
  after insert on public.messages
  for each row execute function public.handle_message_delivery_and_notification();

drop function if exists public.list_conversations();

create or replace function public.list_conversations()
returns table (
  id uuid,
  conversation_type text,
  title text,
  created_at timestamptz,
  updated_at timestamptz,
  is_muted boolean,
  is_archived boolean,
  is_favorite boolean,
  last_message_id uuid,
  last_message_content text,
  last_message_sender_id uuid,
  last_message_created_at timestamptz,
  unread_count bigint,
  peer_id uuid,
  peer_username text,
  peer_avatar_url text,
  peer_is_verified boolean,
  peer_is_online boolean,
  peer_last_seen timestamptz,
  peer_show_online_status boolean,
  peer_role_label text
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
    c.created_at,
    c.updated_at,
    mine.is_muted,
    mine.is_archived,
    mine.is_favorite,
    lm.id as last_message_id,
    lm.content as last_message_content,
    lm.sender_id as last_message_sender_id,
    lm.created_at as last_message_created_at,
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
    ) as unread_count,
    peer.id as peer_id,
    peer.username as peer_username,
    peer.avatar_url as peer_avatar_url,
    peer.is_verified as peer_is_verified,
    case
      when coalesce(peer.show_online_status, true)
      then coalesce(peer.is_online, false)
        and peer.last_seen > now() - interval '2 minutes'
      else false
    end as peer_is_online,
    case
      when coalesce(peer.show_online_status, true) then peer.last_seen
      else null
    end as peer_last_seen,
    coalesce(peer.show_online_status, true) as peer_show_online_status,
    peer.role_label as peer_role_label
  from public.conversation_participants mine
  join public.conversations c on c.id = mine.conversation_id
  left join lateral (
    select m.*
    from public.messages m
    where m.conversation_id = c.id
      and m.deleted_at is null
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
      p.role_label
    from public.conversation_participants cp
    join public.profiles p on p.id = cp.user_id
    where cp.conversation_id = c.id
      and cp.user_id <> auth.uid()
    order by cp.joined_at
    limit 1
  ) peer on true
  where mine.user_id = auth.uid()
  order by coalesce(lm.created_at, c.updated_at, c.created_at) desc;
$$;

grant execute on function public.update_profile_presence(boolean) to authenticated;
grant execute on function public.list_conversations() to authenticated;
