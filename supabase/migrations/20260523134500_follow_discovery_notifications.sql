alter table public.notifications
  add column if not exists action_route text,
  add column if not exists action_label text,
  add column if not exists actor_profile_id uuid references public.profiles(id) on delete set null;

create or replace function public.follow_profile(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  follower_user_id uuid := auth.uid();
  follower_name text;
  inserted_count int;
begin
  if follower_user_id is null then
    raise exception 'You must be signed in to follow an account.';
  end if;

  if follower_user_id = target_user_id then
    raise exception 'You cannot follow yourself.';
  end if;

  insert into public.follows (follower_id, following_id)
  values (follower_user_id, target_user_id)
  on conflict do nothing;

  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return;
  end if;

  select coalesce(nullif(username, ''), 'A CIVIQ user')
  into follower_name
  from public.profiles
  where id = follower_user_id;

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
    target_user_id,
    follower_name || ' followed you',
    'Tap to follow them back.',
    'social_follow',
    false,
    '/profile/' || follower_user_id::text,
    'Follow back',
    follower_user_id
  );
end;
$$;

grant execute on function public.follow_profile(uuid) to authenticated;

create index if not exists idx_notifications_actor_profile
  on public.notifications (actor_profile_id, created_at desc);

create index if not exists idx_notifications_user_category_created
  on public.notifications (user_id, category, created_at desc)
  where deleted_at is null;
