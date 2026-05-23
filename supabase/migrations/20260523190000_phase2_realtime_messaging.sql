create extension if not exists "pgcrypto";

create table if not exists public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_no_self_block check (blocker_id <> blocked_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  conversation_type text not null
    check (conversation_type in ('direct', 'group', 'self')),
  title text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_message_id uuid,
  is_muted boolean not null default false,
  is_archived boolean not null default false,
  is_favorite boolean not null default false,
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  message_type text not null default 'text'
    check (message_type in ('text', 'image', 'document', 'audio', 'system')),
  content text,
  media_url text,
  reply_to_message_id uuid references public.messages(id) on delete set null,
  is_edited boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint messages_has_payload check (
    content is not null or media_url is not null or message_type = 'system'
  )
);

alter table public.conversation_participants
  drop constraint if exists conversation_participants_last_read_message_id_fkey;

alter table public.conversation_participants
  add constraint conversation_participants_last_read_message_id_fkey
  foreign key (last_read_message_id) references public.messages(id) on delete set null;

create table if not exists public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  read_at timestamptz,
  primary key(message_id, user_id)
);

create table if not exists public.favorite_messages (
  user_id uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, message_id)
);

create index if not exists idx_conversations_type_created
  on public.conversations (conversation_type, created_at desc);

create index if not exists idx_conversation_participants_user
  on public.conversation_participants (user_id, is_archived, joined_at desc);

create index if not exists idx_messages_conversation_created
  on public.messages (conversation_id, created_at desc);

create index if not exists idx_messages_text_search
  on public.messages using gin (to_tsvector('simple', coalesce(content, '')))
  where deleted_at is null and message_type = 'text';

create index if not exists idx_message_reads_user_read
  on public.message_reads (user_id, read_at);

