do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'audit_logs'
      and con.contype = 'f'
      and pg_get_constraintdef(con.oid) like '%profiles%'
  loop
    execute format('alter table public.audit_logs drop constraint %I', constraint_name);
  end loop;

  if to_regclass('public.audit_logs') is not null then
    alter table public.audit_logs
      add constraint audit_logs_user_id_fkey
      foreign key (user_id) references public.profiles(id) on delete cascade;
  end if;

  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'security_events'
      and con.contype = 'f'
      and pg_get_constraintdef(con.oid) like '%profiles%'
  loop
    execute format('alter table public.security_events drop constraint %I', constraint_name);
  end loop;

  if to_regclass('public.security_events') is not null then
    alter table public.security_events
      add constraint security_events_user_id_fkey
      foreign key (user_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

alter table if exists public.profiles enable row level security;
alter table if exists public.sessions enable row level security;
alter table if exists public.user_sessions enable row level security;
alter table if exists public.audit_logs enable row level security;
alter table if exists public.security_events enable row level security;
alter table if exists public.legal_acceptance_logs enable row level security;

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can read own security events" on public.security_events;
create policy "Users can read own security events"
  on public.security_events for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create own security events" on public.security_events;
create policy "Users can create own security events"
  on public.security_events for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own audit logs" on public.audit_logs;
create policy "Users can read own audit logs"
  on public.audit_logs for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create own audit logs" on public.audit_logs;
create policy "Users can create own audit logs"
  on public.audit_logs for insert
  with check (auth.uid() = user_id);

do $$
begin
  if to_regclass('public.sessions') is not null then
    drop policy if exists "Users can read own sessions" on public.sessions;
    create policy "Users can read own sessions"
      on public.sessions for select
      using (auth.uid() = user_id);

    drop policy if exists "Users can create own sessions" on public.sessions;
    create policy "Users can create own sessions"
      on public.sessions for insert
      with check (auth.uid() = user_id);

    drop policy if exists "Users can update own sessions" on public.sessions;
    create policy "Users can update own sessions"
      on public.sessions for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if to_regclass('public.user_sessions') is not null then
    drop policy if exists "Users can read own user sessions" on public.user_sessions;
    create policy "Users can read own user sessions"
      on public.user_sessions for select
      using (auth.uid() = user_id);

    drop policy if exists "Users can create own user sessions" on public.user_sessions;
    create policy "Users can create own user sessions"
      on public.user_sessions for insert
      with check (auth.uid() = user_id);

    drop policy if exists "Users can update own user sessions" on public.user_sessions;
    create policy "Users can update own user sessions"
      on public.user_sessions for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

create index if not exists idx_security_events_user_created
  on public.security_events (user_id, created_at desc);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'audit_logs'
      and column_name = 'timestamp'
  ) then
    create index if not exists idx_audit_logs_user_timestamp
      on public.audit_logs (user_id, timestamp desc);
  elsif exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'audit_logs'
      and column_name = 'created_at'
  ) then
    create index if not exists idx_audit_logs_user_created
      on public.audit_logs (user_id, created_at desc);
  end if;
end $$;
