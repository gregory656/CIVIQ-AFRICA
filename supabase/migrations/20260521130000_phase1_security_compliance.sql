create extension if not exists "pgcrypto";

create table if not exists public.legal_acceptance_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  policy_type text,
  policy_name text,
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  ip_address text,
  device_id text,
  user_agent text
);

alter table public.legal_acceptance_logs
  add column if not exists policy_type text,
  add column if not exists policy_name text,
  add column if not exists ip_address text,
  add column if not exists device_id text,
  add column if not exists user_agent text;

update public.legal_acceptance_logs
set policy_type = coalesce(policy_type, policy_name)
where policy_type is null;

alter table public.legal_acceptance_logs
  alter column policy_type set not null;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  scheduled_purge_at timestamptz not null,
  cancelled_at timestamptz,
  completed_at timestamptz,
  unique (user_id)
);

alter table public.profiles
  add column if not exists deleted_at timestamptz;

alter table public.notifications enable row level security;
alter table public.legal_acceptance_logs enable row level security;
alter table public.account_deletion_requests enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can create own notifications" on public.notifications;
create policy "Users can create own notifications"
  on public.notifications for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can create own legal acceptances" on public.legal_acceptance_logs;
create policy "Users can create own legal acceptances"
  on public.legal_acceptance_logs for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own legal acceptances" on public.legal_acceptance_logs;
create policy "Users can read own legal acceptances"
  on public.legal_acceptance_logs for select
  using (auth.uid() = user_id);

drop policy if exists "Users can request own account deletion" on public.account_deletion_requests;
create policy "Users can request own account deletion"
  on public.account_deletion_requests for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own account deletion request" on public.account_deletion_requests;
create policy "Users can update own account deletion request"
  on public.account_deletion_requests for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own account deletion request" on public.account_deletion_requests;
create policy "Users can read own account deletion request"
  on public.account_deletion_requests for select
  using (auth.uid() = user_id);

create index if not exists idx_notifications_user_unread
  on public.notifications (user_id, is_read, created_at desc);

create index if not exists idx_legal_acceptance_user_policy
  on public.legal_acceptance_logs (user_id, policy_type, policy_version);

create index if not exists idx_account_deletion_scheduled
  on public.account_deletion_requests (scheduled_purge_at)
  where cancelled_at is null and completed_at is null;
