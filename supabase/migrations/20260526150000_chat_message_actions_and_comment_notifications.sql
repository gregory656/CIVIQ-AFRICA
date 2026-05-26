begin;

alter table public.messages
  add column if not exists edited_at timestamptz;

alter table public.conversation_participants
  add column if not exists deleted_at timestamptz;

create table if not exists public.message_hidden_users (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'spam',
  created_at timestamptz not null default now(),
  unique (message_id, reporter_id)
);

create index if not exists idx_message_hidden_users_user
  on public.message_hidden_users (user_id, hidden_at desc);

create index if not exists idx_message_reports_message
  on public.message_reports (message_id, created_at desc);

create index if not exists idx_conversation_participants_user_active
  on public.conversation_participants (user_id, deleted_at, is_archived, joined_at desc);

alter table public.message_hidden_users enable row level security;
alter table public.message_reports enable row level security;

drop policy if exists "Users can read own hidden messages" on public.message_hidden_users;
create policy "Users can read own hidden messages"
  on public.message_hidden_users for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can hide own message copies" on public.message_hidden_users;
create policy "Users can hide own message copies"
  on public.message_hidden_users for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own message reports" on public.message_reports;
create policy "Users can read own message reports"
  on public.message_reports for select
  to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists "Users can report messages" on public.message_reports;
create policy "Users can report messages"
  on public.message_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

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
  replied_message public.messages;
  conversation_kind text;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Conversation access denied.';
  end if;

  select conversation_type into conversation_kind
  from public.conversations
  where id = target_conversation_id;

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

  if target_reply_to_message_id is not null then
    select *
    into replied_message
    from public.messages m
    where m.id = target_reply_to_message_id
      and m.conversation_id = target_conversation_id
      and m.deleted_at is null;

    if replied_message.id is null then
      raise exception 'Reply target was not found.';
    end if;
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

  update public.conversation_participants
  set deleted_at = null
  where conversation_id = target_conversation_id
    and user_id = auth.uid();

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

  if conversation_kind = 'group'
     and replied_message.id is not null
     and replied_message.sender_id is not null
     and replied_message.sender_id <> auth.uid() then
    select coalesce(nullif(username, ''), 'A SIVIQ user')
    into actor_name
    from public.profiles
    where id = auth.uid();

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
      replied_message.sender_id,
      actor_name || ' replied to your message',
      coalesce(left(new_message.content, 160), 'Open the group chat to view the reply.'),
      'group_message_reply',
      false,
      '/chats/' || target_conversation_id::text,
      'Open chat',
      auth.uid()
    );
  end if;

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;

  return new_message;
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
    peer.role_label as peer_role_label
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
            select string_agg(coalesce(nullif(username, ''), 'SIVIQ Member'), ', ')
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
    and mine.deleted_at is null
  order by coalesce(lm.created_at, c.updated_at, c.created_at) desc;
$$;

drop function if exists public.list_conversation_messages(uuid, timestamptz, int);
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
  reply_to_content text,
  reply_to_sender_id uuid,
  reply_to_sender_username text,
  is_edited boolean,
  edited_at timestamptz,
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
    case when replied.deleted_at is null then replied.content else 'Message deleted' end as reply_to_content,
    replied.sender_id as reply_to_sender_id,
    replied_sender.username as reply_to_sender_username,
    m.is_edited,
    m.edited_at,
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
  left join public.messages replied on replied.id = m.reply_to_message_id
  left join public.profiles replied_sender on replied_sender.id = replied.sender_id
  left join public.profiles p on p.id = m.sender_id
  where m.conversation_id = target_conversation_id
    and public.is_conversation_participant(target_conversation_id)
    and not exists (
      select 1 from public.message_hidden_users hidden
      where hidden.message_id = m.id and hidden.user_id = auth.uid()
    )
    and (
      before_message_created_at is null
      or m.created_at < before_message_created_at
    )
  order by m.created_at desc
  limit least(greatest(coalesce(result_limit, 50), 1), 100);
$$;

