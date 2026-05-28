begin;

alter table public.profiles
  add column if not exists display_name text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_display_name_length_check'
  ) then
    alter table public.profiles
      add constraint profiles_display_name_length_check
      check (
        display_name is null
        or (
          char_length(trim(display_name)) between 2 and 80
          and display_name !~ '[\r\n\t]'
        )
      )
      not valid;
  end if;
end $$;

create index if not exists idx_profiles_display_name
  on public.profiles (display_name);

drop function if exists public.get_profile_summary(uuid);
create or replace function public.get_profile_summary(target_user_id uuid)
returns table (
  id uuid,
  email text,
  display_name text,
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
    p.display_name,
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

drop function if exists public.discover_civiq_profiles();
create or replace function public.discover_civiq_profiles()
returns table (
  id uuid,
  display_name text,
  username text,
  civiq_code text,
  avatar_url text,
  is_verified boolean,
  role_label text,
  role text
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
    p.role
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
    case p.role
      when 'super_admin' then 0
      when 'admin' then 1
      when 'moderator' then 2
      else 3
    end,
    p.is_verified desc,
    p.display_name nulls last,
    p.username nulls last,
    p.created_at desc;
$$;

drop function if exists public.search_chat_profiles(text, int);
create or replace function public.search_chat_profiles(
  query_text text,
  result_limit int default 20
)
returns table (
  id uuid,
  display_name text,
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
    p.display_name,
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
      or p.display_name ilike '%' || query_text || '%'
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
    p.display_name nulls last,
    p.username nulls last,
    p.created_at desc
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

drop function if exists public.list_group_members(uuid, int);
create or replace function public.list_group_members(
  target_conversation_id uuid,
  result_limit int default 100
)
returns table (
  user_id uuid,
  display_name text,
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
    p.display_name,
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
    p.display_name nulls last,
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
  peer_display_name text,
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
    peer.display_name as peer_display_name,
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
      p.display_name,
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
      select p.display_name, p.username, cp.joined_at
      from public.conversation_participants cp
      join public.profiles p on p.id = cp.user_id
      where cp.conversation_id = c.id
        and cp.user_id <> auth.uid()
      order by cp.joined_at
      limit 3
    )
    select
      count(*)::bigint as member_count,
      string_agg(
        coalesce(nullif(display_name, ''), '@' || nullif(username, ''), 'SIVIQ Member'),
        ', '
        order by joined_at
      ) as member_summary
    from members
  ) group_meta on true
  where mine.user_id = auth.uid()
    and mine.deleted_at is null
  order by c.updated_at desc;
$$;

create or replace view public.v_social_post_feed as
select
  p.id,
  p.author_id,
  p.body,
  p.image_url,
  p.like_count,
  p.comment_count,
  p.share_count,
  p.created_at,
  profile.username as author_username,
  profile.avatar_url as author_avatar_url,
  profile.is_verified as author_is_verified,
  exists (
    select 1
    from public.social_post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  p.moderation_status,
  profile.role as author_role,
  profile.display_name as author_display_name
from public.social_posts p
left join public.profiles profile on profile.id = p.author_id
where p.deleted_at is null
  and p.moderation_status = 'active'
  and not exists (
    select 1
    from public.social_post_hidden_users hidden
    where hidden.post_id = p.id and hidden.user_id = auth.uid()
  );

create or replace view public.v_project_feed as
select
  p.id,
  p.creator_id,
  p.title,
  p.description,
  p.project_type,
  p.county_id,
  c.name as county_name,
  p.subcounty_id,
  s.name as subcounty_name,
  p.location_name,
  p.image_url,
  p.verification_status,
  p.approval_count,
  p.disapproval_count,
  (
    select count(*)::int
    from public.project_comments pc
    where pc.project_id = p.id
      and pc.deleted_at is null
      and pc.moderation_status = 'active'
  ) as comment_count,
  p.score,
  p.created_at,
  pr.username as creator_username,
  pr.avatar_url as creator_avatar_url,
  pr.is_verified as creator_is_verified,
  p.moderation_status,
  pr.role as creator_role,
  pr.display_name as creator_display_name
from public.projects p
left join public.counties c on c.id = p.county_id
left join public.subcounties s on s.id = p.subcounty_id
left join public.profiles pr on pr.id = p.creator_id
where p.deleted_at is null
  and p.verification_status <> 'flagged'
  and p.moderation_status = 'active';

create or replace view public.v_social_post_comments as
select
  c.id,
  c.post_id,
  c.parent_comment_id,
  c.author_id,
  c.body,
  c.created_at,
  c.edited_at,
  p.username as author_username,
  p.avatar_url as author_avatar_url,
  p.is_verified as author_is_verified,
  (
    select count(*)::int
    from public.social_post_comment_likes l
    where l.comment_id = c.id
  ) as like_count,
  (
    select count(*)::int
    from public.social_post_comments r
    where r.parent_comment_id = c.id
      and r.deleted_at is null
      and r.moderation_status = 'active'
  ) as reply_count,
  exists (
    select 1
    from public.social_post_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  c.moderation_status,
  p.role as author_role,
  p.display_name as author_display_name
from public.social_post_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null
  and c.moderation_status = 'active';

create or replace view public.v_project_comments as
select
  c.id,
  c.project_id,
  c.parent_comment_id,
  c.author_id,
  c.body,
  c.created_at,
  c.edited_at,
  p.username as author_username,
  p.avatar_url as author_avatar_url,
  p.is_verified as author_is_verified,
  (
    select count(*)::int
    from public.project_comment_likes l
    where l.comment_id = c.id
  ) as like_count,
  (
    select count(*)::int
    from public.project_comments r
    where r.parent_comment_id = c.id
      and r.deleted_at is null
      and r.moderation_status = 'active'
  ) as reply_count,
  exists (
    select 1
    from public.project_comment_likes l
    where l.comment_id = c.id and l.user_id = auth.uid()
  ) as viewer_has_liked,
  c.moderation_status,
  p.role as author_role,
  p.display_name as author_display_name
from public.project_comments c
left join public.profiles p on p.id = c.author_id
where c.deleted_at is null
  and c.moderation_status = 'active';

grant execute on function public.get_profile_summary(uuid) to authenticated;
grant execute on function public.discover_civiq_profiles() to authenticated;
grant execute on function public.search_chat_profiles(text, int) to authenticated;
grant execute on function public.list_group_members(uuid, int) to authenticated;
grant execute on function public.list_conversations() to authenticated;
grant select on public.v_social_post_feed to authenticated;
grant select on public.v_project_feed to authenticated;
grant select on public.v_social_post_comments to authenticated;
grant select on public.v_project_comments to authenticated;

commit;
