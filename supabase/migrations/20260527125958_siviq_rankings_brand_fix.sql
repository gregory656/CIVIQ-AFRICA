begin;

do $$
declare
  ranking_function text;
begin
  select pg_get_functiondef('public.execute_weekly_rankings_snapshot()'::regprocedure)
  into ranking_function;

  ranking_function := replace(ranking_function, 'CIVIQ top 20', 'SIVIQ top 20');
  execute ranking_function;
end;
$$;

update public.notifications
set
  title = replace(title, 'CIVIQ', 'SIVIQ'),
  body = replace(body, 'CIVIQ', 'SIVIQ')
where category = 'rankings'
  and (title like '%CIVIQ%' or body like '%CIVIQ%');

select cron.unschedule('civiq_weekly_rankings_job')
where exists (
  select 1 from cron.job where jobname = 'civiq_weekly_rankings_job'
);

select cron.unschedule('siviq_weekly_rankings_job')
where exists (
  select 1 from cron.job where jobname = 'siviq_weekly_rankings_job'
);

select cron.schedule(
  'siviq_weekly_rankings_job',
  '0 21 * * 6',
  'select public.execute_weekly_rankings_snapshot();'
);

commit;
