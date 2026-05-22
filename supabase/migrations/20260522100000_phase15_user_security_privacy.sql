alter table public.profiles
  add column if not exists is_public boolean not null default false,
  add column if not exists show_online_status boolean not null default true,
  add column if not exists show_read_receipts boolean not null default true,
  add column if not exists allow_message_requests boolean not null default true,
  add column if not exists show_activity boolean not null default false,
  add column if not exists last_seen timestamptz;

alter table public.notifications
  add column if not exists category text not null default 'general';

create table if not exists public.notification_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  push_enabled boolean not null default true,
  notification_sound text not null default 'default'
    check (notification_sound in ('default', 'soft', 'alert', 'silent')),
  messages_enabled boolean not null default true,
  project_updates_enabled boolean not null default true,
  moderation_alerts_enabled boolean not null default true,
  rankings_enabled boolean not null default true,
  security_alerts_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint security_alerts_always_enabled check (security_alerts_enabled = true)
);

create table if not exists public.data_export_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz
);

alter table public.notification_settings enable row level security;
alter table public.data_export_requests enable row level security;

drop policy if exists "Users can read own notification settings" on public.notification_settings;
create policy "Users can read own notification settings"
  on public.notification_settings for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own notification settings" on public.notification_settings;
create policy "Users can insert own notification settings"
  on public.notification_settings for insert
  with check (auth.uid() = user_id and security_alerts_enabled = true);

drop policy if exists "Users can update own notification settings" on public.notification_settings;
create policy "Users can update own notification settings"
  on public.notification_settings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and security_alerts_enabled = true);

drop policy if exists "Users can read own data export requests" on public.data_export_requests;
create policy "Users can read own data export requests"
  on public.data_export_requests for select
  using (auth.uid() = user_id);

create index if not exists idx_notifications_user_category
  on public.notifications (user_id, category, created_at desc);

create index if not exists idx_data_export_requests_user_requested
  on public.data_export_requests (user_id, requested_at desc);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('user-exports', 'user-exports', false, 10485760, array['application/zip'])
on conflict (id) do nothing;
