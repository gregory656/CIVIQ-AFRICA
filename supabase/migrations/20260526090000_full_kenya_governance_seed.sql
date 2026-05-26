begin;

create extension if not exists pgcrypto;

create table if not exists public.counties (
  id int primary key,
  name text not null unique
);

create table if not exists public.subcounties (
  id int primary key,
  county_id int not null references public.counties(id) on delete cascade,
  name text not null,
  unique (county_id, name)
);

create table if not exists public.leaders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text not null check (role in ('Governor', 'MP')),
  party_name text not null default 'N/A',
  county_id int not null references public.counties(id) on delete cascade,
  subcounty_id int references public.subcounties(id) on delete cascade,
  created_at timestamptz not null default now()
);

create unique index if not exists unique_active_governor on public.leaders (county_id) where (role = 'Governor');
create unique index if not exists unique_active_mp on public.leaders (subcounty_id) where (role = 'MP');

create or replace function public.stage_county(p_id int, p_name text)
returns int
language plpgsql
as $$
declare
  resolved_id int;
  insert_id int;
begin
  select id into resolved_id from public.counties where name = p_name limit 1;
  if resolved_id is not null then
    return resolved_id;
  end if;

  insert_id := p_id;
  if exists (select 1 from public.counties where id = insert_id) then
    insert_id := 100 + p_id;
    while exists (select 1 from public.counties where id = insert_id) loop
      insert_id := insert_id + 100;
    end loop;
  end if;

  insert into public.counties (id, name) values (insert_id, p_name);
  return insert_id;
end;
$$;

create or replace function public.stage_subcounty(p_id int, p_county_name text, p_name text)
returns int
language plpgsql
as $$
declare
  resolved_county_id int;
  resolved_id int;
  insert_id int;
begin
  select id into resolved_county_id from public.counties where name = p_county_name limit 1;
  if resolved_county_id is null then
    raise exception 'County % must be staged before constituency %', p_county_name, p_name;
  end if;

  select id into resolved_id
  from public.subcounties
  where county_id = resolved_county_id and name = p_name
  limit 1;

  if resolved_id is not null then
    return resolved_id;
  end if;

  insert_id := p_id;
  if exists (select 1 from public.subcounties where id = insert_id) then
    select coalesce(max(id), 0) + 1 into insert_id from public.subcounties;
  end if;

  insert into public.subcounties (id, county_id, name)
  values (insert_id, resolved_county_id, p_name);
  return insert_id;
end;
$$;

select public.stage_county(1, 'Mombasa');
select public.stage_county(2, 'Kwale');
select public.stage_county(3, 'Kilifi');
select public.stage_county(4, 'Tana River');
select public.stage_county(5, 'Lamu');
select public.stage_county(6, 'Taita Taveta');
select public.stage_county(7, 'Garissa');
select public.stage_county(8, 'Wajir');
select public.stage_county(9, 'Mandera');
select public.stage_county(10, 'Marsabit');
select public.stage_county(11, 'Isiolo');
select public.stage_county(12, 'Meru');
select public.stage_county(13, 'Tharaka-Nithi');
select public.stage_county(14, 'Embu');
select public.stage_county(15, 'Kitui');
select public.stage_county(16, 'Machakos');
select public.stage_county(17, 'Makueni');
select public.stage_county(18, 'Nyandarua');
select public.stage_county(19, 'Nyeri');
select public.stage_county(20, 'Kirinyaga');
select public.stage_county(21, 'Murang''a');
select public.stage_county(22, 'Kiambu');
select public.stage_county(23, 'Turkana');
select public.stage_county(24, 'West Pokot');
select public.stage_county(25, 'Samburu');
select public.stage_county(26, 'Trans Nzoia');
select public.stage_county(27, 'Uasin Gishu');
select public.stage_county(28, 'Elgeyo-Marakwet');
select public.stage_county(29, 'Nandi');
select public.stage_county(30, 'Baringo');
select public.stage_county(31, 'Laikipia');
select public.stage_county(32, 'Nakuru');
select public.stage_county(33, 'Narok');
select public.stage_county(34, 'Kajiado');
select public.stage_county(35, 'Kericho');
select public.stage_county(36, 'Bomet');
select public.stage_county(37, 'Kakamega');
select public.stage_county(38, 'Vihiga');
select public.stage_county(39, 'Bungoma');
select public.stage_county(40, 'Busia');
select public.stage_county(41, 'Siaya');
select public.stage_county(42, 'Kisumu');
select public.stage_county(43, 'Homa Bay');
select public.stage_county(44, 'Migori');
select public.stage_county(45, 'Kisii');
select public.stage_county(46, 'Nyamira');
select public.stage_county(47, 'Nairobi');

