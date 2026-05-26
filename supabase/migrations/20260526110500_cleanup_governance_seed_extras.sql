begin;

with stale_locations(county_name, subcounty_name) as (
  values
    ('Embu', 'Embu (CWR)'),
    ('Homa Bay', 'Homa Bay (CWR)'),
    ('Homa Bay', 'Rongo'),
    ('Homa Bay', 'Suna West'),
    ('Kakamega', 'Kakamega (CWR)'),
    ('Kakamega', 'Kiharu'),
    ('Nairobi', 'Gatundu North'),
    ('Nairobi', 'Royasambu'),
    ('Narok', 'Baringo North'),
    ('Siaya', 'Siaya (CWR)')
),
stale_subcounties as (
  select s.id
  from public.subcounties s
  join public.counties c on c.id = s.county_id
  join stale_locations stale
    on stale.county_name = c.name
   and stale.subcounty_name = s.name
)
delete from public.leaders l
using stale_subcounties stale
where l.subcounty_id = stale.id;

with stale_locations(county_name, subcounty_name) as (
  values
    ('Embu', 'Embu (CWR)'),
    ('Homa Bay', 'Homa Bay (CWR)'),
    ('Homa Bay', 'Rongo'),
    ('Homa Bay', 'Suna West'),
    ('Kakamega', 'Kakamega (CWR)'),
    ('Kakamega', 'Kiharu'),
    ('Nairobi', 'Gatundu North'),
    ('Nairobi', 'Royasambu'),
    ('Narok', 'Baringo North'),
    ('Siaya', 'Siaya (CWR)')
)
delete from public.subcounties s
using public.counties c, stale_locations stale
where c.id = s.county_id
  and stale.county_name = c.name
  and stale.subcounty_name = s.name;

commit;
