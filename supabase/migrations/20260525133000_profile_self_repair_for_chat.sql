create or replace function public.ensure_current_profile()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_email text := coalesce(auth.jwt() ->> 'email', '');
begin
  if current_user_id is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.profiles (id, email, updated_at)
  values (current_user_id, current_email, now())
  on conflict (id) do update
    set email = coalesce(nullif(public.profiles.email, ''), excluded.email),
        updated_at = now();
end;
$$;

drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can read visible profiles" on public.profiles;
create policy "Users can read visible profiles"
  on public.profiles for select
  to authenticated
  using (deleted_at is null or auth.uid() = id);

grant execute on function public.ensure_current_profile() to authenticated;