select public.stage_subcounty(101, 'Mombasa', 'Changamwe');
select public.stage_subcounty(102, 'Mombasa', 'Jomvu');
select public.stage_subcounty(103, 'Mombasa', 'Kisauni');
select public.stage_subcounty(104, 'Mombasa', 'Nyali');
select public.stage_subcounty(105, 'Mombasa', 'Likoni');
select public.stage_subcounty(106, 'Mombasa', 'Mvita');
select public.stage_subcounty(201, 'Kwale', 'Msambweni');
select public.stage_subcounty(202, 'Kwale', 'Lungalunga');
select public.stage_subcounty(203, 'Kwale', 'Matuga');
select public.stage_subcounty(204, 'Kwale', 'Kinango');
select public.stage_subcounty(301, 'Kilifi', 'Kilifi North');
select public.stage_subcounty(302, 'Kilifi', 'Kilifi South');
select public.stage_subcounty(303, 'Kilifi', 'Kaloleni');
select public.stage_subcounty(304, 'Kilifi', 'Rabai');
select public.stage_subcounty(305, 'Kilifi', 'Ganze');
select public.stage_subcounty(306, 'Kilifi', 'Malindi');
select public.stage_subcounty(307, 'Kilifi', 'Magarini');
select public.stage_subcounty(401, 'Tana River', 'Garsen');
select public.stage_subcounty(402, 'Tana River', 'Galole');
select public.stage_subcounty(403, 'Tana River', 'Bura');
select public.stage_subcounty(501, 'Lamu', 'Lamu East');
select public.stage_subcounty(502, 'Lamu', 'Lamu West');
select public.stage_subcounty(601, 'Taita Taveta', 'Taveta');
select public.stage_subcounty(602, 'Taita Taveta', 'Wundanyi');
select public.stage_subcounty(603, 'Taita Taveta', 'Mwatate');
select public.stage_subcounty(604, 'Taita Taveta', 'Voi');
select public.stage_subcounty(701, 'Garissa', 'Garissa Township');
select public.stage_subcounty(702, 'Garissa', 'Balambala');
select public.stage_subcounty(703, 'Garissa', 'Lagdera');
select public.stage_subcounty(704, 'Garissa', 'Dadaab');
select public.stage_subcounty(705, 'Garissa', 'Fafi');
select public.stage_subcounty(706, 'Garissa', 'Ijara');
select public.stage_subcounty(801, 'Wajir', 'Wajir North');
select public.stage_subcounty(802, 'Wajir', 'Wajir East');
select public.stage_subcounty(803, 'Wajir', 'Tarbaj');
select public.stage_subcounty(804, 'Wajir', 'Wajir West');
select public.stage_subcounty(805, 'Wajir', 'Eldas');
select public.stage_subcounty(806, 'Wajir', 'Wajir South');
select public.stage_subcounty(901, 'Mandera', 'Mandera West');
select public.stage_subcounty(902, 'Mandera', 'Banissa');
select public.stage_subcounty(903, 'Mandera', 'Mandera North');
select public.stage_subcounty(904, 'Mandera', 'Mandera South');
select public.stage_subcounty(905, 'Mandera', 'Mandera East');
select public.stage_subcounty(906, 'Mandera', 'Lafey');
select public.stage_subcounty(1001, 'Marsabit', 'Moyale');
select public.stage_subcounty(1002, 'Marsabit', 'North Horr');
select public.stage_subcounty(1003, 'Marsabit', 'Saku');
select public.stage_subcounty(1004, 'Marsabit', 'Laisamis');
select public.stage_subcounty(1101, 'Isiolo', 'Isiolo North');
select public.stage_subcounty(1102, 'Isiolo', 'Isiolo South');
select public.stage_subcounty(1201, 'Meru', 'Igembe South');
select public.stage_subcounty(1202, 'Meru', 'Igembe Central');
select public.stage_subcounty(1203, 'Meru', 'Igembe North');
select public.stage_subcounty(1204, 'Meru', 'Tigania West');
select public.stage_subcounty(1205, 'Meru', 'Tigania East');
select public.stage_subcounty(1206, 'Meru', 'North Imenti');
select public.stage_subcounty(1207, 'Meru', 'Buuri');
select public.stage_subcounty(1208, 'Meru', 'Central Imenti');
select public.stage_subcounty(1209, 'Meru', 'South Imenti');
select public.stage_subcounty(1301, 'Tharaka-Nithi', 'Maara');
select public.stage_subcounty(1302, 'Tharaka-Nithi', 'Chuka/Igambangombe');
select public.stage_subcounty(1303, 'Tharaka-Nithi', 'Tharaka');
select public.stage_subcounty(1401, 'Embu', 'Manyatta');
select public.stage_subcounty(1402, 'Embu', 'Runyenjes');
select public.stage_subcounty(1403, 'Embu', 'Mbeere South');
select public.stage_subcounty(1404, 'Embu', 'Mbeere North');
select public.stage_subcounty(1501, 'Kitui', 'Mwingi North');
select public.stage_subcounty(1502, 'Kitui', 'Mwingi West');
select public.stage_subcounty(1503, 'Kitui', 'Mwingi Central');
select public.stage_subcounty(1504, 'Kitui', 'Kitui West');
select public.stage_subcounty(1505, 'Kitui', 'Kitui Rural');
select public.stage_subcounty(1506, 'Kitui', 'Kitui Central');
select public.stage_subcounty(1507, 'Kitui', 'Kitui East');
select public.stage_subcounty(1508, 'Kitui', 'Kitui South');
select public.stage_subcounty(1601, 'Machakos', 'Masinga');
select public.stage_subcounty(1602, 'Machakos', 'Yatta');
select public.stage_subcounty(1603, 'Machakos', 'Kangundo');
select public.stage_subcounty(1604, 'Machakos', 'Matungulu');
select public.stage_subcounty(1605, 'Machakos', 'Kathiani');
select public.stage_subcounty(1606, 'Machakos', 'Mavoko');
select public.stage_subcounty(1607, 'Machakos', 'Machakos Town');
select public.stage_subcounty(1608, 'Machakos', 'Mwala');
select public.stage_subcounty(1701, 'Makueni', 'Mbooni');
select public.stage_subcounty(1702, 'Makueni', 'Kilome');
select public.stage_subcounty(1703, 'Makueni', 'Kaiti');
select public.stage_subcounty(1704, 'Makueni', 'Makueni');
select public.stage_subcounty(1705, 'Makueni', 'Kibwezi West');
select public.stage_subcounty(1706, 'Makueni', 'Kibwezi East');
select public.stage_subcounty(1801, 'Nyandarua', 'Kinangop');
select public.stage_subcounty(1802, 'Nyandarua', 'Kipipiri');
select public.stage_subcounty(1803, 'Nyandarua', 'Ol Kalou');
select public.stage_subcounty(1804, 'Nyandarua', 'Ol Jorok');
select public.stage_subcounty(1805, 'Nyandarua', 'Ndaragwa');
select public.stage_subcounty(1901, 'Nyeri', 'Tetu');
select public.stage_subcounty(1902, 'Nyeri', 'Kieni');
select public.stage_subcounty(1903, 'Nyeri', 'Mathira');
select public.stage_subcounty(1904, 'Nyeri', 'Othaya');
select public.stage_subcounty(1905, 'Nyeri', 'Mukurweini');
select public.stage_subcounty(1906, 'Nyeri', 'Nyeri Town');
select public.stage_subcounty(2001, 'Kirinyaga', 'Mwea');
select public.stage_subcounty(2002, 'Kirinyaga', 'Gichugu');
select public.stage_subcounty(2003, 'Kirinyaga', 'Ndia');
select public.stage_subcounty(2004, 'Kirinyaga', 'Kirinyaga Central');
select public.stage_subcounty(2101, 'Murang''a', 'Kangema');
select public.stage_subcounty(2102, 'Murang''a', 'Mathioya');
select public.stage_subcounty(2103, 'Murang''a', 'Kiharu');
select public.stage_subcounty(2104, 'Murang''a', 'Kigumo');
select public.stage_subcounty(2105, 'Murang''a', 'Maragwa');
select public.stage_subcounty(2106, 'Murang''a', 'Kandara');
select public.stage_subcounty(2107, 'Murang''a', 'Gatanga');
select public.stage_subcounty(2201, 'Kiambu', 'Gatundu South');
select public.stage_subcounty(2202, 'Kiambu', 'Gatundu North');
select public.stage_subcounty(2203, 'Kiambu', 'Juja');
select public.stage_subcounty(2204, 'Kiambu', 'Thika Town');
select public.stage_subcounty(2205, 'Kiambu', 'Ruiru');
select public.stage_subcounty(2206, 'Kiambu', 'Githunguri');
select public.stage_subcounty(2207, 'Kiambu', 'Kiambu');
select public.stage_subcounty(2208, 'Kiambu', 'Kiambaa');
select public.stage_subcounty(2209, 'Kiambu', 'Kabete');
select public.stage_subcounty(2210, 'Kiambu', 'Kikuyu');
select public.stage_subcounty(2211, 'Kiambu', 'Limuru');
select public.stage_subcounty(2212, 'Kiambu', 'Lari');
select public.stage_subcounty(2301, 'Turkana', 'Turkana North');
select public.stage_subcounty(2302, 'Turkana', 'Turkana West');
select public.stage_subcounty(2303, 'Turkana', 'Turkana Central');
select public.stage_subcounty(2304, 'Turkana', 'Loima');
select public.stage_subcounty(2305, 'Turkana', 'Turkana South');
select public.stage_subcounty(2306, 'Turkana', 'Turkana East');
select public.stage_subcounty(2401, 'West Pokot', 'Kapenguria');
select public.stage_subcounty(2402, 'West Pokot', 'Sigor');
select public.stage_subcounty(2403, 'West Pokot', 'Kacheliba');
select public.stage_subcounty(2404, 'West Pokot', 'Pokot South');
select public.stage_subcounty(2501, 'Samburu', 'Samburu West');
select public.stage_subcounty(2502, 'Samburu', 'Samburu North');
select public.stage_subcounty(2503, 'Samburu', 'Samburu East');
select public.stage_subcounty(2601, 'Trans Nzoia', 'Kwanza');
select public.stage_subcounty(2602, 'Trans Nzoia', 'Endebess');
select public.stage_subcounty(2603, 'Trans Nzoia', 'Saboti');
select public.stage_subcounty(2604, 'Trans Nzoia', 'Kiminini');
select public.stage_subcounty(2605, 'Trans Nzoia', 'Cherangany');
select public.stage_subcounty(2701, 'Uasin Gishu', 'Soy');
select public.stage_subcounty(2702, 'Uasin Gishu', 'Turbo');
select public.stage_subcounty(2703, 'Uasin Gishu', 'Moiben');
select public.stage_subcounty(2704, 'Uasin Gishu', 'Ainabkoi');
select public.stage_subcounty(2705, 'Uasin Gishu', 'Kapseret');
select public.stage_subcounty(2706, 'Uasin Gishu', 'Kesses');
select public.stage_subcounty(2801, 'Elgeyo-Marakwet', 'Marakwet East');
select public.stage_subcounty(2802, 'Elgeyo-Marakwet', 'Marakwet West');
select public.stage_subcounty(2803, 'Elgeyo-Marakwet', 'Keiyo North');
select public.stage_subcounty(2804, 'Elgeyo-Marakwet', 'Keiyo South');
select public.stage_subcounty(2901, 'Nandi', 'Tinderet');
select public.stage_subcounty(2902, 'Nandi', 'Aldai');
select public.stage_subcounty(2903, 'Nandi', 'Nandi Hills');
select public.stage_subcounty(2904, 'Nandi', 'Chesumei');
select public.stage_subcounty(2905, 'Nandi', 'Emgwen');
select public.stage_subcounty(2906, 'Nandi', 'Mosop');
select public.stage_subcounty(3001, 'Baringo', 'Tiaty');
select public.stage_subcounty(3002, 'Baringo', 'Baringo North');
select public.stage_subcounty(3003, 'Baringo', 'Baringo Central');
select public.stage_subcounty(3004, 'Baringo', 'Baringo South');
select public.stage_subcounty(3005, 'Baringo', 'Mogotio');
select public.stage_subcounty(3006, 'Baringo', 'Eldama Ravine');
select public.stage_subcounty(3101, 'Laikipia', 'Laikipia West');
select public.stage_subcounty(3102, 'Laikipia', 'Laikipia East');
select public.stage_subcounty(3103, 'Laikipia', 'Laikipia North');
select public.stage_subcounty(3201, 'Nakuru', 'Molo');
select public.stage_subcounty(3202, 'Nakuru', 'Njoro');
select public.stage_subcounty(3203, 'Nakuru', 'Naivasha');
select public.stage_subcounty(3204, 'Nakuru', 'Gilgil');
select public.stage_subcounty(3205, 'Nakuru', 'Kuresoi South');
select public.stage_subcounty(3206, 'Nakuru', 'Kuresoi North');
select public.stage_subcounty(3207, 'Nakuru', 'Subukia');
select public.stage_subcounty(3208, 'Nakuru', 'Rongai');
select public.stage_subcounty(3209, 'Nakuru', 'Bahati');
select public.stage_subcounty(3210, 'Nakuru', 'Nakuru Town West');
select public.stage_subcounty(3211, 'Nakuru', 'Nakuru Town East');
select public.stage_subcounty(3301, 'Narok', 'Kilgoris');
select public.stage_subcounty(3302, 'Narok', 'Emurua Dikirr');
select public.stage_subcounty(3303, 'Narok', 'Narok North');
select public.stage_subcounty(3304, 'Narok', 'Narok East');
select public.stage_subcounty(3305, 'Narok', 'Narok South');
select public.stage_subcounty(3306, 'Narok', 'Narok West');
select public.stage_subcounty(3401, 'Kajiado', 'Kajiado North');
select public.stage_subcounty(3402, 'Kajiado', 'Kajiado Central');
select public.stage_subcounty(3403, 'Kajiado', 'Kajiado East');
select public.stage_subcounty(3404, 'Kajiado', 'Kajiado West');
select public.stage_subcounty(3405, 'Kajiado', 'Kajiado South');
select public.stage_subcounty(3501, 'Kericho', 'Kipkelion East');
select public.stage_subcounty(3502, 'Kericho', 'Kipkelion West');
select public.stage_subcounty(3503, 'Kericho', 'Ainamoi');
select public.stage_subcounty(3504, 'Kericho', 'Bureti');
select public.stage_subcounty(3505, 'Kericho', 'Belgut');
select public.stage_subcounty(3506, 'Kericho', 'Sigowet/Soin');
select public.stage_subcounty(3601, 'Bomet', 'Sotik');
select public.stage_subcounty(3602, 'Bomet', 'Chepalungu');
select public.stage_subcounty(3603, 'Bomet', 'Bomet East');
select public.stage_subcounty(3604, 'Bomet', 'Bomet Central');
select public.stage_subcounty(3605, 'Bomet', 'Konoin');
select public.stage_subcounty(3701, 'Kakamega', 'Lugari');
select public.stage_subcounty(3702, 'Kakamega', 'Likuyani');
select public.stage_subcounty(3703, 'Kakamega', 'Malava');
select public.stage_subcounty(3704, 'Kakamega', 'Lurambi');
select public.stage_subcounty(3705, 'Kakamega', 'Navakholo');
select public.stage_subcounty(3706, 'Kakamega', 'Mumias West');
select public.stage_subcounty(3707, 'Kakamega', 'Mumias East');
select public.stage_subcounty(3708, 'Kakamega', 'Matungu');
select public.stage_subcounty(3709, 'Kakamega', 'Butere');
select public.stage_subcounty(3710, 'Kakamega', 'Khwisero');
select public.stage_subcounty(3711, 'Kakamega', 'Shinyalu');
select public.stage_subcounty(3712, 'Kakamega', 'Ikolomani');
select public.stage_subcounty(3801, 'Vihiga', 'Vihiga');
select public.stage_subcounty(3802, 'Vihiga', 'Sabatia');
select public.stage_subcounty(3803, 'Vihiga', 'Hamisi');
select public.stage_subcounty(3804, 'Vihiga', 'Luanda');
select public.stage_subcounty(3805, 'Vihiga', 'Emuhaya');
select public.stage_subcounty(3901, 'Bungoma', 'Mt. Elgon');
select public.stage_subcounty(3902, 'Bungoma', 'Sirisia');
select public.stage_subcounty(3903, 'Bungoma', 'Kabuchai');
select public.stage_subcounty(3904, 'Bungoma', 'Bumula');
select public.stage_subcounty(3905, 'Bungoma', 'Kanduyi');
select public.stage_subcounty(3906, 'Bungoma', 'Webuye East');
select public.stage_subcounty(3907, 'Bungoma', 'Webuye West');
select public.stage_subcounty(3908, 'Bungoma', 'Kimilili');
select public.stage_subcounty(3909, 'Bungoma', 'Tongaren');
select public.stage_subcounty(4001, 'Busia', 'Teso North');
select public.stage_subcounty(4002, 'Busia', 'Teso South');
select public.stage_subcounty(4003, 'Busia', 'Nambale');
select public.stage_subcounty(4004, 'Busia', 'Matayos');
select public.stage_subcounty(4005, 'Busia', 'Butula');
select public.stage_subcounty(4006, 'Busia', 'Funyula');
select public.stage_subcounty(4007, 'Busia', 'Budalangi');
select public.stage_subcounty(4101, 'Siaya', 'Ugenya');
select public.stage_subcounty(4102, 'Siaya', 'Ugunja');
select public.stage_subcounty(4103, 'Siaya', 'Alego Usonga');
select public.stage_subcounty(4104, 'Siaya', 'Gem');
select public.stage_subcounty(4105, 'Siaya', 'Bondo');
select public.stage_subcounty(4106, 'Siaya', 'Rarieda');
select public.stage_subcounty(4201, 'Kisumu', 'Kisumu East');
select public.stage_subcounty(4202, 'Kisumu', 'Kisumu West');
select public.stage_subcounty(4203, 'Kisumu', 'Kisumu Central');
select public.stage_subcounty(4204, 'Kisumu', 'Seme');
select public.stage_subcounty(4205, 'Kisumu', 'Nyando');
select public.stage_subcounty(4206, 'Kisumu', 'Muhoroni');
select public.stage_subcounty(4207, 'Kisumu', 'Nyakach');
select public.stage_subcounty(4301, 'Homa Bay', 'Kasipul');
select public.stage_subcounty(4302, 'Homa Bay', 'Kabondo Kasipul');
select public.stage_subcounty(4303, 'Homa Bay', 'Karachuonyo');
select public.stage_subcounty(4304, 'Homa Bay', 'Rangwe');
select public.stage_subcounty(4305, 'Homa Bay', 'Homa Bay Town');
select public.stage_subcounty(4306, 'Homa Bay', 'Ndhiwa');
select public.stage_subcounty(4307, 'Homa Bay', 'Suba North');
select public.stage_subcounty(4308, 'Homa Bay', 'Suba South');
select public.stage_subcounty(4401, 'Migori', 'Rongo');
select public.stage_subcounty(4402, 'Migori', 'Awendo');
select public.stage_subcounty(4403, 'Migori', 'Suna East');
select public.stage_subcounty(4404, 'Migori', 'Suna West');
select public.stage_subcounty(4405, 'Migori', 'Uriri');
select public.stage_subcounty(4406, 'Migori', 'Nyatike');
select public.stage_subcounty(4407, 'Migori', 'Kuria West');
select public.stage_subcounty(4408, 'Migori', 'Kuria East');
select public.stage_subcounty(4501, 'Kisii', 'Bonchari');
select public.stage_subcounty(4502, 'Kisii', 'South Mugirango');
select public.stage_subcounty(4503, 'Kisii', 'Bomachoge Borabu');
select public.stage_subcounty(4504, 'Kisii', 'Bobasi');
select public.stage_subcounty(4505, 'Kisii', 'Bomachoge Chache');
select public.stage_subcounty(4506, 'Kisii', 'Nyaribari Masaba');
select public.stage_subcounty(4507, 'Kisii', 'Nyaribari Chache');
select public.stage_subcounty(4508, 'Kisii', 'Kitutu Chache North');
select public.stage_subcounty(4509, 'Kisii', 'Kitutu Chache South');
select public.stage_subcounty(4601, 'Nyamira', 'Kitutu Masaba');
select public.stage_subcounty(4602, 'Nyamira', 'West Mugirango');
select public.stage_subcounty(4603, 'Nyamira', 'North Mugirango');
select public.stage_subcounty(4604, 'Nyamira', 'Borabu');
select public.stage_subcounty(4701, 'Nairobi', 'Westlands');
select public.stage_subcounty(4702, 'Nairobi', 'Dagoretti North');
select public.stage_subcounty(4703, 'Nairobi', 'Dagoretti South');
select public.stage_subcounty(4704, 'Nairobi', 'Langata');
select public.stage_subcounty(4705, 'Nairobi', 'Kibra');
select public.stage_subcounty(4706, 'Nairobi', 'Roysambu');
select public.stage_subcounty(4707, 'Nairobi', 'Kasarani');
select public.stage_subcounty(4708, 'Nairobi', 'Ruaraka');
select public.stage_subcounty(4709, 'Nairobi', 'Embakasi South');
select public.stage_subcounty(4710, 'Nairobi', 'Embakasi North');
select public.stage_subcounty(4711, 'Nairobi', 'Embakasi Central');
select public.stage_subcounty(4712, 'Nairobi', 'Embakasi East');
select public.stage_subcounty(4713, 'Nairobi', 'Embakasi West');
select public.stage_subcounty(4714, 'Nairobi', 'Makadara');
select public.stage_subcounty(4715, 'Nairobi', 'Kamkunji');
select public.stage_subcounty(4716, 'Nairobi', 'Starehe');
select public.stage_subcounty(4717, 'Nairobi', 'Mathare');

