alter table public.conversations
  add column if not exists group_photo_url text,
  add column if not exists group_description text,
  add column if not exists is_group boolean not null default false;

alter table public.conversation_participants
  add column if not exists role text not null default 'member';

alter table public.conversation_participants
  drop constraint if exists conversation_participants_role_check;

alter table public.conversation_participants
  add constraint conversation_participants_role_check
  check (role in ('member', 'admin', 'owner'));

update public.conversations
set is_group = conversation_type = 'group'
where is_group is distinct from (conversation_type = 'group');

update public.conversation_participants cp
set role = 'owner'
from public.conversations c
where c.id = cp.conversation_id
  and c.conversation_type = 'group'
  and c.created_by = cp.user_id
  and cp.role <> 'owner';

create table if not exists public.group_events (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  target_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null
    check (event_type in (
      'member_added',
      'member_removed',
      'left_group',
      'role_changed',
      'group_updated',
      'group_deleted',
      'group_reported'
    )),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.group_reports (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique (conversation_id, reporter_id)
);

create index if not exists idx_conversations_group_updated
  on public.conversations (is_group, updated_at desc);

create index if not exists idx_conversation_participants_group_role
  on public.conversation_participants (conversation_id, role, joined_at);

create index if not exists idx_group_events_conversation_created
  on public.group_events (conversation_id, created_at desc);

create index if not exists idx_group_reports_conversation_created
  on public.group_reports (conversation_id, created_at desc);

create or replace function public.group_role(target_conversation_id uuid, target_user_id uuid default auth.uid())
returns text
language sql
stable
security definer
set search_path = public
as $$
  select cp.role
  from public.conversation_participants cp
  join public.conversations c on c.id = cp.conversation_id
  where cp.conversation_id = target_conversation_id
    and cp.user_id = target_user_id
    and c.conversation_type = 'group'
  limit 1;
$$;

create or replace function public.can_manage_group(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.group_role(target_conversation_id), '') in ('owner', 'admin');
$$;

drop function if exists public.create_group_conversation(text, uuid[]);

create or replace function public.create_group_conversation(
  group_title text,
  member_ids uuid[],
  group_description text default null,
  group_photo_url text default null
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
  normalized_title text := nullif(trim(coalesce(group_title, '')), '');
  creator_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if normalized_title is null then
    raise exception 'Group name is required.';
  end if;

  if length(normalized_title) > 50 then
    raise exception 'Group name must be 50 characters or fewer.';
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
    raise exception 'Phase 2.2 groups are limited to 50 members.';
  end if;

  foreach member_id in array normalized_members loop
    if member_id <> auth.uid() and not public.can_message_profile(member_id) then
      raise exception 'A selected member cannot be messaged.';
    end if;
  end loop;

  select coalesce(nullif(username, ''), 'A CIVIQ user')
  into creator_name
  from public.profiles
  where id = auth.uid();

  insert into public.conversations (
    conversation_type,
    title,
    group_description,
    group_photo_url,
    created_by,
    is_group
  )
  values (
    'group',
    normalized_title,
    nullif(trim(coalesce(group_description, '')), ''),
    nullif(trim(coalesce(group_photo_url, '')), ''),
    auth.uid(),
    true
  )
  returning id into new_id;

  insert into public.conversation_participants (conversation_id, user_id, role)
  select
    new_id,
    id,
    case when id = auth.uid() then 'owner' else 'member' end
  from unnest(normalized_members) as id
  on conflict do nothing;

  insert into public.group_events (conversation_id, actor_id, target_user_id, event_type)
  select new_id, auth.uid(), id, 'member_added'
  from unnest(normalized_members) as id
  where id <> auth.uid();

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
  select
    id,
    creator_name || ' added you to ' || normalized_title,
    'Open the group to start participating.',
    'group_invite',
    false,
    '/chats/' || new_id::text,
    'Open group',
    auth.uid()
  from unnest(normalized_members) as id
  where id <> auth.uid();

  return new_id;
end;
$$;

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
    cp.joined_at,
    p.username nulls last
  limit least(greatest(coalesce(result_limit, 100), 1), 250);
$$;

create or replace function public.add_group_members(
  target_conversation_id uuid,
  member_ids uuid[]
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
  normalized_members uuid[];
  current_count int;
  inserted_count int := 0;
  group_title text;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.can_manage_group(target_conversation_id) then
    raise exception 'Only group admins can add members.';
  end if;

  normalized_members := array(
    select distinct id
    from unnest(coalesce(member_ids, array[]::uuid[])) as id
    where id is not null and id <> auth.uid()
  );

  if array_length(normalized_members, 1) is null then
    return 0;
  end if;

  select count(*)
  into current_count
  from public.conversation_participants
  where conversation_id = target_conversation_id;

  if current_count + array_length(normalized_members, 1) > 50 then
    raise exception 'Phase 2.2 groups are limited to 50 members.';
  end if;

  foreach target_id in array normalized_members loop
    if not public.can_message_profile(target_id) then
      raise exception 'A selected member cannot be messaged.';
    end if;
  end loop;

  select title into group_title
  from public.conversations
  where id = target_conversation_id
    and conversation_type = 'group';

  select coalesce(nullif(username, ''), 'A CIVIQ user')
  into actor_name
  from public.profiles
  where id = auth.uid();

  insert into public.conversation_participants (conversation_id, user_id, role)
  select target_conversation_id, id, 'member'
  from unnest(normalized_members) as id
  where not exists (
    select 1
    from public.conversation_participants existing
    where existing.conversation_id = target_conversation_id
      and existing.user_id = id
  )
  on conflict do nothing;

  get diagnostics inserted_count = row_count;

  insert into public.group_events (conversation_id, actor_id, target_user_id, event_type)
  select target_conversation_id, auth.uid(), id, 'member_added'
  from unnest(normalized_members) as id
  where exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.user_id = id
      and cp.joined_at > now() - interval '5 seconds'
  );

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
  select
    id,
    actor_name || ' added you to ' || coalesce(group_title, 'a CIVIQ group'),
    'Open the group to start participating.',
    'group_invite',
    false,
    '/chats/' || target_conversation_id::text,
    'Open group',
    auth.uid()
  from unnest(normalized_members) as id
  where exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.user_id = id
      and cp.joined_at > now() - interval '5 seconds'
  );

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;

  return inserted_count;
end;
$$;

create or replace function public.remove_group_member(
  target_conversation_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role text := public.group_role(target_conversation_id);
  target_role text := public.group_role(target_conversation_id, target_user_id);
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if actor_role is null then
    raise exception 'Group access denied.';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'Use leave group instead.';
  end if;

  if actor_role = 'member' then
    raise exception 'Only group admins can remove members.';
  end if;

  if actor_role = 'admin' and target_role <> 'member' then
    raise exception 'Admins can only remove regular members.';
  end if;

  if target_role = 'owner' then
    raise exception 'The owner cannot be removed.';
  end if;

  delete from public.conversation_participants
  where conversation_id = target_conversation_id
    and user_id = target_user_id;

  insert into public.group_events (conversation_id, actor_id, target_user_id, event_type)
  values (target_conversation_id, auth.uid(), target_user_id, 'member_removed');

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;
end;
$$;

create or replace function public.leave_group(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  my_role text := public.group_role(target_conversation_id);
  other_owner_count int;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if my_role is null then
    raise exception 'Group access denied.';
  end if;

  if my_role = 'owner' then
    select count(*)
    into other_owner_count
    from public.conversation_participants
    where conversation_id = target_conversation_id
      and user_id <> auth.uid()
      and role = 'owner';

    if other_owner_count = 0 then
      raise exception 'Transfer ownership before leaving this group.';
    end if;
  end if;

  delete from public.conversation_participants
  where conversation_id = target_conversation_id
    and user_id = auth.uid();

  insert into public.group_events (conversation_id, actor_id, target_user_id, event_type)
  values (target_conversation_id, auth.uid(), auth.uid(), 'left_group');

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;
end;
$$;

create or replace function public.update_group_profile(
  target_conversation_id uuid,
  group_title text default null,
  group_description text default null,
  group_photo_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  my_role text := public.group_role(target_conversation_id);
  normalized_title text := nullif(trim(coalesce(group_title, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if my_role not in ('owner', 'admin') then
    raise exception 'Only group admins can edit group details.';
  end if;

  if group_title is not null and normalized_title is null then
    raise exception 'Group name is required.';
  end if;

  if normalized_title is not null and length(normalized_title) > 50 then
    raise exception 'Group name must be 50 characters or fewer.';
  end if;

  update public.conversations
  set
    title = coalesce(normalized_title, title),
    group_description = case
      when group_description is null then public.conversations.group_description
      else nullif(trim(group_description), '')
    end,
    group_photo_url = case
      when group_photo_url is null then public.conversations.group_photo_url
      else nullif(trim(group_photo_url), '')
    end,
    updated_at = now()
  where id = target_conversation_id
    and conversation_type = 'group';

  insert into public.group_events (conversation_id, actor_id, event_type)
  values (target_conversation_id, auth.uid(), 'group_updated');
end;
$$;

create or replace function public.set_group_member_role(
  target_conversation_id uuid,
  target_user_id uuid,
  target_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if public.group_role(target_conversation_id) <> 'owner' then
    raise exception 'Only the owner can change admin roles.';
  end if;

  if target_role not in ('member', 'admin', 'owner') then
    raise exception 'Invalid group role.';
  end if;

  if target_user_id = auth.uid() and target_role <> 'owner' then
    raise exception 'The owner cannot demote themselves.';
  end if;

  update public.conversation_participants
  set role = target_role
  where conversation_id = target_conversation_id
    and user_id = target_user_id;

  insert into public.group_events (
    conversation_id,
    actor_id,
    target_user_id,
    event_type,
    metadata
  )
  values (
    target_conversation_id,
    auth.uid(),
    target_user_id,
    'role_changed',
    jsonb_build_object('role', target_role)
  );
end;
$$;

create or replace function public.report_group(
  target_conversation_id uuid,
  reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Group access denied.';
  end if;

  insert into public.group_reports (conversation_id, reporter_id, reason)
  values (target_conversation_id, auth.uid(), nullif(trim(coalesce(reason, '')), ''))
  on conflict (conversation_id, reporter_id) do update
    set reason = excluded.reason,
        created_at = now();

  insert into public.group_events (conversation_id, actor_id, event_type)
  values (target_conversation_id, auth.uid(), 'group_reported');
end;
$$;

create or replace function public.delete_group(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if public.group_role(target_conversation_id) <> 'owner' then
    raise exception 'Only the owner can delete this group.';
  end if;

  insert into public.group_events (conversation_id, actor_id, event_type)
  values (target_conversation_id, auth.uid(), 'group_deleted');

  delete from public.conversations
  where id = target_conversation_id
    and conversation_type = 'group';
end;
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
    lm.content as last_message_content,
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
  left join lateral (
    with members as (
      select p.username, cp.joined_at
      from public.conversation_participants cp
      join public.profiles p on p.id = cp.user_id
      where cp.conversation_id = c.id
        and cp.user_id <> auth.uid()
      order by cp.joined_at
    )
    select
      (select count(*) from public.conversation_participants cp2 where cp2.conversation_id = c.id) as member_count,
      case
        when c.conversation_type <> 'group' then null
        else concat_ws(
          '',
          (
            select string_agg(coalesce(nullif(username, ''), 'CIVIQ Member'), ', ')
            from (select username from members limit 2) first_members
          ),
          case
            when (select count(*) from members) > 2
            then ' +' || ((select count(*) from members) - 2)::text
            else ''
          end
        )
      end as member_summary
  ) group_meta on true
  where mine.user_id = auth.uid()
  order by coalesce(lm.created_at, c.updated_at, c.created_at) desc;
$$;

alter table public.group_events enable row level security;
alter table public.group_reports enable row level security;

drop policy if exists "Participants can read group events" on public.group_events;
create policy "Participants can read group events"
  on public.group_events for select
  to authenticated
  using (public.is_conversation_participant(conversation_id));

drop policy if exists "Users can read own group reports" on public.group_reports;
create policy "Users can read own group reports"
  on public.group_reports for select
  to authenticated
  using (reporter_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.group_events;
exception
  when duplicate_object then null;
end $$;

grant execute on function public.group_role(uuid, uuid) to authenticated;
grant execute on function public.can_manage_group(uuid) to authenticated;
grant execute on function public.create_group_conversation(text, uuid[], text, text) to authenticated;
grant execute on function public.list_group_members(uuid, int) to authenticated;
grant execute on function public.add_group_members(uuid, uuid[]) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.update_group_profile(uuid, text, text, text) to authenticated;
grant execute on function public.set_group_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.report_group(uuid, text) to authenticated;
grant execute on function public.delete_group(uuid) to authenticated;
grant execute on function public.list_conversations() to authenticated;
