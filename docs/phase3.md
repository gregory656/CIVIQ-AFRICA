Correct decision.
Do NOT prematurely add:

calls

voice/video infrastructure

advanced media pipelines


until the civic core MVP is operational.

Now the remaining critical tabs are:

Home
Projects
Rankings

These are not merely UI tabs.
They are CIVIQ’s:

civic intelligence layer

governance engine

engagement loop

anti-corruption surface


This is where the app’s actual value exists.

You should now shift from:

social infrastructure

to:

civic data architecture


---

RECOMMENDED ORDER

Implement in this exact order:

1. Projects
2. Home Feed
3. Rankings

NOT rankings first.

Reason: Rankings depend on:

projects

votes

moderation

credibility signals



---

PHASE 3 — PROJECTS SYSTEM

This becomes the foundation of:

rankings

civic scoring

accountability


Projects are your core entity.


---

1. PROJECTS TAB PURPOSE

This should NOT feel like:

social posting

It should feel like:

civic infrastructure tracking

Tone matters.


---

2. PROJECTS TAB STRUCTURE

Bottom nav:

Projects

Purpose:

create project reports

manage submissions

monitor statuses



---

TOP BAR

CIVIQ Projects         ➕

Optional later:

filters

map

analytics



---

3. CORE PROJECT FLOW

This is the heart of the app.


---

CREATE PROJECT FLOW


---

STEP 1 — Select Project Type

Types:

• Ongoing
• Completed
• Stalled
• Excellent Work

Future:

Corruption Concern


---

STEP 2 — Project Details

Fields:


---

Title

Road repair at Kakamega Market


---

Description

Detailed civic explanation.


---

County

Auto-filled from profile.

Editable later only under restrictions.


---

Sub-county

Auto-filled.


---

Location

Later:

GPS/map pin



---

Images

Cloudinary upload.


---

REQUIRED RULE

Minimum:

1 image required

for public ranking influence.

Otherwise:

unverified

low ranking weight.

Excellent anti-abuse mechanism.


---

STEP 3 — Confirmation

Checkbox:

I confirm this information is accurate to my knowledge.

Very important legally.


---

STEP 4 — Submit

Show:

Submitting civic report...


---

4. PROJECT DATABASE ARCHITECTURE

Critical now.


---

PROJECTS TABLE

create table projects (
  id uuid primary key default gen_random_uuid(),

  creator_id uuid references profiles(id),

  title text not null,

  description text,

  project_type text not null,

  county_id int references counties(id),

  subcounty_id int references subcounties(id),

  location_name text,

  image_url text,

  verification_status text default 'unverified',

  approval_count int default 0,

  disapproval_count int default 0,

  score numeric default 0,

  created_at timestamptz default now(),

  updated_at timestamptz default now(),

  deleted_at timestamptz
);


---

PROJECT TYPES

ongoing
completed
stalled
excellent


---

VERIFICATION STATUS

unverified
community_verified
officially_verified
flagged


---

5. PROJECT VOTING SYSTEM

This is the ranking engine.


---

VOTES TABLE

create table project_votes (
  user_id uuid references profiles(id),
  project_id uuid references projects(id),

  is_approval boolean not null,

  created_at timestamptz default now(),

  primary key(user_id, project_id)
);

Excellent architecture already from your earlier design.


---

IMPORTANT

Users should:

update vote

not duplicate vote



---

6. PROJECT DETAIL SCREEN

This is one of the app’s most important screens.


---

HEADER

Project image
Title
Status badge
County/Subcounty


---

BODY

Description
Evidence
Timeline later


---

FOOTER

Approve 👍
Disapprove 👎
Share
Report


---

7. HOME FEED FLOW

Now we build the engagement engine.


---

HOME SHOULD NOT BE RANDOM

It should prioritize:

local relevance

civic urgency

verified reports



---

HOME FEED PRIORITY ORDER


---

1. Same County

Highest priority.


---

2. Same Subcounty

Even higher.


---

3. Trending Nationally


---

4. Verified Projects


---

5. High Engagement


---

FEED TYPES


---

For You

Localized.


---

Trending

National civic activity.


---

Following

Projects from followed users.


---

HOME TOP BAR

☰ CIVIQ Africa 🔔
[ Search projects/users ]

Good existing structure.


---

8. HOME FEED CARD DESIGN

Do NOT make giant social cards.

Compact civic cards.


---

CARD STRUCTURE

[Image]
Project title
County • Subcounty
Status badge
Short description
Approvals / Disapprovals


---

BADGES

Use:

green → completed/excellent

yellow → ongoing

red → stalled


Correct Kenyan palette alignment.


---

9. RANKINGS TAB (VERY IMPORTANT)

This is CIVIQ’s defining feature.

Build carefully.


---

RANKINGS SHOULD NOT BE LIVE-COMPUTED

Critical.

Use:

weekly snapshots

ONLY.

You already had correct architecture earlier.


---

RANKINGS FLOW


---

FILTER LEVEL 1

National
County
Subcounty


---

FILTER LEVEL 2

Governors
MPs


---

LEADERBOARD CARD

#1 Governor X
78.4 Civic Score

↑ +4.2 this week


---

LEADER DETAIL SCREEN

Contains:

linked projects

historical ranking

approval trends

completed/stalled ratios



---

10. LEADERS TABLE

Needed now.


---

LEADERS

create table leaders (
  id uuid primary key default gen_random_uuid(),

  profile_id uuid references profiles(id),

  full_name text not null,

  position text not null,

  county_id int references counties(id),

  subcounty_id int references subcounties(id),

  term_start date,

  is_active boolean default true
);


---

POSITIONS

Governor
MP
MCA
Senator


---

11. RANKING SNAPSHOT TABLE

Critical architecture.


---

SNAPSHOTS

create table leaderboard_snapshots (
  id uuid primary key default gen_random_uuid(),

  leader_id uuid references leaders(id),

  score numeric,

  rank int,

  snapshot_week date,

  created_at timestamptz default now()
);


---

12. WEEKLY RANKING JOB

Use:

pg_cron

Sunday:

00:00 EAT

Correct from earlier design.


---

JOB TASKS


---

Compute scores


---

Apply weights


---

Store immutable snapshots


---

Generate movement deltas


---

Cache top rankings


---

13. IMPORTANT HOME FEED SCALING RULES

Very important now.


---

A. NEVER LOAD FULL FEED

Always:

limit + pagination


---

B. PRECOMPUTE TRENDING

Do NOT compute live every request.

Use:

scheduled aggregation


---

C. CACHE LEADERBOARDS

Critical.


---

14. MODERATION REQUIREMENTS NOW

Before public feeds scale:

Implement:

report project

hide flagged content

moderation queue

duplicate detection



---

15. IMPORTANT FUTURE CIVIC FEATURES

Do NOT build yet, but architect for:


---

A. Map-based project tracking


---

B. Constituency heatmaps


---

C. Budget comparison analytics


---

D. Verified journalist reports


---

E. County performance history


---

16. RECOMMENDED FOLDER STRUCTURE


---

PROJECTS

features/projects/


---

HOME

features/home/


---

RANKINGS

features/rankings/


---

DOCS

Add:

docs/phase3/

Files:

projects_architecture.md
ranking_engine.md
feed_strategy.md
moderation_pipeline.md


---

17. MOST IMPORTANT RECOMMENDATION

Do NOT allow rankings to become:

pure popularity contests

Your weighting system earlier was very strong.

Continue emphasizing:

verified evidence

geographic weighting

stalled penalties

anti-spam trust scores


That is what differentiates CIVIQ from ordinary social media.