create or replace function public.edit_message(
  target_message_id uuid,
  body text
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_message public.messages;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  update public.messages m
  set content = nullif(trim(coalesce(body, '')), ''),
      is_edited = true,
      edited_at = now(),
      updated_at = now()
  where m.id = target_message_id
    and m.sender_id = auth.uid()
    and m.deleted_at is null
    and m.created_at >= now() - interval '5 minutes'
    and nullif(trim(coalesce(body, '')), '') is not null
  returning * into updated_message;

  if updated_message.id is null then
    raise exception 'Messages can only be edited by the sender within 5 minutes.';
  end if;

  update public.conversations
  set updated_at = now()
  where id = updated_message.conversation_id;

  return updated_message;
end;
$$;

create or replace function public.delete_message_for_me(target_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select m.conversation_id into target_conversation_id
  from public.messages m
  where m.id = target_message_id;

  if target_conversation_id is null or not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Message access denied.';
  end if;

  insert into public.message_hidden_users (message_id, user_id)
  values (target_message_id, auth.uid())
  on conflict (message_id, user_id) do update
    set hidden_at = now();
end;
$$;

create or replace function public.delete_message_for_everyone(target_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  update public.messages m
  set deleted_at = now(),
      is_edited = false,
      edited_at = null,
      updated_at = now()
  where m.id = target_message_id
    and m.sender_id = auth.uid()
    and m.deleted_at is null
  returning m.conversation_id into target_conversation_id;

  if target_conversation_id is null then
    raise exception 'Only the sender can delete this message for everyone.';
  end if;

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;
end;
$$;

create or replace function public.report_message_spam(
  target_message_id uuid,
  report_reason text default 'spam'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select m.conversation_id into target_conversation_id
  from public.messages m
  where m.id = target_message_id;

  if target_conversation_id is null or not public.is_conversation_participant(target_conversation_id) then
    raise exception 'Message access denied.';
  end if;

  insert into public.message_reports (message_id, reporter_id, reason)
  values (target_message_id, auth.uid(), coalesce(nullif(trim(report_reason), ''), 'spam'))
  on conflict (message_id, reporter_id) do update
    set reason = excluded.reason,
        created_at = now();
end;
$$;

create or replace function public.archive_conversation_for_me(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversation_participants
  set is_archived = true
  where conversation_id = target_conversation_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.delete_conversation_for_me(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversation_participants
  set deleted_at = now(),
      is_archived = true
  where conversation_id = target_conversation_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.notify_social_comment_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  recipient_id uuid;
  notice_title text;
  notice_body text;
begin
  if new.author_id is null then
    return new;
  end if;

  select coalesce(nullif(username, ''), 'A SIVIQ user')
  into actor_name
  from public.profiles
  where id = new.author_id;

  if new.parent_comment_id is not null then
    select author_id into recipient_id
    from public.social_post_comments
    where id = new.parent_comment_id;
    notice_title := actor_name || ' replied to your comment';
  else
    select author_id into recipient_id
    from public.social_posts
    where id = new.post_id;
    notice_title := actor_name || ' commented on your post';
  end if;

  if recipient_id is null or recipient_id = new.author_id then
    return new;
  end if;

  notice_body := left(new.body, 160);

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
    recipient_id,
    notice_title,
    notice_body,
    case when new.parent_comment_id is null then 'social_post_comment' else 'social_comment_reply' end,
    false,
    '/home',
    'Open post',
    new.author_id
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_social_comment_activity on public.social_post_comments;
create trigger trg_notify_social_comment_activity
  after insert on public.social_post_comments
  for each row execute function public.notify_social_comment_activity();

create or replace function public.notify_project_comment_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  recipient_id uuid;
  notice_title text;
begin
  if new.author_id is null then
    return new;
  end if;

  select coalesce(nullif(username, ''), 'A SIVIQ user')
  into actor_name
  from public.profiles
  where id = new.author_id;

  if new.parent_comment_id is not null then
    select author_id into recipient_id
    from public.project_comments
    where id = new.parent_comment_id;
    notice_title := actor_name || ' replied to your comment';
  else
    select creator_id into recipient_id
    from public.projects
    where id = new.project_id;
    notice_title := actor_name || ' commented on your project';
  end if;

  if recipient_id is null or recipient_id = new.author_id then
    return new;
  end if;

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
    recipient_id,
    notice_title,
    left(new.body, 160),
    case when new.parent_comment_id is null then 'project_comment' else 'project_comment_reply' end,
    false,
    '/projects',
    'Open project',
    new.author_id
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_project_comment_activity on public.project_comments;
create trigger trg_notify_project_comment_activity
  after insert on public.project_comments
  for each row execute function public.notify_project_comment_activity();

grant select, insert on public.message_hidden_users to authenticated;
grant select, insert on public.message_reports to authenticated;
grant execute on function public.send_message(uuid, text, text, text, uuid) to authenticated;
grant execute on function public.list_conversations() to authenticated;
grant execute on function public.list_conversation_messages(uuid, timestamptz, int) to authenticated;
grant execute on function public.edit_message(uuid, text) to authenticated;
grant execute on function public.delete_message_for_me(uuid) to authenticated;
grant execute on function public.delete_message_for_everyone(uuid) to authenticated;
grant execute on function public.report_message_spam(uuid, text) to authenticated;
grant execute on function public.archive_conversation_for_me(uuid) to authenticated;
grant execute on function public.delete_conversation_for_me(uuid) to authenticated;

commit;
