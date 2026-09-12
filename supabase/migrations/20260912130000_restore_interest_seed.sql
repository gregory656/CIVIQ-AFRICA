insert into public.interests (name)
values
  ('Infrastructure'),
  ('Roads'),
  ('Water'),
  ('Healthcare'),
  ('Education'),
  ('Jobs'),
  ('Youth'),
  ('Environment'),
  ('Safety'),
  ('Housing'),
  ('Technology'),
  ('Governance')
on conflict (name) do nothing;
