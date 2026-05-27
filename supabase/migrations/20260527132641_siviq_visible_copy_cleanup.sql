begin;

do $$
declare
  profile_function text;
begin
  select pg_get_functiondef('public.handle_new_user_profile()'::regprocedure)
  into profile_function;

  profile_function := replace(
    profile_function,
    'Create your first civic project report.',
    'Create your first SIVIQ project report.'
  );
  execute profile_function;
end;
$$;

update public.notifications
set
  title = replace(title, 'Create your first civic project report.', 'Create your first SIVIQ project report.'),
  body = replace(body, 'civic', 'SIVIQ')
where title like '%civic%'
   or body like '%civic%';

commit;