create index if not exists idx_favorite_messages_user_created
  on public.favorite_messages (user_id, created_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_conversations_updated_at on public.conversations;
create trigger touch_conversations_updated_at
  before update on public.conversations
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_messages_updated_at on public.messages;
create trigger touch_messages_updated_at
  before update on public.messages
  for each row execute function public.touch_updated_at();

create or replace function public.is_conversation_participant(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.user_id = auth.uid()
  );
$$;

create or replace function public.can_message_profile(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and target_user_id is not null
    and not exists (
      select 1
      from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = target_user_id)
         or (b.blocker_id = target_user_id and b.blocked_id = auth.uid())
    )
    and (
      target_user_id = auth.uid()
      or exists (
        select 1
        from public.profiles p
        where p.id = target_user_id
          and coalesce(p.allow_message_requests, true)
          and p.deleted_at is null
      )
      or exists (
        select 1
        from public.follows f
        where f.follower_id = target_user_id
          and f.following_id = auth.uid()
      )
    );
$$;

create or replace function public.ensure_self_conversation(target_user_id uuid default auth.uid())
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_id uuid;
  new_id uuid;
begin
  if target_user_id is null then
    raise exception 'User is required.';
  end if;

  select c.id into existing_id
  from public.conversations c
  join public.conversation_participants cp
    on cp.conversation_id = c.id
  where c.conversation_type = 'self'
    and cp.user_id = target_user_id
  limit 1;

  if existing_id is not null then
    return existing_id;
  end if;

  insert into public.conversations (conversation_type, title, created_by)
  values ('self', 'Saved Messages', target_user_id)
  returning id into new_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values (new_id, target_user_id)
  on conflict do nothing;

  return new_id;
end;
$$;

create or replace function public.create_self_conversation_for_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_self_conversation(new.id);
  return new;
end;
$$;

drop trigger if exists create_self_conversation_after_profile on public.profiles;
create trigger create_self_conversation_after_profile
  after insert on public.profiles
  for each row execute function public.create_self_conversation_for_profile();

create or replace function public.create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_id uuid;
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if target_user_id = auth.uid() then
    return public.ensure_self_conversation(auth.uid());
  end if;

  if not public.can_message_profile(target_user_id) then
    raise exception 'Messaging is not allowed for this profile.';
  end if;

  select c.id into existing_id
  from public.conversations c
  join public.conversation_participants a
    on a.conversation_id = c.id and a.user_id = auth.uid()
  join public.conversation_participants b
    on b.conversation_id = c.id and b.user_id = target_user_id
  where c.conversation_type = 'direct'
    and (
      select count(*)
      from public.conversation_participants cp
      where cp.conversation_id = c.id
    ) = 2
  limit 1;

  if existing_id is not null then
    return existing_id;
  end if;

  insert into public.conversations (conversation_type, created_by)
  values ('direct', auth.uid())
  returning id into new_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values
    (new_id, auth.uid()),
    (new_id, target_user_id)
  on conflict do nothing;

  return new_id;
end;
$$;

create or replace function public.create_group_conversation(
  group_title text,
  member_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  member_id uuid;
  normalized_members uuid[];
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  normalized_members := array(
    select distinct id
    from unnest(coalesce(member_ids, array[]::uuid[]) || auth.uid()) as id
    where id is not null
  );

  if array_length(normalized_members, 1) is null
    or array_length(normalized_members, 1) < 2 then
    raise exception 'Groups need at least two members.';
  end if;

  if array_length(normalized_members, 1) > 50 then
    raise exception 'Phase 2 groups are limited to 50 members.';
  end if;

  foreach member_id in array normalized_members loop
    if member_id <> auth.uid() and not public.can_message_profile(member_id) then
      raise exception 'A selected member cannot be messaged.';
    end if;
  end loop;

  insert into public.conversations (conversation_type, title, created_by)
  values ('group', nullif(trim(group_title), ''), auth.uid())
  returning id into new_id;

  insert into public.conversation_participants (conversation_id, user_id)
  select new_id, id from unnest(normalized_members) as id
  on conflict do nothing;

  return new_id;
end;
$$;

create or replace function public.send_message(
  target_conversation_id uuid,
  body text,
  target_message_type text default 'text',
  target_media_url text default null,
  target_reply_to_message_id uuid default null
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  new_message public.messages;
  recipient_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Conversation access denied.';
  end if;

  if nullif(trim(coalesce(body, '')), '') is null and target_media_url is null then
    raise exception 'Message content is required.';
  end if;

  if length(coalesce(body, '')) > 4000 then
    raise exception 'Message is too long.';
  end if;

  if exists (
    select 1
    from public.messages m
    where m.sender_id = auth.uid()
      and m.created_at > now() - interval '10 seconds'
    group by m.sender_id
    having count(*) >= 8
  ) then
    raise exception 'You are sending messages too quickly.';
  end if;

  for recipient_id in
    select cp.user_id
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.user_id <> auth.uid()
  loop
    if exists (
      select 1
      from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = auth.uid())
    ) then
      raise exception 'Blocked users cannot exchange messages.';
    end if;
  end loop;

  insert into public.messages (
    conversation_id,
    sender_id,
    message_type,
    content,
    media_url,
    reply_to_message_id
  )
  values (
    target_conversation_id,
    auth.uid(),
    coalesce(target_message_type, 'text'),
    nullif(trim(coalesce(body, '')), ''),
    target_media_url,
    target_reply_to_message_id
  )
  returning * into new_message;

  insert into public.message_reads (message_id, user_id, delivered_at, read_at)
  values (new_message.id, auth.uid(), now(), now())
  on conflict (message_id, user_id) do update
    set delivered_at = excluded.delivered_at,
        read_at = excluded.read_at;

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;

  return new_message;
end;
$$;

create or replace function public.mark_conversation_read(
  target_conversation_id uuid,
  target_message_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  latest_message_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Conversation access denied.';
  end if;

  select coalesce(
    target_message_id,
    (
      select m.id
      from public.messages m
      where m.conversation_id = target_conversation_id
        and m.deleted_at is null
      order by m.created_at desc
      limit 1
    )
  )
  into latest_message_id;

  if latest_message_id is null then
    return;
  end if;

  insert into public.message_reads (message_id, user_id, delivered_at, read_at)
  select m.id, auth.uid(), now(), now()
  from public.messages m
  join public.profiles reader on reader.id = auth.uid()
  where m.conversation_id = target_conversation_id
    and m.sender_id is distinct from auth.uid()
    and m.deleted_at is null
    and coalesce(reader.show_read_receipts, true)
  on conflict (message_id, user_id) do update
    set delivered_at = least(public.message_reads.delivered_at, excluded.delivered_at),
        read_at = excluded.read_at;

  insert into public.message_reads (message_id, user_id, delivered_at, read_at)
  select m.id, auth.uid(), now(), null
  from public.messages m
  join public.profiles reader on reader.id = auth.uid()
  where m.conversation_id = target_conversation_id
    and m.sender_id is distinct from auth.uid()
    and m.deleted_at is null
    and not coalesce(reader.show_read_receipts, true)
  on conflict (message_id, user_id) do update
    set delivered_at = least(public.message_reads.delivered_at, excluded.delivered_at);

  update public.conversation_participants
  set last_read_message_id = latest_message_id
  where conversation_id = target_conversation_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.toggle_favorite_message(target_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  is_favorite boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not exists (
    select 1
    from public.messages m
    where m.id = target_message_id
      and public.is_conversation_participant(m.conversation_id)
  ) then
    raise exception 'Message access denied.';
  end if;

  delete from public.favorite_messages
  where user_id = auth.uid()
    and message_id = target_message_id
  returning true into is_favorite;

  if is_favorite then
    return false;
  end if;

  insert into public.favorite_messages (user_id, message_id)
  values (auth.uid(), target_message_id)
  on conflict do nothing;

  return true;
end;
$$;

create or replace function public.search_chat_profiles(query_text text, result_limit int default 20)
returns table (
  id uuid,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text
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
    p.role_label
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
    p.is_verified desc,
    p.username nulls last,
    p.created_at desc
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

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
    select p.id, p.username, p.avatar_url, p.is_verified, p.role_label
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

create or replace function public.list_conversation_messages(
  target_conversation_id uuid,
  before_message_created_at timestamptz default null,
  result_limit int default 50
)
returns table (
  id uuid,
  conversation_id uuid,
  sender_id uuid,
  message_type text,
  content text,
  media_url text,
  reply_to_message_id uuid,
  is_edited boolean,
  created_at timestamptz,
  deleted_at timestamptz,
  sender_username text,
  sender_avatar_url text,
  is_favorite boolean,
  delivered_count bigint,
  read_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    m.message_type,
    m.content,
    m.media_url,
    m.reply_to_message_id,
    m.is_edited,
    m.created_at,
    m.deleted_at,
    p.username as sender_username,
    p.avatar_url as sender_avatar_url,
    exists (
      select 1
      from public.favorite_messages f
      where f.user_id = auth.uid()
        and f.message_id = m.id
    ) as is_favorite,
    (
      select count(*)
      from public.message_reads mr
      where mr.message_id = m.id
        and mr.user_id <> m.sender_id
        and mr.delivered_at is not null
    ) as delivered_count,
    (
      select count(*)
      from public.message_reads mr
      join public.profiles reader on reader.id = mr.user_id
      where mr.message_id = m.id
        and mr.user_id <> m.sender_id
        and mr.read_at is not null
        and coalesce(reader.show_read_receipts, true)
    ) as read_count
  from public.messages m
  left join public.profiles p on p.id = m.sender_id
  where m.conversation_id = target_conversation_id
    and public.is_conversation_participant(target_conversation_id)
    and (
      before_message_created_at is null
      or m.created_at < before_message_created_at
    )
  order by m.created_at desc
  limit least(greatest(coalesce(result_limit, 50), 1), 100);
$$;

alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;
alter table public.favorite_messages enable row level security;
alter table public.blocked_users enable row level security;

drop policy if exists "Participants can read conversations" on public.conversations;
create policy "Participants can read conversations"
  on public.conversations for select
  to authenticated
  using (public.is_conversation_participant(id));

drop policy if exists "Participants can read participant rows" on public.conversation_participants;
create policy "Participants can read participant rows"
  on public.conversation_participants for select
  to authenticated
  using (public.is_conversation_participant(conversation_id));

drop policy if exists "Users can update own participant state" on public.conversation_participants;
create policy "Users can update own participant state"
  on public.conversation_participants for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Participants can read messages" on public.messages;
create policy "Participants can read messages"
  on public.messages for select
  to authenticated
  using (public.is_conversation_participant(conversation_id));

drop policy if exists "Participants can soft delete own messages" on public.messages;
create policy "Participants can soft delete own messages"
  on public.messages for update
  to authenticated
  using (sender_id = auth.uid() and public.is_conversation_participant(conversation_id))
  with check (sender_id = auth.uid() and public.is_conversation_participant(conversation_id));

drop policy if exists "Participants can read message receipts" on public.message_reads;
create policy "Participants can read message receipts"
  on public.message_reads for select
  to authenticated
  using (
    exists (
      select 1
      from public.messages m
      where m.id = message_id
        and public.is_conversation_participant(m.conversation_id)
    )
  );

drop policy if exists "Users can read own favorite messages" on public.favorite_messages;
create policy "Users can read own favorite messages"
  on public.favorite_messages for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read own block graph" on public.blocked_users;
create policy "Users can read own block graph"
  on public.blocked_users for select
  to authenticated
  using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "Users can create own blocks" on public.blocked_users;
create policy "Users can create own blocks"
  on public.blocked_users for insert
  to authenticated
  with check (auth.uid() = blocker_id);

drop policy if exists "Users can remove own blocks" on public.blocked_users;
create policy "Users can remove own blocks"
  on public.blocked_users for delete
  to authenticated
  using (auth.uid() = blocker_id);

do $$
begin
  perform public.ensure_self_conversation(p.id)
  from public.profiles p
  where not exists (
    select 1
    from public.conversations c
    join public.conversation_participants cp
      on cp.conversation_id = c.id
    where c.conversation_type = 'self'
      and cp.user_id = p.id
  );
end $$;

do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.conversation_participants;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.message_reads;
exception
  when duplicate_object then null;
end $$;

grant execute on function public.ensure_self_conversation(uuid) to authenticated;
grant execute on function public.create_direct_conversation(uuid) to authenticated;
grant execute on function public.create_group_conversation(text, uuid[]) to authenticated;
grant execute on function public.send_message(uuid, text, text, text, uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid, uuid) to authenticated;
grant execute on function public.toggle_favorite_message(uuid) to authenticated;
grant execute on function public.search_chat_profiles(text, int) to authenticated;
grant execute on function public.list_conversations() to authenticated;
grant execute on function public.list_conversation_messages(uuid, timestamptz, int) to authenticated;
