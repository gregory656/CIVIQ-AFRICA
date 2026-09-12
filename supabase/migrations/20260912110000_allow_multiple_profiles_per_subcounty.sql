do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class relation on relation.oid = con.conrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'profiles'
      and con.contype = 'u'
      and con.conkey = array[
        (select attnum from pg_attribute
         where attrelid = relation.oid and attname = 'subcounty_id')
      ]
  loop
    execute format('alter table public.profiles drop constraint %I', constraint_name);
  end loop;
end;
$$;
