//The first sql i have run is this 
-- =========================================================================
-- PHASE 1: RE-INITIALIZE SCHEMAS CLEANLY
-- =========================================================================
drop view if exists v_geographic_governance cascade;
drop table if exists leaders cascade;
drop table if exists subcounties cascade;
drop table if exists counties cascade;

-- Counties Table
create table counties (
    id integer primary key,
    name varchar(50) not null unique,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Sub-Counties Table
create table subcounties (
    id serial primary key,
    county_id integer not null references counties(id) on delete cascade,
    name varchar(100) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint unique_subcounty_per_county unique (county_id, name)
);

-- Leaders Table
create table leaders (
    id uuid primary key default gen_random_uuid(),
    name varchar(150) not null,
    role varchar(20) not null check (role in ('Governor', 'MP')),
    party_name varchar(100) not null,
    county_id integer not null references counties(id) on delete cascade,
    subcounty_id integer references subcounties(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    
    constraint check_leader_jurisdiction check (
        (role = 'Governor' and subcounty_id is null) or
        (role = 'MP' and subcounty_id is not null)
    )
);

-- Core Constraints and Indexes
create unique index unique_active_governor on leaders (county_id) where (role = 'Governor');
create unique index unique_active_mp on leaders (subcounty_id) where (role = 'MP');
create index idx_subcounties_county_id on subcounties(county_id);
create index idx_leaders_lookup on leaders(county_id, subcounty_id);


-- =========================================================================
-- PHASE 2: COMPREHENSIVE GEOGRAPHIC SEED MATRIX
-- =========================================================================

-- Seed All Required Counties
insert into counties (id, name) values
(1, 'Mombasa'), (2, 'Kwale'), (9, 'Mandera'), (11, 'Isiolo'), (12, 'Meru'), 
(14, 'Embu'), (16, 'Machakos'), (24, 'West Pokot'), (25, 'Samburu'), 
(26, 'Trans Nzoia'), (32, 'Nakuru'), (33, 'Narok'), (36, 'Bomet'), 
(37, 'Kakamega'), (38, 'Vihiga'), (39, 'Bungoma'), (40, 'Busia'), 
(41, 'Siaya'), (42, 'Kisumu'), (44, 'Homa Bay'), (47, 'Nairobi')
on conflict (id) do nothing;

-- Explicitly seed EVERY sub-county referenced in our dataset to guarantee matching
insert into subcounties (county_id, name) values
(1, 'Changamwe'), (1, 'Jomvu'), (1, 'Kisauni'), (1, 'Nyali'), (1, 'Likoni'), (1, 'Mvita'),
(2, 'Matuga'), (2, 'Msambweni'),
(9, 'Lafey'), (9, 'Mandera North'),
(11, 'Isiolo North'),
(12, 'North Imenti'), (12, 'South Imenti'), (12, 'Igembe Central'), (12, 'Tigania East'), (12, 'Buuri'), (12, 'Igembe South'),
(14, 'Mbeere North'), (14, 'Mbeere South'), (14, 'Manyatta'), (14, 'Runyenjes'), (14, 'Embu (CWR)'),
(16, 'Kangundo'), (16, 'Masinga'), (16, 'Machakos Town'), (16, 'Matungulu'), (16, 'Mwala'),
(24, 'Pokot South'), (24, 'Kacheliba'), (24, 'Kapenguria'), (24, 'Sigor'),
(25, 'Samburu East'), (25, 'Samburu West'), (25, 'Samburu North'),
(26, 'Cherangany'), (26, 'Kiminini'), (26, 'Kwanza'), (26, 'Endebess'),
(32, 'Nakuru Town West'), (32, 'Rongai'), (32, 'Njoro'), (32, 'Nakuru Town East'), (32, 'Molo'), (32, 'Kuresoi North'), (32, 'Kuresoi South'), (32, 'Gilgil'),
(33, 'Narok South'), (33, 'Narok North'), (33, 'Emurua Dikirr'), (33, 'Narok West'),
(36, 'Chepalungu'), (36, 'Bomet Central'), (36, 'Sotik'), (36, 'Konoin'), (36, 'Bomet East'),
(37, 'Shinyalu'), (37, 'Malava'), (37, 'Mumias East'), (37, 'Mumias West'), (37, 'Matungu'), (37, 'Butere'), (37, 'Lugari'), (37, 'Lurambi'), (37, 'Kakamega (CWR)'), (37, 'Ikolomani'), (37, 'Navakholo'), (37, 'Khwisero'), (37, 'Kiharu'),
(38, 'Hamisi'), (38, 'Vihiga'), (38, 'Emuhaya'), (38, 'Luanda'), (38, 'Sabatia'),
(39, 'Bumula'), (39, 'Kabuchai'), (39, 'Kanduyi'), (39, 'Tongaren'), (39, 'Webuye West'), (39, 'Sirisia'), (39, 'Mt. Elgon'), (39, 'Kimilili'),
(40, 'Nambale'), (40, 'Funyula'), (40, 'Budalangi'),
(41, 'Ugenya'), (41, 'Rarieda'), (41, 'Alego Usonga'), (41, 'Gem'), (41, 'Siaya (CWR)'), (41, 'Bondo'), (41, 'Ugunja'),
(42, 'Kisumu East'), (42, 'Kisumu West'), (42, 'Seme'), (42, 'Nyando'), (42, 'Kisumu Central'), (42, 'Muhoroni'), (42, 'Nyakach'),
(44, 'Rongo'), (44, 'Homa Bay Town'), (44, 'Rangwe'), (44, 'Suna East'), (44, 'Awendo'), (44, 'Ndhiwa'), (44, 'Homa Bay (CWR)'), (44, 'Kasipul'), (44, 'Suna West'), (44, 'Suba North'), (44, 'Karachuonyo'),
(47, 'Kasarani'), (47, 'Gatundu North'), (47, 'Kamkunji'), (47, 'Starehe'), (47, 'Embakasi West'), (47, 'Westlands'), (47, 'Embakasi East'), (47, 'Langata'), (47, 'Dagoretti North'), (47, 'Ruaraka'), (47, 'Mathare'), (47, 'Makadara'), (47, 'Kibra'), (47, 'Embakasi South'), (47, 'Embakasi North'), (47, 'Embakasi Central'), (47, 'Royasambu'), (47, 'Dagoretti South')
on conflict on constraint unique_subcounty_per_county do nothing;


-- =========================================================================
-- PHASE 3: BULK INGESTION WITH ROBUST ERROR HANDLING
-- =========================================================================

create or replace function stage_leader(
    p_name varchar, p_role varchar, p_party varchar, p_county_id integer, p_subcounty_name varchar default null
) returns void as $$
declare
    v_subcounty_id integer := null;
begin
    if p_role = 'MP' and p_subcounty_name is not null then
        select id into v_subcounty_id from subcounties 
        where county_id = p_county_id and lower(trim(name)) = lower(trim(p_subcounty_name)) limit 1;
        
        -- Fallback: If it's a structural mismatch but the county exists, create it dynamically to prevent constraint failures
        if v_subcounty_id is null then
            insert into subcounties (county_id, name) values (p_county_id, p_subcounty_name)
            returning id into v_subcounty_id;
        end if;
    end if;

    insert into leaders (name, role, party_name, county_id, subcounty_id)
    values (p_name, p_role, p_party, p_county_id, v_subcounty_id) on conflict do nothing;
end;
$$ language plpgsql;

-- Governors
select stage_leader('Abdullswamad Sherrif Nassir', 'Governor', 'ODM', 1);
select stage_leader('Fatuma Achani', 'Governor', 'UDA', 2);
select stage_leader('Kawira Mwangaza', 'Governor', 'Independent', 12);
select stage_leader('Cecily Mbarire', 'Governor', 'UDA', 14);
select stage_leader('Wavinya Ndeti', 'Governor', 'Wiper', 16);
select stage_leader('Simon Kachapin', 'Governor', 'UDA', 24);
select stage_leader('Lati Lelelit', 'Governor', 'UDA', 25);
select stage_leader('George Natembeya', 'Governor', 'DAP-K', 26);
select stage_leader('Patrick Keturet Ole Ntutu', 'Governor', 'UDA', 33);
select stage_leader('Hillary Barchork', 'Governor', 'UDA', 36);
select stage_leader('Fernandes Barasa', 'Governor', 'ODM', 37);
select stage_leader('Wilberforce Khasilwa Ottichilo', 'Governor', 'ODM', 38);
select stage_leader('Kenneth Lusaka', 'Governor', 'UDA', 39);
select stage_leader('James Orengo', 'Governor', 'ODM', 41);
select stage_leader('Anyang Nyongo', 'Governor', 'ODM', 42);
select stage_leader('Gladys Wanga', 'Governor', 'ODM', 44);
select stage_leader('Johnson Sakaja', 'Governor', 'UDA', 47);

-- National Assembly MPs
select stage_leader('Gimose Charles Gumini', 'MP', 'ANC', 38, 'Hamisi');
select stage_leader('IkanaM Frederick Lusuli', 'MP', 'ANC', 37, 'Shinyalu');
select stage_leader('Injendi Moses Malulu', 'MP', 'ANC', 37, 'Malava');
select stage_leader('Kagesi Kivai Ernest Ogesi', 'MP', 'ANC', 38, 'Vihiga');
select stage_leader('Omboko Milemba Jeremiah', 'MP', 'ANC', 38, 'Emuhaya');
select stage_leader('Tandaza Kassim Sawa', 'MP', 'ANC', 2, 'Matuga');
select stage_leader('Koech Victor Kipngetich', 'MP', 'CCM', 36, 'Chepalungu');
select stage_leader('Barasa Patrick Simiyu', 'MP', 'DAP-K', 26, 'Cherangany');
select stage_leader('Bisau Maurice Kakai', 'MP', 'DAP-K', 26, 'Kiminini');
select stage_leader('Oyugi Dick Maungu', 'MP', 'DAP-K', 38, 'Luanda');
select stage_leader('Salasya Peter Kalerwa', 'MP', 'DAP-K', 37, 'Mumias East');
select stage_leader('Wamboka Nelson Jack Wamboka', 'MP', 'DAP-K', 39, 'Bumula');
select stage_leader('Ruku Geoffrey Kariuki Kiringa', 'MP', 'DP', 14, 'Mbeere North');
select stage_leader('Kalasinga Joseph Simiyu Wekesa Majimbo', 'MP', 'FORD-K', 39, 'Kabuchai');
select stage_leader('Makali John Okwisia', 'MP', 'FORD-K', 39, 'Kanduyi');
select stage_leader('Murumba John Chikati', 'MP', 'FORD-K', 39, 'Tongaren');
select stage_leader('Wanyonyi Ferdinand Kevin', 'MP', 'FORD-K', 26, 'Kwanza');
select stage_leader('Wanyonyi Martin Pepela', 'MP', 'FORD-K', 39, 'Webuye West');
select stage_leader('Muli Fabian Kyule', 'MP', 'GDDP', 16, 'Kangundo');
select stage_leader('Abdul Rahim Dawood', 'MP', 'Independent', 12, 'North Imenti');
select stage_leader('Ahmed Shakeel Ahmed Shabbir', 'MP', 'Independent', 42, 'Kisumu East');
select stage_leader('Karauri Ronald Kamwiko', 'MP', 'Independent', 47, 'Kasarani');
select stage_leader('Kitilai Ole Ntutu', 'MP', 'Independent', 33, 'Narok South');
select stage_leader('Kururia Elijah Njore Njoroge', 'MP', 'Independent', 47, 'Gatundu North');
select stage_leader('Mulanya Geoffrey Ekesa', 'MP', 'Independent', 40, 'Nambale');
select stage_leader('Mwalyo Joshua Mbithi Mutua', 'MP', 'Independent', 16, 'Masinga');
select stage_leader('Nebart Bernard Muriuki', 'MP', 'Independent', 14, 'Mbeere South');
select stage_leader('Abdirahman Mohamed Abdi', 'MP', 'JP', 9, 'Lafey');
select stage_leader('Arama Samuel', 'MP', 'JP', 32, 'Nakuru Town West');
select stage_leader('Hassan Abdi Yusuf', 'MP', 'JP', 47, 'Kamkunji');
select stage_leader('Ithinji Dr. Shadrack Mwiti', 'MP', 'JP', 12, 'South Imenti');
select stage_leader('Karitho Kiili Daniel', 'MP', 'JP', 12, 'Igembe Central');
select stage_leader('Koyi John Waluke', 'MP', 'JP', 39, 'Sirisia');
select stage_leader('Lomwa Joseph Samal', 'MP', 'JP', 11, 'Isiolo North');
select stage_leader('Maina Mwago Amos', 'MP', 'JP', 47, 'Starehe');
select stage_leader('Mwenje Mark Samuel Muriithi', 'MP', 'JP', 47, 'Embakasi West');
select stage_leader('Aburi Lawrence Mpuru', 'MP', 'NOPEU', 12, 'Tigania East');
select stage_leader('Wetangula Timothy Wanyonyi', 'MP', 'ODM', 47, 'Westlands');
select stage_leader('Babu Owino Paul Ongili', 'MP', 'ODM', 47, 'Embakasi East');
select stage_leader('Khodhe Phelix Odiwuor', 'MP', 'ODM', 47, 'Langata');
select stage_leader('Abuor Paul', 'MP', 'ODM', 44, 'Rongo');
select stage_leader('Amollo Paul Otiende', 'MP', 'ODM', 41, 'Rarieda');
select stage_leader('Samuel Onunga', 'MP', 'ODM', 41, 'Alego Usonga');
select stage_leader('Bady Twalib', 'MP', 'ODM', 1, 'Jomvu');
select stage_leader('Bedzumba Rashid juma', 'MP', 'ODM', 1, 'Kisauni');
select stage_leader('Elachi Beatrice Kadeveresia', 'MP', 'ODM', 47, 'Dagoretti North');
select stage_leader('Francis Kajwang Tom Joseph', 'MP', 'ODM', 47, 'Ruaraka');
select stage_leader('Kaluma George Peter Opondo', 'MP', 'ODM', 44, 'Homa Bay Town');
select stage_leader('Machele Mohamed Soud', 'MP', 'ODM', 1, 'Mvita');
select stage_leader('Mboko Mishi Juma Khamisi', 'MP', 'ODM', 1, 'Likoni');
select stage_leader('Mohamed Junet Sheikh Nuh', 'MP', 'ODM', 44, 'Suna East');
select stage_leader('Naicca Johnson Manya', 'MP', 'ODM', 37, 'Mumias West');
select stage_leader('Nabulindo Peter Oscar', 'MP', 'ODM', 37, 'Matungu');
select stage_leader('Mvale Nicholas S. Tindi', 'MP', 'ODM', 37, 'Butere');
select stage_leader('Nabii Nabwera Daraja', 'MP', 'ODM', 37, 'Lugari');
select stage_leader('Muhanda Elsie Busihile', 'MP', 'ODM', 37, 'Kakamega (CWR)');
select stage_leader('Mukhwana Titus Khamala', 'MP', 'ODM', 37, 'Lurambi');
select stage_leader('Odhiambo Elisha Ochieng', 'MP', 'ODM', 41, 'Gem');
select stage_leader('Oduor Christine Ombaka', 'MP', 'ODM', 41, 'Siaya (CWR)');
select stage_leader('Ogolla Gideon Ochanda', 'MP', 'ODM', 41, 'Bondo');
select stage_leader('Oluoch Anthony Tom', 'MP', 'ODM', 47, 'Mathare');
select stage_leader('Omwera George Aladwa', 'MP', 'ODM', 47, 'Makadara');
select stage_leader('Orero Peter Ochieng', 'MP', 'ODM', 47, 'Kibra');
select stage_leader('Oron Joshua Odongo', 'MP', 'ODM', 42, 'Kisumu Central');
select stage_leader('Oundo Wilberforce Ojiambo', 'MP', 'ODM', 40, 'Funyula');
select stage_leader('Owino John Walter', 'MP', 'ODM', 44, 'Awendo');
select stage_leader('Owino Martin Peters', 'MP', 'ODM', 44, 'Ndhiwa');
select stage_leader('Ovuor Joshua Aduma', 'MP', 'ODM', 42, 'Nyakach');
select stage_leader('Oyoo James Onyango', 'MP', 'ODM', 42, 'Muhoroni');
select stage_leader('Shimbwa Omar Mwinyi', 'MP', 'ODM', 1, 'Changamwe');
select stage_leader('Shinali Bernard Masaka', 'MP', 'ODM', 37, 'Ikolomani');
select stage_leader('Wandayi James Opiyo', 'MP', 'ODM', 41, 'Ugunja');
select stage_leader('Wangaya Christopher Aseka', 'MP', 'ODM', 37, 'Khwisero');
select stage_leader('Wangwe Emmanuel', 'MP', 'ODM', 37, 'Navakholo');
select stage_leader('Wanjala Raphael Sauti Bitta', 'MP', 'ODM', 40, 'Budalangi');
select stage_leader('Were Charles Ong''ondo', 'MP', 'ODM', 44, 'Kasipul');
select stage_leader('Bader Salim Feisal', 'MP', 'UDA', 2, 'Msambweni');
select stage_leader('Chebor Paul Kibet', 'MP', 'UDA', 32, 'Rongai');
select stage_leader('Chepkwony Charity Kathambi', 'MP', 'UDA', 32, 'Njoro');
select stage_leader('Chumel Samwel Moroto', 'MP', 'UDA', 24, 'Kapenguria');
select stage_leader('Double N Pamela Njoki Njeru', 'MP', 'UDA', 14, 'Embu (CWR)');
select stage_leader('Gakuya James Mwangi', 'MP', 'UDA', 47, 'Embakasi North');
select stage_leader('Gathiru Mejjadonk Benjamin', 'MP', 'UDA', 47, 'Embakasi Central');
select stage_leader('Gikaria David', 'MP', 'UDA', 32, 'Nakuru Town East');
select stage_leader('Karemba Eric Muchangi Njiru', 'MP', 'UDA', 14, 'Runyenjes');
select stage_leader('Kilel Richard Cheruiyot', 'MP', 'UDA', 36, 'Bomet Central');
select stage_leader('Kimani Francis Kuria', 'MP', 'UDA', 32, 'Molo');
select stage_leader('Kipkoros Joseph Makilap', 'MP', 'UDA', 33, 'Baringo North');
select stage_leader('Kiprono Mutai Alfred', 'MP', 'UDA', 32, 'Kuresoi North');
select stage_leader('Lochakapong Peter', 'MP', 'UDA', 24, 'Sigor');
select stage_leader('Logova Sloya Clement', 'MP', 'UDA', 38, 'Sabatia');
select stage_leader('Mizighi Lydia Haika Mnene', 'MP', 'UDA', 1, 'Nyali');
select stage_leader('Mukunji John Gitonga Mwaniki', 'MP', 'UDA', 14, 'Manyatta');
select stage_leader('Muriu Wakili Edward', 'MP', 'UDA', 12, 'Buuri');
select stage_leader('Mutua Didmus Wekesa Barasa', 'MP', 'UDA', 39, 'Kimilili');
select stage_leader('Mutunga John Kanyuithia', 'MP', 'UDA', 12, 'Tigania West');
select stage_leader('Mwafrika Augustine Kamande', 'MP', 'UDA', 47, 'Royasambu');
select stage_leader('Nyoro Samson Ndindi', 'MP', 'UDA', 37, 'Kiharu');
select stage_leader('Pukose Robert (Dr.)', 'MP', 'UDA', 26, 'Endebess');
select stage_leader('Saney Ibrahim Abdi', 'MP', 'UDA', 9, 'Mandera North');
select stage_leader('Sigei Francis Kipyegon arap', 'MP', 'UDA', 36, 'Sotik');
select stage_leader('Sitati Daniel Wanyama', 'MP', 'UDA', 39, 'Webuye West');
select stage_leader('Tongoyo Gabriel Koshal', 'MP', 'UDA', 33, 'Narok West');
select stage_leader('Tonui Joseph Kipkosgei', 'MP', 'UDA', 32, 'Kuresoi South');
select stage_leader('Wanjira Martha Wangari', 'MP', 'UDA', 32, 'Gilgil');
select stage_leader('Waweru John Kiarie', 'MP', 'UDA', 47, 'Dagoretti South');
select stage_leader('Yegon Brighton Leonard', 'MP', 'UDA', 36, 'Konoin');
select stage_leader('Yegon Richard Kipkemoi', 'MP', 'UDA', 36, 'Bomet East');
select stage_leader('Mawathe Julius Musili', 'MP', 'WDM', 47, 'Embakasi South');

drop function stage_leader(varchar, varchar, varchar, integer, varchar);

-- =========================================================================
-- PHASE 4: DISPATCH ENVIRONMENT CONSUMPTION VIEW
-- =========================================================================
create or replace view v_geographic_governance as
select 
    c.id as county_id,
    c.name as county_name,
    s.id as subcounty_id,
    s.name as subcounty_name,
    g.name as governor_name,
    g.party_name as governor_party,
    m.name as mp_name,
    m.party_name as mp_party
from subcounties s
join counties c on s.county_id = c.id
left join leaders g on g.county_id = c.id and g.role = 'Governor'
left join leaders m on m.subcounty_id = s.id and m.role = 'MP';



the 2nd sql is this
-- =========================================================================
-- PHASE 1: RE-INITIALIZE SCHEMAS CLEANLY
-- =========================================================================
drop view if exists v_geographic_governance cascade;
drop table if exists leaders cascade;
drop table if exists subcounties cascade;
drop table if exists counties cascade;

-- Counties Table
create table counties (
    id integer primary key,
    name varchar(50) not null unique,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Sub-Counties Table
create table subcounties (
    id serial primary key,
    county_id integer not null references counties(id) on delete cascade,
    name varchar(100) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint unique_subcounty_per_county unique (county_id, name)
);

-- Leaders Table
create table leaders (
    id uuid primary key default gen_random_uuid(),
    name varchar(150) not null,
    role varchar(20) not null check (role in ('Governor', 'MP')),
    party_name varchar(100) not null,
    county_id integer not null references counties(id) on delete cascade,
    subcounty_id integer references subcounties(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    
    constraint check_leader_jurisdiction check (
        (role = 'Governor' and subcounty_id is null) or
        (role = 'MP' and subcounty_id is not null)
    )
);

-- Core Constraints and Indexes
create unique index unique_active_governor on leaders (county_id) where (role = 'Governor');
create unique index unique_active_mp on leaders (subcounty_id) where (role = 'MP');
create index idx_subcounties_county_id on subcounties(county_id);
create index idx_leaders_lookup on leaders(county_id, subcounty_id);


-- =========================================================================
-- PHASE 2: COMPREHENSIVE GEOGRAPHIC SEED MATRIX
-- =========================================================================

-- Seed All Required Counties
insert into counties (id, name) values
(1, 'Mombasa'), (2, 'Kwale'), (9, 'Mandera'), (11, 'Isiolo'), (12, 'Meru'), 
(14, 'Embu'), (16, 'Machakos'), (24, 'West Pokot'), (25, 'Samburu'), 
(26, 'Trans Nzoia'), (32, 'Nakuru'), (33, 'Narok'), (36, 'Bomet'), 
(37, 'Kakamega'), (38, 'Vihiga'), (39, 'Bungoma'), (40, 'Busia'), 
(41, 'Siaya'), (42, 'Kisumu'), (44, 'Homa Bay'), (47, 'Nairobi')
on conflict (id) do nothing;

-- Explicitly seed EVERY sub-county referenced in our dataset to guarantee matching
insert into subcounties (county_id, name) values
(1, 'Changamwe'), (1, 'Jomvu'), (1, 'Kisauni'), (1, 'Nyali'), (1, 'Likoni'), (1, 'Mvita'),
(2, 'Matuga'), (2, 'Msambweni'),
(9, 'Lafey'), (9, 'Mandera North'),
(11, 'Isiolo North'),
(12, 'North Imenti'), (12, 'South Imenti'), (12, 'Igembe Central'), (12, 'Tigania East'), (12, 'Buuri'), (12, 'Igembe South'),
(14, 'Mbeere North'), (14, 'Mbeere South'), (14, 'Manyatta'), (14, 'Runyenjes'), (14, 'Embu (CWR)'),
(16, 'Kangundo'), (16, 'Masinga'), (16, 'Machakos Town'), (16, 'Matungulu'), (16, 'Mwala'),
(24, 'Pokot South'), (24, 'Kacheliba'), (24, 'Kapenguria'), (24, 'Sigor'),
(25, 'Samburu East'), (25, 'Samburu West'), (25, 'Samburu North'),
(26, 'Cherangany'), (26, 'Kiminini'), (26, 'Kwanza'), (26, 'Endebess'),
(32, 'Nakuru Town West'), (32, 'Rongai'), (32, 'Njoro'), (32, 'Nakuru Town East'), (32, 'Molo'), (32, 'Kuresoi North'), (32, 'Kuresoi South'), (32, 'Gilgil'),
(33, 'Narok South'), (33, 'Narok North'), (33, 'Emurua Dikirr'), (33, 'Narok West'),
(36, 'Chepalungu'), (36, 'Bomet Central'), (36, 'Sotik'), (36, 'Konoin'), (36, 'Bomet East'),
(37, 'Shinyalu'), (37, 'Malava'), (37, 'Mumias East'), (37, 'Mumias West'), (37, 'Matungu'), (37, 'Butere'), (37, 'Lugari'), (37, 'Lurambi'), (37, 'Kakamega (CWR)'), (37, 'Ikolomani'), (37, 'Navakholo'), (37, 'Khwisero'), (37, 'Kiharu'),
(38, 'Hamisi'), (38, 'Vihiga'), (38, 'Emuhaya'), (38, 'Luanda'), (38, 'Sabatia'),
(39, 'Bumula'), (39, 'Kabuchai'), (39, 'Kanduyi'), (39, 'Tongaren'), (39, 'Webuye West'), (39, 'Sirisia'), (39, 'Mt. Elgon'), (39, 'Kimilili'),
(40, 'Nambale'), (40, 'Funyula'), (40, 'Budalangi'),
(41, 'Ugenya'), (41, 'Rarieda'), (41, 'Alego Usonga'), (41, 'Gem'), (41, 'Siaya (CWR)'), (41, 'Bondo'), (41, 'Ugunja'),
(42, 'Kisumu East'), (42, 'Kisumu West'), (42, 'Seme'), (42, 'Nyando'), (42, 'Kisumu Central'), (42, 'Muhoroni'), (42, 'Nyakach'),
(44, 'Rongo'), (44, 'Homa Bay Town'), (44, 'Rangwe'), (44, 'Suna East'), (44, 'Awendo'), (44, 'Ndhiwa'), (44, 'Homa Bay (CWR)'), (44, 'Kasipul'), (44, 'Suna West'), (44, 'Suba North'), (44, 'Karachuonyo'),
(47, 'Kasarani'), (47, 'Gatundu North'), (47, 'Kamkunji'), (47, 'Starehe'), (47, 'Embakasi West'), (47, 'Westlands'), (47, 'Embakasi East'), (47, 'Langata'), (47, 'Dagoretti North'), (47, 'Ruaraka'), (47, 'Mathare'), (47, 'Makadara'), (47, 'Kibra'), (47, 'Embakasi South'), (47, 'Embakasi North'), (47, 'Embakasi Central'), (47, 'Royasambu'), (47, 'Dagoretti South')
on conflict on constraint unique_subcounty_per_county do nothing;


-- =========================================================================
-- PHASE 3: BULK INGESTION WITH ROBUST ERROR HANDLING
-- =========================================================================

create or replace function stage_leader(
    p_name varchar, p_role varchar, p_party varchar, p_county_id integer, p_subcounty_name varchar default null
) returns void as $$
declare
    v_subcounty_id integer := null;
begin
    if p_role = 'MP' and p_subcounty_name is not null then
        select id into v_subcounty_id from subcounties 
        where county_id = p_county_id and lower(trim(name)) = lower(trim(p_subcounty_name)) limit 1;
        
        -- Fallback: If it's a structural mismatch but the county exists, create it dynamically to prevent constraint failures
        if v_subcounty_id is null then
            insert into subcounties (county_id, name) values (p_county_id, p_subcounty_name)
            returning id into v_subcounty_id;
        end if;
    end if;

    insert into leaders (name, role, party_name, county_id, subcounty_id)
    values (p_name, p_role, p_party, p_county_id, v_subcounty_id) on conflict do nothing;
end;
$$ language plpgsql;

-- Governors
select stage_leader('Abdullswamad Sherrif Nassir', 'Governor', 'ODM', 1);
select stage_leader('Fatuma Achani', 'Governor', 'UDA', 2);
select stage_leader('Kawira Mwangaza', 'Governor', 'Independent', 12);
select stage_leader('Cecily Mbarire', 'Governor', 'UDA', 14);
select stage_leader('Wavinya Ndeti', 'Governor', 'Wiper', 16);
select stage_leader('Simon Kachapin', 'Governor', 'UDA', 24);
select stage_leader('Lati Lelelit', 'Governor', 'UDA', 25);
select stage_leader('George Natembeya', 'Governor', 'DAP-K', 26);
select stage_leader('Patrick Keturet Ole Ntutu', 'Governor', 'UDA', 33);
select stage_leader('Hillary Barchork', 'Governor', 'UDA', 36);
select stage_leader('Fernandes Barasa', 'Governor', 'ODM', 37);
select stage_leader('Wilberforce Khasilwa Ottichilo', 'Governor', 'ODM', 38);
select stage_leader('Kenneth Lusaka', 'Governor', 'UDA', 39);
select stage_leader('James Orengo', 'Governor', 'ODM', 41);
select stage_leader('Anyang Nyongo', 'Governor', 'ODM', 42);
select stage_leader('Gladys Wanga', 'Governor', 'ODM', 44);
select stage_leader('Johnson Sakaja', 'Governor', 'UDA', 47);

-- National Assembly MPs
select stage_leader('Gimose Charles Gumini', 'MP', 'ANC', 38, 'Hamisi');
select stage_leader('IkanaM Frederick Lusuli', 'MP', 'ANC', 37, 'Shinyalu');
select stage_leader('Injendi Moses Malulu', 'MP', 'ANC', 37, 'Malava');
select stage_leader('Kagesi Kivai Ernest Ogesi', 'MP', 'ANC', 38, 'Vihiga');
select stage_leader('Omboko Milemba Jeremiah', 'MP', 'ANC', 38, 'Emuhaya');
select stage_leader('Tandaza Kassim Sawa', 'MP', 'ANC', 2, 'Matuga');
select stage_leader('Koech Victor Kipngetich', 'MP', 'CCM', 36, 'Chepalungu');
select stage_leader('Barasa Patrick Simiyu', 'MP', 'DAP-K', 26, 'Cherangany');
select stage_leader('Bisau Maurice Kakai', 'MP', 'DAP-K', 26, 'Kiminini');
select stage_leader('Oyugi Dick Maungu', 'MP', 'DAP-K', 38, 'Luanda');
select stage_leader('Salasya Peter Kalerwa', 'MP', 'DAP-K', 37, 'Mumias East');
select stage_leader('Wamboka Nelson Jack Wamboka', 'MP', 'DAP-K', 39, 'Bumula');
select stage_leader('Ruku Geoffrey Kariuki Kiringa', 'MP', 'DP', 14, 'Mbeere North');
select stage_leader('Kalasinga Joseph Simiyu Wekesa Majimbo', 'MP', 'FORD-K', 39, 'Kabuchai');
select stage_leader('Makali John Okwisia', 'MP', 'FORD-K', 39, 'Kanduyi');
select stage_leader('Murumba John Chikati', 'MP', 'FORD-K', 39, 'Tongaren');
select stage_leader('Wanyonyi Ferdinand Kevin', 'MP', 'FORD-K', 26, 'Kwanza');
select stage_leader('Wanyonyi Martin Pepela', 'MP', 'FORD-K', 39, 'Webuye West');
select stage_leader('Muli Fabian Kyule', 'MP', 'GDDP', 16, 'Kangundo');
select stage_leader('Abdul Rahim Dawood', 'MP', 'Independent', 12, 'North Imenti');
select stage_leader('Ahmed Shakeel Ahmed Shabbir', 'MP', 'Independent', 42, 'Kisumu East');
select stage_leader('Karauri Ronald Kamwiko', 'MP', 'Independent', 47, 'Kasarani');
select stage_leader('Kitilai Ole Ntutu', 'MP', 'Independent', 33, 'Narok South');
select stage_leader('Kururia Elijah Njore Njoroge', 'MP', 'Independent', 47, 'Gatundu North');
select stage_leader('Mulanya Geoffrey Ekesa', 'MP', 'Independent', 40, 'Nambale');
select stage_leader('Mwalyo Joshua Mbithi Mutua', 'MP', 'Independent', 16, 'Masinga');
select stage_leader('Nebart Bernard Muriuki', 'MP', 'Independent', 14, 'Mbeere South');
select stage_leader('Abdirahman Mohamed Abdi', 'MP', 'JP', 9, 'Lafey');
select stage_leader('Arama Samuel', 'MP', 'JP', 32, 'Nakuru Town West');
select stage_leader('Hassan Abdi Yusuf', 'MP', 'JP', 47, 'Kamkunji');
select stage_leader('Ithinji Dr. Shadrack Mwiti', 'MP', 'JP', 12, 'South Imenti');
select stage_leader('Karitho Kiili Daniel', 'MP', 'JP', 12, 'Igembe Central');
select stage_leader('Koyi John Waluke', 'MP', 'JP', 39, 'Sirisia');
select stage_leader('Lomwa Joseph Samal', 'MP', 'JP', 11, 'Isiolo North');
select stage_leader('Maina Mwago Amos', 'MP', 'JP', 47, 'Starehe');
select stage_leader('Mwenje Mark Samuel Muriithi', 'MP', 'JP', 47, 'Embakasi West');
select stage_leader('Aburi Lawrence Mpuru', 'MP', 'NOPEU', 12, 'Tigania East');
select stage_leader('Wetangula Timothy Wanyonyi', 'MP', 'ODM', 47, 'Westlands');
select stage_leader('Babu Owino Paul Ongili', 'MP', 'ODM', 47, 'Embakasi East');
select stage_leader('Khodhe Phelix Odiwuor', 'MP', 'ODM', 47, 'Langata');
select stage_leader('Abuor Paul', 'MP', 'ODM', 44, 'Rongo');
select stage_leader('Amollo Paul Otiende', 'MP', 'ODM', 41, 'Rarieda');
select stage_leader('Samuel Onunga', 'MP', 'ODM', 41, 'Alego Usonga');
select stage_leader('Bady Twalib', 'MP', 'ODM', 1, 'Jomvu');
select stage_leader('Bedzumba Rashid juma', 'MP', 'ODM', 1, 'Kisauni');
select stage_leader('Elachi Beatrice Kadeveresia', 'MP', 'ODM', 47, 'Dagoretti North');
select stage_leader('Francis Kajwang Tom Joseph', 'MP', 'ODM', 47, 'Ruaraka');
select stage_leader('Kaluma George Peter Opondo', 'MP', 'ODM', 44, 'Homa Bay Town');
select stage_leader('Machele Mohamed Soud', 'MP', 'ODM', 1, 'Mvita');
select stage_leader('Mboko Mishi Juma Khamisi', 'MP', 'ODM', 1, 'Likoni');
select stage_leader('Mohamed Junet Sheikh Nuh', 'MP', 'ODM', 44, 'Suna East');
select stage_leader('Naicca Johnson Manya', 'MP', 'ODM', 37, 'Mumias West');
select stage_leader('Nabulindo Peter Oscar', 'MP', 'ODM', 37, 'Matungu');
select stage_leader('Mvale Nicholas S. Tindi', 'MP', 'ODM', 37, 'Butere');
select stage_leader('Nabii Nabwera Daraja', 'MP', 'ODM', 37, 'Lugari');
select stage_leader('Muhanda Elsie Busihile', 'MP', 'ODM', 37, 'Kakamega (CWR)');
select stage_leader('Mukhwana Titus Khamala', 'MP', 'ODM', 37, 'Lurambi');
select stage_leader('Odhiambo Elisha Ochieng', 'MP', 'ODM', 41, 'Gem');
select stage_leader('Oduor Christine Ombaka', 'MP', 'ODM', 41, 'Siaya (CWR)');
select stage_leader('Ogolla Gideon Ochanda', 'MP', 'ODM', 41, 'Bondo');
select stage_leader('Oluoch Anthony Tom', 'MP', 'ODM', 47, 'Mathare');
select stage_leader('Omwera George Aladwa', 'MP', 'ODM', 47, 'Makadara');
select stage_leader('Orero Peter Ochieng', 'MP', 'ODM', 47, 'Kibra');
select stage_leader('Oron Joshua Odongo', 'MP', 'ODM', 42, 'Kisumu Central');
select stage_leader('Oundo Wilberforce Ojiambo', 'MP', 'ODM', 40, 'Funyula');
select stage_leader('Owino John Walter', 'MP', 'ODM', 44, 'Awendo');
select stage_leader('Owino Martin Peters', 'MP', 'ODM', 44, 'Ndhiwa');
select stage_leader('Ovuor Joshua Aduma', 'MP', 'ODM', 42, 'Nyakach');
select stage_leader('Oyoo James Onyango', 'MP', 'ODM', 42, 'Muhoroni');
select stage_leader('Shimbwa Omar Mwinyi', 'MP', 'ODM', 1, 'Changamwe');
select stage_leader('Shinali Bernard Masaka', 'MP', 'ODM', 37, 'Ikolomani');
select stage_leader('Wandayi James Opiyo', 'MP', 'ODM', 41, 'Ugunja');
select stage_leader('Wangaya Christopher Aseka', 'MP', 'ODM', 37, 'Khwisero');
select stage_leader('Wangwe Emmanuel', 'MP', 'ODM', 37, 'Navakholo');
select stage_leader('Wanjala Raphael Sauti Bitta', 'MP', 'ODM', 40, 'Budalangi');
select stage_leader('Were Charles Ong''ondo', 'MP', 'ODM', 44, 'Kasipul');
select stage_leader('Bader Salim Feisal', 'MP', 'UDA', 2, 'Msambweni');
select stage_leader('Chebor Paul Kibet', 'MP', 'UDA', 32, 'Rongai');
select stage_leader('Chepkwony Charity Kathambi', 'MP', 'UDA', 32, 'Njoro');
select stage_leader('Chumel Samwel Moroto', 'MP', 'UDA', 24, 'Kapenguria');
select stage_leader('Double N Pamela Njoki Njeru', 'MP', 'UDA', 14, 'Embu (CWR)');
select stage_leader('Gakuya James Mwangi', 'MP', 'UDA', 47, 'Embakasi North');
select stage_leader('Gathiru Mejjadonk Benjamin', 'MP', 'UDA', 47, 'Embakasi Central');
select stage_leader('Gikaria David', 'MP', 'UDA', 32, 'Nakuru Town East');
select stage_leader('Karemba Eric Muchangi Njiru', 'MP', 'UDA', 14, 'Runyenjes');
select stage_leader('Kilel Richard Cheruiyot', 'MP', 'UDA', 36, 'Bomet Central');
select stage_leader('Kimani Francis Kuria', 'MP', 'UDA', 32, 'Molo');
select stage_leader('Kipkoros Joseph Makilap', 'MP', 'UDA', 33, 'Baringo North');
select stage_leader('Kiprono Mutai Alfred', 'MP', 'UDA', 32, 'Kuresoi North');
select stage_leader('Lochakapong Peter', 'MP', 'UDA', 24, 'Sigor');
select stage_leader('Logova Sloya Clement', 'MP', 'UDA', 38, 'Sabatia');
select stage_leader('Mizighi Lydia Haika Mnene', 'MP', 'UDA', 1, 'Nyali');
select stage_leader('Mukunji John Gitonga Mwaniki', 'MP', 'UDA', 14, 'Manyatta');
select stage_leader('Muriu Wakili Edward', 'MP', 'UDA', 12, 'Buuri');
select stage_leader('Mutua Didmus Wekesa Barasa', 'MP', 'UDA', 39, 'Kimilili');
select stage_leader('Mutunga John Kanyuithia', 'MP', 'UDA', 12, 'Tigania West');
select stage_leader('Mwafrika Augustine Kamande', 'MP', 'UDA', 47, 'Royasambu');
select stage_leader('Nyoro Samson Ndindi', 'MP', 'UDA', 37, 'Kiharu');
select stage_leader('Pukose Robert (Dr.)', 'MP', 'UDA', 26, 'Endebess');
select stage_leader('Saney Ibrahim Abdi', 'MP', 'UDA', 9, 'Mandera North');
select stage_leader('Sigei Francis Kipyegon arap', 'MP', 'UDA', 36, 'Sotik');
select stage_leader('Sitati Daniel Wanyama', 'MP', 'UDA', 39, 'Webuye West');
select stage_leader('Tongoyo Gabriel Koshal', 'MP', 'UDA', 33, 'Narok West');
select stage_leader('Tonui Joseph Kipkosgei', 'MP', 'UDA', 32, 'Kuresoi South');
select stage_leader('Wanjira Martha Wangari', 'MP', 'UDA', 32, 'Gilgil');
select stage_leader('Waweru John Kiarie', 'MP', 'UDA', 47, 'Dagoretti South');
select stage_leader('Yegon Brighton Leonard', 'MP', 'UDA', 36, 'Konoin');
select stage_leader('Yegon Richard Kipkemoi', 'MP', 'UDA', 36, 'Bomet East');
select stage_leader('Mawathe Julius Musili', 'MP', 'WDM', 47, 'Embakasi South');

drop function stage_leader(varchar, varchar, varchar, integer, varchar);

-- =========================================================================
-- PHASE 4: DISPATCH ENVIRONMENT CONSUMPTION VIEW
-- =========================================================================
create or replace view v_geographic_governance as
select 
    c.id as county_id,
    c.name as county_name,
    s.id as subcounty_id,
    s.name as subcounty_name,
    g.name as governor_name,
    g.party_name as governor_party,
    m.name as mp_name,
    m.party_name as mp_party
from subcounties s
join counties c on s.county_id = c.id
left join leaders g on g.county_id = c.id and g.role = 'Governor'
left join leaders m on m.subcounty_id = s.id and m.role = 'MP';


the 3rd sql is this
-- ============================================================================
-- 1. EXTENSIONS & PREREQUISITES
-- ============================================================================
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Clean up any partial state safely
drop trigger if exists on_auth_user_created on auth.users;
drop table if exists notifications cascade;
drop table if exists security_events cascade;
drop table if exists audit_logs cascade;
drop table if exists user_sessions cascade;
drop table if exists legal_acceptance_logs cascade;
drop table if exists profiles cascade;

-- ============================================================================
-- 2. CORE PROFILES & STRUCTURAL AUDIT LOGGING
-- ============================================================================
create table profiles (
    id uuid references auth.users on delete cascade primary key,
    email text not null unique,
    username varchar(30) unique check (username ~* '^[a-zA-Z0-9_]+$'),
    civiq_code varchar(12) unique,
    phone text unique,
    bio varchar(500),
    avatar_url text,
    county_id integer references counties(id) on delete set null,
    subcounty_id integer references subcounties(id) on delete set null,
    is_verified boolean default false not null,
    is_public boolean default false not null, -- Private by default
    is_online boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Real-time validation function to safely guarantee geo-alignment without constraint conflicts
create or replace function check_profile_geo_alignment() 
returns trigger as $$
declare
    v_actual_county_id integer;
begin
    if new.subcounty_id is not null then
        select county_id into v_actual_county_id from subcounties where id = new.subcounty_id;
        if v_actual_county_id != new.county_id then
            raise exception 'Sub-county ID % does not belong to County ID %', new.subcounty_id, new.county_id;
        end if;
    end if;
    return new;
end;
$$ language plpgsql stable;

create trigger trg_validate_profile_geo
    before insert or update on profiles
    for each row execute function check_profile_geo_alignment();


create table legal_acceptance_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    policy_version varchar(20) not null,
    accepted_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table user_sessions (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    device_id text not null,
    token_version int default 1 not null,
    last_active_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table audit_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references profiles(id) on delete set null,
    action varchar(100) not null,
    ip_address varchar(45),
    device_id text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table security_events (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references profiles(id) on delete set null,
    event_type varchar(100) not null,
    metadata jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table notifications (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    title text not null,
    body text not null,
    is_read boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ============================================================================
-- 3. AUTOMATED SYSTEM TRIGGER PROCEDURES (CIVIQ CODE & INSTANT NOTIFICATIONS)
-- ============================================================================

-- Function: Generate Alphanumeric Unique Code
create or replace function generate_unique_civiq_code()
returns varchar as $$
declare
    chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    result varchar(12);
    is_unique boolean := false;
    p1 varchar(4);
    p2 varchar(2);
begin
    while not is_unique loop
        p1 := ''; p2 := '';
        for i in 1..4 loop
            p1 := p1 || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
        end loop;
        for i in 1..2 loop
            p2 := p2 || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
        end loop;
        result := 'CQ-' || p1 || '-' || p2;
        select not exists(select 1 from profiles where civiq_code = result) into is_unique;
    end loop;
    return result;
end;
$$ language plpgsql volatile;

-- Function: Handle New Signup Processing Engine
create or replace function handle_new_user_profile()
returns trigger as $$
declare
    v_civiq_code varchar;
begin
    v_civiq_code := generate_unique_civiq_code();
    
    -- 1. Create Core App Profile Record
    insert into public.profiles (id, email, civiq_code, is_verified, is_public)
    values (new.id, new.email, v_civiq_code, false, false);
    
    -- 2. Dispatch Welcome Notification 1
    insert into public.notifications (user_id, title, body)
    values (
        new.id,
        'Welcome to CIVIQ Africa 🌍',
        'Read our guidelines to help responsibly improve your local community. Your safe unique messaging key is active.'
    );
    
    -- 3. Dispatch Engagement Notification 2
    insert into public.notifications (user_id, title, body)
    values (
        new.id,
        'Action Required: File Local Report 📢',
        'Create your first civic project report and engage your local leadership right from your constituency grid.'
    );

    return new;
end;
$$ language plpgsql security definer;

-- Bind Trigger to Auth Signup
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function handle_new_user_profile();

-- ============================================================================
-- 4. USERNAME VALIDATION & SUGGESTION ENGINE
-- ============================================================================
create or replace function suggest_available_usernames(p_requested varchar)
returns table(suggested_username varchar) as $$
declare
    v_suffix integer := 1;
    v_candidate varchar;
    v_exists boolean;
    v_found_suggestions integer := 0;
begin
    p_requested := regexp_replace(p_requested, '[^a-zA-Z0-9_]', '', 'g');
    
    if p_requested = '' or p_requested is null then
        p_requested := 'civiq_user';
    end if;

    -- Option 1: Append country suffix
    v_candidate := substring(p_requested from 1 for 27) || '_KE';
    select exists(select 1 from profiles where username = v_candidate) into v_exists;
    if not v_exists then 
        suggested_username := v_candidate;
        v_found_suggestions := v_found_suggestions + 1;
        return next;
    end if;

    -- Option 2: Append platform suffix
    v_candidate := substring(p_requested from 1 for 27) || '_CQ';
    select exists(select 1 from profiles where username = v_candidate) into v_exists;
    if not v_exists then 
        suggested_username := v_candidate;
        v_found_suggestions := v_found_suggestions + 1;
        return next;
    end if;

    -- Option 3: Auto-increment sequentially
    while v_found_suggestions < 3 loop
        v_candidate := substring(p_requested from 1 for (29 - length(v_suffix::text))) || v_suffix::text;
        select exists(select 1 from profiles where username = v_candidate) into v_exists;
        
        if not v_exists then
            suggested_username := v_candidate;
            v_found_suggestions := v_found_suggestions + 1;
            return next;
        end if;
        
        v_suffix := v_suffix + floor(random() * 10 + 1)::integer;
    end loop;
end;
$$ language plpgsql stable;

-- ============================================================================
-- 5. ACCESS PRIVILEGE ROW-LEVEL SECURITY (RLS)
-- ============================================================================
alter table profiles enable row level security;
alter table notifications enable row level security;
alter table legal_acceptance_logs enable row level security;
alter table audit_logs enable row level security;

create policy "Profiles are queryable by authenticated users" on profiles for select to authenticated using (true);
create policy "Users can modify their own structural data" on profiles for update to authenticated using (auth.uid() = id);
create policy "Users can check their notifications" on notifications for select to authenticated using (auth.uid() = user_id);
create policy "Users can modify notification read states" on notifications for update to authenticated using (auth.uid() = user_id);
create policy "Users can view own legal signatures" on legal_acceptance_logs for select to authenticated using (auth.uid() = user_id);
create policy "Users can log legal compliance" on legal_acceptance_logs for insert to authenticated with check (auth.uid() = user_id);