delete from public.leaders where role in ('Governor', 'MP');

create or replace function public.stage_governance_leader(
  p_name text,
  p_role text,
  p_party_name text,
  p_county_name text,
  p_subcounty_name text default null
) returns void
language plpgsql
as $$
declare
  resolved_county_id int;
  resolved_subcounty_id int;
begin
  select id into resolved_county_id from public.counties where name = p_county_name limit 1;
  if resolved_county_id is null then
    raise exception 'County % is missing for leader %', p_county_name, p_name;
  end if;

  if p_role = 'MP' then
    select id into resolved_subcounty_id
    from public.subcounties
    where county_id = resolved_county_id and name = p_subcounty_name
    limit 1;
  end if;

  insert into public.leaders (name, role, party_name, county_id, subcounty_id)
  values (p_name, p_role, p_party_name, resolved_county_id, resolved_subcounty_id);
end;
$$;

select public.stage_governance_leader('Abdulswamad Nassir', 'Governor', 'N/A', 'Mombasa');
select public.stage_governance_leader('Fatuma Achani', 'Governor', 'N/A', 'Kwale');
select public.stage_governance_leader('Gideon Mung''aro', 'Governor', 'N/A', 'Kilifi');
select public.stage_governance_leader('Dhadho Godhana', 'Governor', 'N/A', 'Tana River');
select public.stage_governance_leader('Issa Abdallah Timamy', 'Governor', 'N/A', 'Lamu');
select public.stage_governance_leader('Andrew Mwadime', 'Governor', 'N/A', 'Taita Taveta');
select public.stage_governance_leader('Nathif Jama', 'Governor', 'N/A', 'Garissa');
select public.stage_governance_leader('Ahmed Abdullahi', 'Governor', 'N/A', 'Wajir');
select public.stage_governance_leader('Mohamed Adan Khalif', 'Governor', 'N/A', 'Mandera');
select public.stage_governance_leader('Mohamud Ali', 'Governor', 'N/A', 'Marsabit');
select public.stage_governance_leader('Abdi Hassan Guyo', 'Governor', 'N/A', 'Isiolo');
select public.stage_governance_leader('Kawira Mwangaza', 'Governor', 'N/A', 'Meru');
select public.stage_governance_leader('Muthomi Njuki', 'Governor', 'N/A', 'Tharaka-Nithi');
select public.stage_governance_leader('Cecily Mbarire', 'Governor', 'N/A', 'Embu');
select public.stage_governance_leader('Julius Malombe', 'Governor', 'N/A', 'Kitui');
select public.stage_governance_leader('Wavinya Ndeti', 'Governor', 'N/A', 'Machakos');
select public.stage_governance_leader('Mutula Kilonzo', 'Governor', 'N/A', 'Makueni');
select public.stage_governance_leader('Moses Kiarie Badilisha', 'Governor', 'N/A', 'Nyandarua');
select public.stage_governance_leader('Mutahi Kahiga', 'Governor', 'N/A', 'Nyeri');
select public.stage_governance_leader('Anne Waiguru', 'Governor', 'N/A', 'Kirinyaga');
select public.stage_governance_leader('Irungu Kang''ata', 'Governor', 'N/A', 'Murang''a');
select public.stage_governance_leader('Kimani Wamatangi', 'Governor', 'N/A', 'Kiambu');
select public.stage_governance_leader('Jeremiah Lomurkai', 'Governor', 'N/A', 'Turkana');
select public.stage_governance_leader('Simon Kachapin', 'Governor', 'N/A', 'West Pokot');
select public.stage_governance_leader('Jonathan Lati Lelelit', 'Governor', 'N/A', 'Samburu');
select public.stage_governance_leader('George Natembeya', 'Governor', 'N/A', 'Trans Nzoia');
select public.stage_governance_leader('Jonathan Bii', 'Governor', 'N/A', 'Uasin Gishu');
select public.stage_governance_leader('Wisley Rotich', 'Governor', 'N/A', 'Elgeyo-Marakwet');
select public.stage_governance_leader('Stephen Sang', 'Governor', 'N/A', 'Nandi');
select public.stage_governance_leader('Benjamin Cheboi', 'Governor', 'N/A', 'Baringo');
select public.stage_governance_leader('Joshua Irungu', 'Governor', 'N/A', 'Laikipia');
select public.stage_governance_leader('Susan Kihika', 'Governor', 'N/A', 'Nakuru');
select public.stage_governance_leader('Patrick Ole Ntutu', 'Governor', 'N/A', 'Narok');
select public.stage_governance_leader('Joseph Ole Lenku', 'Governor', 'N/A', 'Kajiado');
select public.stage_governance_leader('Erick Mutai', 'Governor', 'N/A', 'Kericho');
select public.stage_governance_leader('Hillary Barchok', 'Governor', 'N/A', 'Bomet');
select public.stage_governance_leader('Fernandes Barasa', 'Governor', 'N/A', 'Kakamega');
select public.stage_governance_leader('Wilberforce Ottichilo', 'Governor', 'N/A', 'Vihiga');
select public.stage_governance_leader('Kenneth Lusaka', 'Governor', 'N/A', 'Bungoma');
select public.stage_governance_leader('Paul Otuoma', 'Governor', 'N/A', 'Busia');
select public.stage_governance_leader('James Orengo', 'Governor', 'N/A', 'Siaya');
select public.stage_governance_leader('Anyang'' Nyong''o', 'Governor', 'N/A', 'Kisumu');
select public.stage_governance_leader('Gladys Wanga', 'Governor', 'N/A', 'Homa Bay');
select public.stage_governance_leader('Ochilo Ayacko', 'Governor', 'N/A', 'Migori');
select public.stage_governance_leader('Simba Arati', 'Governor', 'N/A', 'Kisii');
select public.stage_governance_leader('Amos Nyaribo', 'Governor', 'N/A', 'Nyamira');
select public.stage_governance_leader('Johnson Sakaja', 'Governor', 'N/A', 'Nairobi');
select public.stage_governance_leader('Shimbwa, Omar Mwinyi', 'MP', 'ODM', 'Mombasa', 'Changamwe');
select public.stage_governance_leader('Bady, Bady Twalib', 'MP', 'ODM', 'Mombasa', 'Jomvu');
select public.stage_governance_leader('Bedzumba, Rashid juma', 'MP', 'ODM', 'Mombasa', 'Kisauni');
select public.stage_governance_leader('Mohamed, Mohamed Ali', 'MP', 'UDA', 'Mombasa', 'Nyali');
select public.stage_governance_leader('Mboko, Mishi Juma Khamisi', 'MP', 'ODM', 'Mombasa', 'Likoni');
select public.stage_governance_leader('Machele, Mohamed Soud', 'MP', 'ODM', 'Mombasa', 'Mvita');
select public.stage_governance_leader('Bader, Salim Feisal', 'MP', 'UDA', 'Kwale', 'Msambweni');
select public.stage_governance_leader('Chiforomodo, Mangale Munga', 'MP', 'UDM', 'Kwale', 'Lungalunga');
select public.stage_governance_leader('Tandaza, Kassim Sawa', 'MP', 'ANC', 'Kwale', 'Matuga');
select public.stage_governance_leader('Rai, Samuel Gonzi', 'MP', 'PAA', 'Kwale', 'Kinango');
select public.stage_governance_leader('Baya, Owen Yan', 'MP', 'UDA', 'Kilifi', 'Kilifi North');
select public.stage_governance_leader('Kiti, Richard Ken Chonga', 'MP', 'ODM', 'Kilifi', 'Kilifi South');
select public.stage_governance_leader('Katana, Paul Kahindi', 'MP', 'ODM', 'Kilifi', 'Kaloleni');
select public.stage_governance_leader('Mupe, Anthony Kenga', 'MP', 'PAA', 'Kilifi', 'Rabai');
select public.stage_governance_leader('Tungule, Charo Kenneth Kazungu', 'MP', 'PAA', 'Kilifi', 'Ganze');
select public.stage_governance_leader('Mnyazi, Amina Laura', 'MP', 'ODM', 'Kilifi', 'Malindi');
select public.stage_governance_leader('Kombe, Harrison Garama', 'MP', 'ODM', 'Kilifi', 'Magarini');
select public.stage_governance_leader('Guyo, Ali Wario', 'MP', 'ODM', 'Tana River', 'Garsen');
select public.stage_governance_leader('Hiribae, Said Buya', 'MP', 'ODM', 'Tana River', 'Galole');
select public.stage_governance_leader('Yakub, Adow Kuno', 'MP', 'UPIA', 'Tana River', 'Bura');
select public.stage_governance_leader('Obo, Ruweida Mohamed', 'MP', 'JP', 'Lamu', 'Lamu East');
select public.stage_governance_leader('Muiruri, Muthama Stanley', 'MP', 'JP', 'Lamu', 'Lamu West');
select public.stage_governance_leader('Bwire, John Okano', 'MP', 'WDM', 'Taita Taveta', 'Taveta');
select public.stage_governance_leader('Mwakuwona, Danson Mwashako', 'MP', 'WDM', 'Taita Taveta', 'Wundanyi');
select public.stage_governance_leader('Shake, Peter Mbogho', 'MP', 'JP', 'Taita Taveta', 'Mwatate');
select public.stage_governance_leader('Abdi, Khamis Chome', 'MP', 'WDM', 'Taita Taveta', 'Voi');
select public.stage_governance_leader('Barrow, Dekow Mohamed', 'MP', 'UDA', 'Garissa', 'Garissa Township');
select public.stage_governance_leader('Shurie, Abdi Omar', 'MP', 'JP', 'Garissa', 'Balambala');
select public.stage_governance_leader('Mohamed, Abdikadir Hussein', 'MP', 'ODM', 'Garissa', 'Lagdera');
select public.stage_governance_leader('Maalim, Farah', 'MP', 'WDM', 'Garissa', 'Dadaab');
select public.stage_governance_leader('Yakub, Farah Salah', 'MP', 'UDA', 'Garissa', 'Fafi');
select public.stage_governance_leader('Abdi, Abdi Ali', 'MP', 'NAP-K', 'Garissa', 'Ijara');
select public.stage_governance_leader('Saney, Ibrahim Abdi', 'MP', 'UDA', 'Wajir', 'Wajir North');
select public.stage_governance_leader('Mohamed, Aden Daudi', 'MP', 'JP', 'Wajir', 'Wajir East');
select public.stage_governance_leader('Barre, Hussein Abdi', 'MP', 'UDA', 'Wajir', 'Tarbaj');
select public.stage_governance_leader('Farah, Yussuf Mohamed', 'MP', 'ODM', 'Wajir', 'Wajir West');
select public.stage_governance_leader('Wehliye, Adan Keynan', 'MP', 'JP', 'Wajir', 'Eldas');
select public.stage_governance_leader('Adow, Mohamed Aden', 'MP', 'ODM', 'Wajir', 'Wajir South');
select public.stage_governance_leader('Yussuf, Adan Haji', 'MP', 'UDM', 'Mandera', 'Mandera West');
select public.stage_governance_leader('Vacant', 'MP', 'UDM', 'Mandera', 'Banissa');
select public.stage_governance_leader('Abdullahi, Bashir Sheikh', 'MP', 'UDM', 'Mandera', 'Mandera North');
select public.stage_governance_leader('Haro, Abdul Ebrahim', 'MP', 'UDM', 'Mandera', 'Mandera South');
select public.stage_governance_leader('Abdirahman, Husseinweytan Mohamed', 'MP', 'ODM', 'Mandera', 'Mandera East');
select public.stage_governance_leader('Abdirahman, Mohamed Abdi', 'MP', 'JP', 'Mandera', 'Lafey');
select public.stage_governance_leader('Jaldesa, Guyo Waqo', 'MP', 'UPIA', 'Marsabit', 'Moyale');
select public.stage_governance_leader('Guyo, Adhe Wario', 'MP', 'KANU', 'Marsabit', 'North Horr');
select public.stage_governance_leader('Raso, Dido Ali', 'MP', 'UDA', 'Marsabit', 'Saku');
select public.stage_governance_leader('Lekuton, Joseph', 'MP', 'UDM', 'Marsabit', 'Laisamis');
select public.stage_governance_leader('Lomwa, Joseph Samal', 'MP', 'JP', 'Isiolo', 'Isiolo North');
select public.stage_governance_leader('Tubi, Bidu Mohamed', 'MP', 'JP', 'Isiolo', 'Isiolo South');
select public.stage_governance_leader('Mwiringi, John Paul', 'MP', 'UDA', 'Meru', 'Igembe South');
select public.stage_governance_leader('Karitho, Kiili Daniel', 'MP', 'JP', 'Meru', 'Igembe Central');
select public.stage_governance_leader('M''Anaiba, Julius Taitumu', 'MP', 'UDA', 'Meru', 'Igembe North');
select public.stage_governance_leader('Mutunga, John Kanyuithia', 'MP', 'UDA', 'Meru', 'Tigania West');
select public.stage_governance_leader('Aburi, Lawrence Mpuru', 'MP', 'NOPEU', 'Meru', 'Tigania East');
select public.stage_governance_leader('Abdul, Rahim Dawood', 'MP', 'Independent', 'Meru', 'North Imenti');
select public.stage_governance_leader('Murwithania, Rindikiri Mugambi', 'MP', 'UDA', 'Meru', 'Buuri');
select public.stage_governance_leader('Kirima, Moses Nguchine', 'MP', 'UDA', 'Meru', 'Central Imenti');
select public.stage_governance_leader('Ithinji, Dr. Shadrack Mwiti', 'MP', 'JP', 'Meru', 'South Imenti');
select public.stage_governance_leader('Mbiuki, Japhet Miriti Kareke', 'MP', 'UDA', 'Tharaka-Nithi', 'Maara');
select public.stage_governance_leader('Ntwiga, Patrick Munene', 'MP', 'UDA', 'Tharaka-Nithi', 'Chuka/Igambangombe');
select public.stage_governance_leader('Murugara, George Gitonga', 'MP', 'UDA', 'Tharaka-Nithi', 'Tharaka');
select public.stage_governance_leader('Mukunji, John Gitonga Mwaniki', 'MP', 'UDA', 'Embu', 'Manyatta');
select public.stage_governance_leader('Karemba, Eric Muchangi Njiru', 'MP', 'UDA', 'Embu', 'Runyenjes');
select public.stage_governance_leader('Nebart, Bernard Muriuki', 'MP', 'Independent', 'Embu', 'Mbeere South');
select public.stage_governance_leader('Ruku, Geoffrey Kariuki Kiringa', 'MP', 'DP', 'Embu', 'Mbeere North');
select public.stage_governance_leader('Nzengu, Paul Musyimi', 'MP', 'WDM', 'Kitui', 'Mwingi North');
select public.stage_governance_leader('Nguna, Charles Ngusya', 'MP', 'WDM', 'Kitui', 'Mwingi West');
select public.stage_governance_leader('Mulyungi, Gideon Mutemi', 'MP', 'WDM', 'Kitui', 'Mwingi Central');
select public.stage_governance_leader('Nyenze, Edith Vethi', 'MP', 'WDM', 'Kitui', 'Kitui West');
select public.stage_governance_leader('Mboni, David Mwalika', 'MP', 'WDM', 'Kitui', 'Kitui Rural');
select public.stage_governance_leader('Mulu, Makali Benson', 'MP', 'WDM', 'Kitui', 'Kitui Central');
select public.stage_governance_leader('Mbai, Nimrod Mbithuka', 'MP', 'UDA', 'Kitui', 'Kitui East');
select public.stage_governance_leader('Nyamai, Rachael Kaki', 'MP', 'JP', 'Kitui', 'Kitui South');
select public.stage_governance_leader('Mwalyo, Joshua Mbithi Mutua', 'MP', 'Independent', 'Machakos', 'Masinga');
select public.stage_governance_leader('Basil, Robert Ngui', 'MP', 'WDM', 'Machakos', 'Yatta');
select public.stage_governance_leader('Muli, Fabian Kyule', 'MP', 'GDDP', 'Machakos', 'Kangundo');
select public.stage_governance_leader('Mule, Stephen Mutinda', 'MP', 'WDM', 'Machakos', 'Matungulu');
select public.stage_governance_leader('Mbui, Robert', 'MP', 'WDM', 'Machakos', 'Kathiani');
select public.stage_governance_leader('Kingola, Patrick Makau', 'MP', 'WDM', 'Machakos', 'Mavoko');
select public.stage_governance_leader('Mule, Caleb Mutiso', 'MP', 'MCCP', 'Machakos', 'Machakos Town');
select public.stage_governance_leader('Musau, Vincent Musyoka', 'MP', 'UDA', 'Machakos', 'Mwala');
select public.stage_governance_leader('Nzioka, Erastus Kivasu', 'MP', 'WDM', 'Makueni', 'Mbooni');
select public.stage_governance_leader('Nzambia, Thudeeus Kithua', 'MP', 'WDM', 'Makueni', 'Kilome');
select public.stage_governance_leader('Kimilu, Joshua Kivinda', 'MP', 'WDM', 'Makueni', 'Kaiti');
select public.stage_governance_leader('Kiamba, Suzanne Ndunge', 'MP', 'WDM', 'Makueni', 'Makueni');
select public.stage_governance_leader('Mutuse, Eckomas Mwengi', 'MP', 'MCCP', 'Makueni', 'Kibwezi West');
select public.stage_governance_leader('Mbalu, Jessica Nduku Kiko', 'MP', 'WDM', 'Makueni', 'Kibwezi East');
select public.stage_governance_leader('Kwenya, Thuku Zachary', 'MP', 'JP', 'Nyandarua', 'Kinangop');
select public.stage_governance_leader('Muhia, Wanjiku', 'MP', 'UDA', 'Nyandarua', 'Kipipiri');
select public.stage_governance_leader('Kiaraho, David Njuguna', 'MP', 'JP', 'Nyandarua', 'Ol Kalou');
select public.stage_governance_leader('Muchira, Michael Mwangi', 'MP', 'UDA', 'Nyandarua', 'Ol Jorok');
select public.stage_governance_leader('Gachagua, George N.', 'MP', 'UDA', 'Nyandarua', 'Ndaragwa');
select public.stage_governance_leader('Mwangi, Geoffrey Wandeto', 'MP', 'UDA', 'Nyeri', 'Tetu');
select public.stage_governance_leader('Wainaina, Antony Njoroge', 'MP', 'UDA', 'Nyeri', 'Kieni');
select public.stage_governance_leader('Kahugu, Eric Meangi', 'MP', 'UDA', 'Nyeri', 'Mathira');
select public.stage_governance_leader('Wainaina, Michael Wambugu', 'MP', 'UDA', 'Nyeri', 'Othaya');
select public.stage_governance_leader('Gichohi, Kaguchia John Philip', 'MP', 'UDA', 'Nyeri', 'Mukurweini');
select public.stage_governance_leader('Mathenge, Duncan Maina', 'MP', 'UDA', 'Nyeri', 'Nyeri Town');
select public.stage_governance_leader('Maingi, Mary', 'MP', 'UDA', 'Kirinyaga', 'Mwea');
select public.stage_governance_leader('Githinji, Robert Gichimu', 'MP', 'UDA', 'Kirinyaga', 'Gichugu');
select public.stage_governance_leader('GK, George Macharia Kariuki', 'MP', 'UDA', 'Kirinyaga', 'Ndia');
select public.stage_governance_leader('Gitari, Joseph Gachoki', 'MP', 'UDA', 'Kirinyaga', 'Kirinyaga Central');
select public.stage_governance_leader('Kihungi, Peter Irungu', 'MP', 'UDA', 'Murang''a', 'Kangema');
select public.stage_governance_leader('Gichuki, Edwin Mugo', 'MP', 'UDA', 'Murang''a', 'Mathioya');
select public.stage_governance_leader('Nyoro, Samson Ndindi', 'MP', 'UDA', 'Murang''a', 'Kiharu');
select public.stage_governance_leader('Munyoro, Joseph Kamau', 'MP', 'UDA', 'Murang''a', 'Kigumo');
select public.stage_governance_leader('Njoroge, Mary Wamaua Waithira', 'MP', 'UDA', 'Murang''a', 'Maragwa');
select public.stage_governance_leader('Njuguna, Chege', 'MP', 'UDA', 'Murang''a', 'Kandara');
select public.stage_governance_leader('Muriu, Wakili Edward', 'MP', 'UDA', 'Murang''a', 'Gatanga');
select public.stage_governance_leader('Kagombe, Gabriel Gathuka', 'MP', 'UDA', 'Kiambu', 'Gatundu South');
select public.stage_governance_leader('Kururia, Elijah Njore Njoroge', 'MP', 'Independent', 'Kiambu', 'Gatundu North');
select public.stage_governance_leader('Ndungu, George Koimburi', 'MP', 'UDA', 'Kiambu', 'Juja');
select public.stage_governance_leader('Nganga, Alice Wambui', 'MP', 'UDA', 'Kiambu', 'Thika Town');
select public.stage_governance_leader('Kingara, Simon Nganga', 'MP', 'UDA', 'Kiambu', 'Ruiru');
select public.stage_governance_leader('Wamuchomba, Gathoni', 'MP', 'UDA', 'Kiambu', 'Githunguri');
select public.stage_governance_leader('Waithaka, John Machua', 'MP', 'UDA', 'Kiambu', 'Kiambu');
select public.stage_governance_leader('John Njuguna', 'MP', 'UDA', 'Kiambu', 'Kiambaa');
select public.stage_governance_leader('Wamacukuru, James Githua Kamau', 'MP', 'UDA', 'Kiambu', 'Kabete');
select public.stage_governance_leader('Ichung''wah, Anthony Kimani', 'MP', 'UDA', 'Kiambu', 'Kikuyu');
select public.stage_governance_leader('Chege, John Kiragu', 'MP', 'UDA', 'Kiambu', 'Limuru');
select public.stage_governance_leader('Kahangara, Joseph Mburu', 'MP', 'UDA', 'Kiambu', 'Lari');
select public.stage_governance_leader('Naibun, Paul Ekwom', 'MP', 'ODM', 'Turkana', 'Turkana North');
select public.stage_governance_leader('Nanok, Daniel Epuyo', 'MP', 'UDA', 'Turkana', 'Turkana West');
select public.stage_governance_leader('Emathe, Joseph Namuar', 'MP', 'UDA', 'Turkana', 'Turkana Central');
select public.stage_governance_leader('Akuja, Protus Ewesit', 'MP', 'UDA', 'Turkana', 'Loima');
select public.stage_governance_leader('Namoit, John Ariko', 'MP', 'ODM', 'Turkana', 'Turkana South');
select public.stage_governance_leader('Ngikolong, Nicholas Ng''ikor Nixon', 'MP', 'JP', 'Turkana', 'Turkana East');
select public.stage_governance_leader('Chumel, Samwel Moroto', 'MP', 'UDA', 'West Pokot', 'Kapenguria');
select public.stage_governance_leader('Lochakapong, Peter', 'MP', 'UDA', 'West Pokot', 'Sigor');
select public.stage_governance_leader('Titus, Lotee', 'MP', 'KUP', 'West Pokot', 'Kacheliba');
select public.stage_governance_leader('Pkosing, David Losiakou', 'MP', 'KUP', 'West Pokot', 'Pokot South');
select public.stage_governance_leader('Lesuuda, Josephine Naisula', 'MP', 'KANU', 'Samburu', 'Samburu West');
select public.stage_governance_leader('Letipila, Dominic Eli', 'MP', 'UDA', 'Samburu', 'Samburu North');
select public.stage_governance_leader('Lentoijoni, Jackson Lekumontare', 'MP', 'KANU', 'Samburu', 'Samburu East');
select public.stage_governance_leader('Wanyonyi, Ferdinand Kevin', 'MP', 'FORD-K', 'Trans Nzoia', 'Kwanza');
select public.stage_governance_leader('Pukose, Robert (Dr.)', 'MP', 'UDA', 'Trans Nzoia', 'Endebess');
select public.stage_governance_leader('Luyai, Caleb Amisi', 'MP', 'ODM', 'Trans Nzoia', 'Saboti');
select public.stage_governance_leader('Bisau, Maurice Kakai', 'MP', 'DAP-K', 'Trans Nzoia', 'Kiminini');
select public.stage_governance_leader('Barasa, Patrick Simiyu', 'MP', 'DAP-K', 'Trans Nzoia', 'Cherangany');
select public.stage_governance_leader('Kiplagat, David', 'MP', 'UDA', 'Uasin Gishu', 'Soy');
select public.stage_governance_leader('Sitienei, Janet Jepkemboi', 'MP', 'UDA', 'Uasin Gishu', 'Turbo');
select public.stage_governance_leader('Bartoo, Phylis Jepkemoi', 'MP', 'UDA', 'Uasin Gishu', 'Moiben');
select public.stage_governance_leader('Chepkonga, Kiprono Samwel', 'MP', 'UDA', 'Uasin Gishu', 'Ainabkoi');
select public.stage_governance_leader('Sudi, Oscar Kipchumba', 'MP', 'UDA', 'Uasin Gishu', 'Kapseret');
select public.stage_governance_leader('Rutto, Julius Kipletting', 'MP', 'UDA', 'Uasin Gishu', 'Kesses');
select public.stage_governance_leader('Bowen, David Kangogo', 'MP', 'UDA', 'Elgeyo-Marakwet', 'Marakwet East');
select public.stage_governance_leader('Toroitich, Timothy Kipchumba', 'MP', 'Independent', 'Elgeyo-Marakwet', 'Marakwet West');
select public.stage_governance_leader('Korir, Adams Kipsanai', 'MP', 'UDA', 'Elgeyo-Marakwet', 'Keiyo North');
select public.stage_governance_leader('Kipkoech, Gideon Kimaiyo', 'MP', 'UDA', 'Elgeyo-Marakwet', 'Keiyo South');
select public.stage_governance_leader('Kipbiwot, Julius Melly', 'MP', 'UDA', 'Nandi', 'Tinderet');
select public.stage_governance_leader('Kitany, Marianne Jebet', 'MP', 'UDA', 'Nandi', 'Aldai');
select public.stage_governance_leader('Kitur, Bernard Kibor', 'MP', 'UDA', 'Nandi', 'Nandi Hills');
select public.stage_governance_leader('Biego, Paul Kibichy', 'MP', 'UDA', 'Nandi', 'Chesumei');
select public.stage_governance_leader('Lelmengit, Josses Kiptoo Kosgey', 'MP', 'UDA', 'Nandi', 'Emgwen');
select public.stage_governance_leader('Kirwa, Abraham Kipsang', 'MP', 'UDA', 'Nandi', 'Mosop');
select public.stage_governance_leader('Kassait, William Kamket', 'MP', 'KANU', 'Baringo', 'Tiaty');
select public.stage_governance_leader('Kipkoros, Joseph Makilap', 'MP', 'UDA', 'Baringo', 'Baringo North');
select public.stage_governance_leader('Kandie, Joshua Chepyegon', 'MP', 'UDA', 'Baringo', 'Baringo Central');
select public.stage_governance_leader('Kamuren, Charles', 'MP', 'UDA', 'Baringo', 'Baringo South');
select public.stage_governance_leader('Kipgnor, Reuben Kiborek', 'MP', 'UDA', 'Baringo', 'Mogotio');
select public.stage_governance_leader('Sirma, Musa Cherutich', 'MP', 'UDA', 'Baringo', 'Eldama Ravine');
select public.stage_governance_leader('Karani, Stephen Wachira', 'MP', 'UDA', 'Laikipia', 'Laikipia West');
select public.stage_governance_leader('Kiunjuri, Festus Mwangi', 'MP', 'TSP', 'Laikipia', 'Laikipia East');
select public.stage_governance_leader('Korere, Sarah Paulata', 'MP', 'JP', 'Laikipia', 'Laikipia North');
select public.stage_governance_leader('Kimani, Francis Kuria', 'MP', 'UDA', 'Nakuru', 'Molo');
select public.stage_governance_leader('Chepkwony, Charity Kathambi', 'MP', 'UDA', 'Nakuru', 'Njoro');
select public.stage_governance_leader('Kihara, Jayne Wanjiru Njeru', 'MP', 'UDA', 'Nakuru', 'Naivasha');
select public.stage_governance_leader('Wanjira, Martha Wangari', 'MP', 'UDA', 'Nakuru', 'Gilgil');
select public.stage_governance_leader('Tonui, Joseph Kipkosgei', 'MP', 'UDA', 'Nakuru', 'Kuresoi South');
select public.stage_governance_leader('Kiprono, Mutai Alfred', 'MP', 'UDA', 'Nakuru', 'Kuresoi North');
select public.stage_governance_leader('Gachobe, Samuel Kinuthia', 'MP', 'UDA', 'Nakuru', 'Subukia');
select public.stage_governance_leader('Chebor, Paul Kibet', 'MP', 'UDA', 'Nakuru', 'Rongai');
select public.stage_governance_leader('Mrembo, Irene Njoki', 'MP', 'JP', 'Nakuru', 'Bahati');
select public.stage_governance_leader('Arama, Samuel', 'MP', 'JP', 'Nakuru', 'Nakuru Town West');
select public.stage_governance_leader('Gikaria, David', 'MP', 'UDA', 'Nakuru', 'Nakuru Town East');
select public.stage_governance_leader('Sunkuli, Julius Lekakeny Ole', 'MP', 'KANU', 'Narok', 'Kilgoris');
select public.stage_governance_leader('Kipyegon, Johana Ng''eno', 'MP', 'UDA', 'Narok', 'Emurua Dikirr');
select public.stage_governance_leader('Pareiyo, Agnes Mantaine', 'MP', 'JP', 'Narok', 'Narok North');
select public.stage_governance_leader('Lemanken, Aramat', 'MP', 'UDA', 'Narok', 'Narok East');
select public.stage_governance_leader('Kitilai, Ole Ntutu', 'MP', 'Independent', 'Narok', 'Narok South');
select public.stage_governance_leader('Tongoyo, Gabriel Koshal', 'MP', 'UDA', 'Narok', 'Narok West');
select public.stage_governance_leader('Nguro, Onesmus Ngogoyo', 'MP', 'UDA', 'Kajiado', 'Kajiado North');
select public.stage_governance_leader('Kanchory, Elijah Memusi', 'MP', 'ODM', 'Kajiado', 'Kajiado Central');
select public.stage_governance_leader('Hamisi, Kakuta Maimai', 'MP', 'ODM', 'Kajiado', 'Kajiado East');
select public.stage_governance_leader('Risa, Sunkuiya George', 'MP', 'UDA', 'Kajiado', 'Kajiado West');
select public.stage_governance_leader('Sakimba, Parashina Samuel', 'MP', 'ODM', 'Kajiado', 'Kajiado South');
select public.stage_governance_leader('Cherorot, Joseph Kimutai', 'MP', 'UDA', 'Kericho', 'Kipkelion East');
select public.stage_governance_leader('Kosgei, Hilary Kiplangat', 'MP', 'UDA', 'Kericho', 'Kipkelion West');
select public.stage_governance_leader('Langat, Benjamin Kipkirui', 'MP', 'UDA', 'Kericho', 'Ainamoi');
select public.stage_governance_leader('Komingoi, Kibet Kirui', 'MP', 'UDA', 'Kericho', 'Bureti');
select public.stage_governance_leader('Koech, Nelson', 'MP', 'UDA', 'Kericho', 'Belgut');
select public.stage_governance_leader('Kemei, Justice Kipsang', 'MP', 'UDA', 'Kericho', 'Sigowet/Soin');
select public.stage_governance_leader('Sigei, Francis Kipyegon arap', 'MP', 'UDA', 'Bomet', 'Sotik');
select public.stage_governance_leader('Koech, Victor Kipngetich', 'MP', 'CCM', 'Bomet', 'Chepalungu');
select public.stage_governance_leader('Yegon, Richard Kipkemoi', 'MP', 'UDA', 'Bomet', 'Bomet East');
select public.stage_governance_leader('Kilel, Richard Cheruiyot', 'MP', 'UDA', 'Bomet', 'Bomet Central');
select public.stage_governance_leader('Yegon, Brighton Leonard', 'MP', 'UDA', 'Bomet', 'Konoin');
select public.stage_governance_leader('Nabii, Nabwera Daraja', 'MP', 'ODM', 'Kakamega', 'Lugari');
select public.stage_governance_leader('Mugabe, Innocent Maino', 'MP', 'ODM', 'Kakamega', 'Likuyani');
select public.stage_governance_leader('Injendi, Moses Malulu', 'MP', 'ANC', 'Kakamega', 'Malava');
select public.stage_governance_leader('Mukhwana, Titus Khamala', 'MP', 'ODM', 'Kakamega', 'Lurambi');
select public.stage_governance_leader('Wangwe, Emmanuel', 'MP', 'ODM', 'Kakamega', 'Navakholo');
select public.stage_governance_leader('Naicca, Johnson Manya', 'MP', 'ODM', 'Kakamega', 'Mumias West');
select public.stage_governance_leader('Salasya, Peter Kalerwa', 'MP', 'DAP-K', 'Kakamega', 'Mumias East');
select public.stage_governance_leader('Nabulindo, Peter Oscar', 'MP', 'ODM', 'Kakamega', 'Matungu');
select public.stage_governance_leader('Mwale, Nicholas S. Tindi', 'MP', 'ODM', 'Kakamega', 'Butere');
select public.stage_governance_leader('Wangaya, Christopher Aseka', 'MP', 'ODM', 'Kakamega', 'Khwisero');
select public.stage_governance_leader('IkanaM, Frederick Lusuli', 'MP', 'ANC', 'Kakamega', 'Shinyalu');
select public.stage_governance_leader('Shinali, Bernard Masaka', 'MP', 'ODM', 'Kakamega', 'Ikolomani');
select public.stage_governance_leader('Kagesi, Kivai Ernest Ogesi', 'MP', 'ANC', 'Vihiga', 'Vihiga');
select public.stage_governance_leader('Logova, Sloya Clement', 'MP', 'UDA', 'Vihiga', 'Sabatia');
select public.stage_governance_leader('Gimose, Charles Gumini', 'MP', 'ANC', 'Vihiga', 'Hamisi');
select public.stage_governance_leader('Oyugi, Dick Maungu', 'MP', 'DAP-K', 'Vihiga', 'Luanda');
select public.stage_governance_leader('Omboko, Milemba Jeremiah', 'MP', 'ANC', 'Vihiga', 'Emuhaya');
select public.stage_governance_leader('Chesebe, Fred Kapondi', 'MP', 'UDA', 'Bungoma', 'Mt. Elgon');
select public.stage_governance_leader('Koyi, John Waluke', 'MP', 'JP', 'Bungoma', 'Sirisia');
select public.stage_governance_leader('Kalasinga, Joseph Simiyu Wekesa Majimbo', 'MP', 'FORD-K', 'Bungoma', 'Kabuchai');
select public.stage_governance_leader('Wamboka, Nelson Jack Wamboka', 'MP', 'DAP-K', 'Bungoma', 'Bumula');
select public.stage_governance_leader('Makali, John Okwisia', 'MP', 'FORD-K', 'Bungoma', 'Kanduyi');
select public.stage_governance_leader('Wanyonyi, Martin Pepela', 'MP', 'FORD-K', 'Bungoma', 'Webuye East');
select public.stage_governance_leader('Sitati, Daniel Wanyama', 'MP', 'UDA', 'Bungoma', 'Webuye West');
select public.stage_governance_leader('Mutua, Didmus Wekesa Barasa', 'MP', 'UDA', 'Bungoma', 'Kimilili');
select public.stage_governance_leader('Murumba, John Chikati', 'MP', 'FORD-K', 'Bungoma', 'Tongaren');
select public.stage_governance_leader('Oku, Edward Kaunya', 'MP', 'ODM', 'Busia', 'Teso North');
select public.stage_governance_leader('Otucho, Mary Emaase', 'MP', 'UDA', 'Busia', 'Teso South');
select public.stage_governance_leader('Mulanya, Geoffrey Ekesa', 'MP', 'Independent', 'Busia', 'Nambale');
select public.stage_governance_leader('Odanga, Geoffrey Makokha', 'MP', 'ODM', 'Busia', 'Matayos');
select public.stage_governance_leader('Oyula, Joseph H. Maero', 'MP', 'ODM', 'Busia', 'Butula');
select public.stage_governance_leader('Oundo, Wilberforce Ojiambo', 'MP', 'ODM', 'Busia', 'Funyula');
select public.stage_governance_leader('Wanjala, Raphael Sauti Bitta', 'MP', 'ODM', 'Busia', 'Budalangi');
select public.stage_governance_leader('Ochieng, David Ouma', 'MP', 'MDG', 'Siaya', 'Ugenya');
select public.stage_governance_leader('Wandayi, James Opiyo', 'MP', 'ODM', 'Siaya', 'Ugunja');
select public.stage_governance_leader('Samuel Onunga', 'MP', 'ODM', 'Siaya', 'Alego Usonga');
select public.stage_governance_leader('Odhiambo, Elisha Ochieng', 'MP', 'ODM', 'Siaya', 'Gem');
select public.stage_governance_leader('Ogolla, Gideon Ochanda', 'MP', 'ODM', 'Siaya', 'Bondo');
select public.stage_governance_leader('Amollo, Paul Otiende', 'MP', 'ODM', 'Siaya', 'Rarieda');
select public.stage_governance_leader('Ahmed, Shakeel Ahmed Shabbir', 'MP', 'Independent', 'Kisumu', 'Kisumu East');
select public.stage_governance_leader('Buyu, Rozaah Akiny', 'MP', 'ODM', 'Kisumu', 'Kisumu West');
select public.stage_governance_leader('Oron, Joshua Odongo', 'MP', 'ODM', 'Kisumu', 'Kisumu Central');
select public.stage_governance_leader('Nyikal, James Wambura', 'MP', 'ODM', 'Kisumu', 'Seme');
select public.stage_governance_leader('Odoyo, Okello Jared', 'MP', 'ODM', 'Kisumu', 'Nyando');
select public.stage_governance_leader('Oyoo, James Onyango', 'MP', 'ODM', 'Kisumu', 'Muhoroni');
select public.stage_governance_leader('Owuor, Joshua Aduma', 'MP', 'ODM', 'Kisumu', 'Nyakach');
select public.stage_governance_leader('Were, Charles Ong''ondo', 'MP', 'ODM', 'Homa Bay', 'Kasipul');
select public.stage_governance_leader('Obara, Eve Akinyi', 'MP', 'ODM', 'Homa Bay', 'Kabondo Kasipul');
select public.stage_governance_leader('Okuome, Andrew Adipo', 'MP', 'ODM', 'Homa Bay', 'Karachuonyo');
select public.stage_governance_leader('Gogo, Lilian Achieng', 'MP', 'ODM', 'Homa Bay', 'Rangwe');
select public.stage_governance_leader('Kaluma, George Peter Opondo', 'MP', 'ODM', 'Homa Bay', 'Homa Bay Town');
select public.stage_governance_leader('Owino, Martin Peters', 'MP', 'ODM', 'Homa Bay', 'Ndhiwa');
select public.stage_governance_leader('Odhiambo, Millie Grace Akoth', 'MP', 'ODM', 'Homa Bay', 'Suba North');
select public.stage_governance_leader('Omondi, Caroli', 'MP', 'ODM', 'Homa Bay', 'Suba South');
select public.stage_governance_leader('Abuor, Paul', 'MP', 'ODM', 'Migori', 'Rongo');
select public.stage_governance_leader('Owino, John Walter', 'MP', 'ODM', 'Migori', 'Awendo');
select public.stage_governance_leader('Mohamed, Junet Sheikh Nuh', 'MP', 'ODM', 'Migori', 'Suna East');
select public.stage_governance_leader('Masara, Peter Francis', 'MP', 'ODM', 'Migori', 'Suna West');
select public.stage_governance_leader('Nyamita, Mark Ogolla', 'MP', 'ODM', 'Migori', 'Uriri');
select public.stage_governance_leader('Odege, Tom Mboya', 'MP', 'ODM', 'Migori', 'Nyatike');
select public.stage_governance_leader('Robi, Mathias Nyamabe', 'MP', 'UDA', 'Migori', 'Kuria West');
select public.stage_governance_leader('Kemero, Maisori Marwa Kitayama', 'MP', 'UDA', 'Migori', 'Kuria East');
select public.stage_governance_leader('Onchoke, Charles', 'MP', 'UPA', 'Kisii', 'Bonchari');
select public.stage_governance_leader('Onyiego, Silvanus Osoro', 'MP', 'UDA', 'Kisii', 'South Mugirango');
select public.stage_governance_leader('Barongo, Nolfason Obadiah', 'MP', 'ODM', 'Kisii', 'Bomachoge Borabu');
select public.stage_governance_leader('Momanyi, Innocent Obiri', 'MP', 'WDM', 'Kisii', 'Bobasi');
select public.stage_governance_leader('Alfah, Miruka Ondieki', 'MP', 'UDA', 'Kisii', 'Bomachoge Chache');
select public.stage_governance_leader('Manduku, Daniel Ogwoka', 'MP', 'ODM', 'Kisii', 'Nyaribari Masaba');
select public.stage_governance_leader('Jhanda Zaheer', 'MP', 'UDA', 'Kisii', 'Nyaribari Chache');
select public.stage_governance_leader('Mokaya, Nyakundi Japheth', 'MP', 'UDA', 'Kisii', 'Kitutu Chache North');
select public.stage_governance_leader('Kibagendi, Antoney', 'MP', 'ODM', 'Kisii', 'Kitutu Chache South');
select public.stage_governance_leader('Gisairo, Clive Ombane', 'MP', 'ODM', 'Nyamira', 'Kitutu Masaba');
select public.stage_governance_leader('Mogaka, Stephen M.', 'MP', 'JP', 'Nyamira', 'West Mugirango');
select public.stage_governance_leader('Nyamoko, Joash Nyamache', 'MP', 'UDA', 'Nyamira', 'North Mugirango');
select public.stage_governance_leader('Osero, Patrick Kibagendi', 'MP', 'ODM', 'Nyamira', 'Borabu');
select public.stage_governance_leader('Wetangula, Timothy Wanyonyi', 'MP', 'ODM', 'Nairobi', 'Westlands');
select public.stage_governance_leader('Elachi, Beatrice Kadeveresia', 'MP', 'ODM', 'Nairobi', 'Dagoretti North');
select public.stage_governance_leader('Waweru, John Kiarie', 'MP', 'UDA', 'Nairobi', 'Dagoretti South');
select public.stage_governance_leader('Khodhe, Phelix Odiwuor', 'MP', 'ODM', 'Nairobi', 'Langata');
select public.stage_governance_leader('Orero, Peter Ochieng', 'MP', 'ODM', 'Nairobi', 'Kibra');
select public.stage_governance_leader('Mwafrika, Augustine Kamande', 'MP', 'UDA', 'Nairobi', 'Roysambu');
select public.stage_governance_leader('Karauri, Ronald Kamwiko', 'MP', 'Independent', 'Nairobi', 'Kasarani');
select public.stage_governance_leader('Francis, Kajwang Tom Joseph', 'MP', 'ODM', 'Nairobi', 'Ruaraka');
select public.stage_governance_leader('Mawathe, Julius Musili', 'MP', 'WDM', 'Nairobi', 'Embakasi South');
select public.stage_governance_leader('Gakuya, James Mwangi', 'MP', 'UDA', 'Nairobi', 'Embakasi North');
select public.stage_governance_leader('Gathiru, Mejjadonk Benjamin', 'MP', 'UDA', 'Nairobi', 'Embakasi Central');
select public.stage_governance_leader('Ongili, Babu Owino Paul', 'MP', 'ODM', 'Nairobi', 'Embakasi East');
select public.stage_governance_leader('Mwenje, Mark Samuel Muriithi', 'MP', 'JP', 'Nairobi', 'Embakasi West');
select public.stage_governance_leader('Omwera, George Aladwa', 'MP', 'ODM', 'Nairobi', 'Makadara');
select public.stage_governance_leader('Hassan, Abdi Yusuf', 'MP', 'JP', 'Nairobi', 'Kamkunji');
select public.stage_governance_leader('Maina, Mwago Amos', 'MP', 'JP', 'Nairobi', 'Starehe');
select public.stage_governance_leader('Oluoch, Anthony Tom', 'MP', 'ODM', 'Nairobi', 'Mathare');

drop function public.stage_county(int, text);
drop function public.stage_subcounty(int, text, text);
drop function public.stage_governance_leader(text, text, text, text, text);

create or replace view public.v_geographic_governance as
select
  c.id as county_id,
  c.name as county_name,
  s.id as subcounty_id,
  s.name as subcounty_name,
  g.name as governor_name,
  g.party_name as governor_party,
  m.name as mp_name,
  m.party_name as mp_party
from public.subcounties s
join public.counties c on c.id = s.county_id
left join public.leaders g on g.county_id = c.id and g.role = 'Governor'
left join public.leaders m on m.subcounty_id = s.id and m.role = 'MP';

grant select on public.counties to anon, authenticated;
grant select on public.subcounties to anon, authenticated;
grant select on public.leaders to anon, authenticated;
grant select on public.v_geographic_governance to anon, authenticated;

commit;
