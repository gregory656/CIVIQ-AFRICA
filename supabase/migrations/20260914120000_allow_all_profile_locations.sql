begin;

-- A location belongs to a profile; it must never be exclusive to one profile.
-- Remove every legacy uniqueness rule containing the location columns, not
-- only the old single-column subcounty rule. This lets all counties and their
-- constituencies be selected by any number of residents.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select constraint_info.conname
    from pg_constraint constraint_info
    join pg_class relation on relation.oid = constraint_info.conrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'profiles'
      and constraint_info.contype = 'u'
      and exists (
        select 1
        from unnest(constraint_info.conkey) as key_column(attnum)
        join pg_attribute attribute
          on attribute.attrelid = relation.oid and attribute.attnum = key_column.attnum
        where attribute.attname in ('county_id', 'subcounty_id')
      )
  loop
    execute format('alter table public.profiles drop constraint %I', constraint_name);
  end loop;
end;
$$;

commit;
