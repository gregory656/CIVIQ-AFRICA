alter table public.notifications
  add column if not exists archived_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists spam_reported_at timestamptz;

create index if not exists idx_notifications_user_active
  on public.notifications (user_id, archived_at, deleted_at, created_at desc);

create index if not exists idx_notifications_user_archived
  on public.notifications (user_id, archived_at desc)
  where archived_at is not null and deleted_at is null;
