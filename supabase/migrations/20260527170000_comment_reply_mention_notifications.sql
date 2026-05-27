begin;

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
    notice_title := actor_name || ' mentioned you in a comment';
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
    notice_title := actor_name || ' mentioned you in a comment';
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

commit;

