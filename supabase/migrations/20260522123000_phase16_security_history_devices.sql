create table if not exists public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_label text not null,
  platform text,
  device_fingerprint text,
  last_seen_at timestamptz not null default now(),
  trusted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_fingerprint)
);

create table if not exists public.app_error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  area text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.data_export_requests
  add column if not exists status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed', 'expired'));

update public.data_export_requests
set status = case
  when completed_at is not null and expires_at is not null and expires_at < now() then 'expired'
  when completed_at is not null then 'completed'
  else status
end;

alter table public.trusted_devices enable row level security;
alter table public.app_error_logs enable row level security;

drop policy if exists "Users can read own trusted devices" on public.trusted_devices;
create policy "Users can read own trusted devices"
  on public.trusted_devices for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create own trusted devices" on public.trusted_devices;
create policy "Users can create own trusted devices"
  on public.trusted_devices for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own trusted devices" on public.trusted_devices;
create policy "Users can update own trusted devices"
  on public.trusted_devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can create own error logs" on public.app_error_logs;
create policy "Users can create own error logs"
  on public.app_error_logs for insert
  with check (auth.uid() = user_id);

create index if not exists idx_trusted_devices_user_seen
  on public.trusted_devices (user_id, last_seen_at desc);

create index if not exists idx_data_export_requests_user_status
  on public.data_export_requests (user_id, status, requested_at desc);

create index if not exists idx_app_error_logs_user_created
  on public.app_error_logs (user_id, created_at desc);

create or replace function public.create_security_alert(
  p_user_id uuid,
  p_event_type text,
  p_title text,
  p_body text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  event_id uuid;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Not allowed';
  end if;

  insert into public.security_events (user_id, event_type, metadata)
  values (p_user_id, p_event_type, coalesce(p_metadata, '{}'::jsonb))
  returning id into event_id;

  insert into public.notifications (user_id, title, body, category, is_read)
  values (p_user_id, p_title, p_body, 'security', false);

  return event_id;
end;
$$;

grant execute on function public.create_security_alert(uuid, text, text, text, jsonb)
  to authenticated;
