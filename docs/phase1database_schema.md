# Database Schema for Phase 1 Identity, Security, Compliance, and Recovery

Phase 1 should stay architecturally strict. It is not just authentication, and it should not mix security rules, onboarding steps, and legal compliance into the same feature bucket.

Use this separation:

| Category | Owns | Does not own |
| --- | --- | --- |

| Onboarding logic | First-run screens, profile setup, terms checkbox state, CIVIQ code display, notification prompt | Legal wording, enforcement rules, session/device security |
| Security logic | Authentication, sessions, device trust, app lock, PIN reset, audit/security events, account recovery | Marketing/profile copy, legal policy content |
| Legal compliance | Privacy policy, terms, community guidelines, policy acceptance logs, dispute/appeal evidence, content liability language | UI-only checkbox state, password/PIN mechanics |

## Terms And Guidelines Categorization

### Onboarding Logic

These are product flow requirements:

- Signup must show "I agree to Community Guidelines and Terms".
- Signup remains disabled until the user accepts.
- The Community Guidelines, Terms, and Privacy Policy buttons must open full readable pages before acceptance.
- Project creation later should require "I confirm this post is true to my knowledge".
- CIVIQ code display should include copy action, feedback, and later QR support.
- After onboarding, create welcome notifications in the database.

Onboarding stores user intent, but it does not define the legal text or enforce security policy by itself.

### Security Logic

These are security and recovery requirements:

- Public profile must not expose full email addresses.
- Full email belongs under Profile -> Security -> Account Information and should be masked in the UI.
- App lock is separate from account authentication.
- PIN is an app unlock credential, not an account password.
- PIN must never be stored raw; store only a strong hash.
- PIN reset must require full account reauthentication.
- Device/session records should support future trusted-device and revoke-session flows.
- Security-sensitive actions should create audit or security event records.
- Delete account should use a soft-delete/recovery period before permanent purge.

Security logic can reference legal requirements, but it should live in security services, secure storage, RLS, database functions, or edge functions, not inside onboarding widgets.

### Legal Compliance

These are compliance requirements:

- Create readable routes for:
  - `/legal/privacy-policy`
  - `/legal/terms`
  - `/legal/community-guidelines`
- Later add:
  - `/legal/data-policy`
  - `/legal/dispute-resolution`
  - `/legal/content-liability`
- Track acceptance with user, policy type, policy version, timestamp, and later device/IP evidence.
- Store community guideline enforcement records separately from profile data.
- Support right of reply, appeals, and content moderation evidence.
- Legal pages must be versioned so old acceptances remain meaningful after text changes.

Legal compliance owns the policy text and proof of acceptance. It should not be reduced to a checkbox.

## Phase 1 Table Groups

### Onboarding Tables

- `profiles`
- `counties`
- `subcounties`
- `notifications`

### Security And Recovery Tables

- `sessions`
- `audit_logs`
- `security_events`
- `account_deletion_requests`
- future `trusted_devices`
- future `recovery_codes`

### Legal And Moderation Tables

- `legal_acceptance_logs`
- `reports`
- `appeals`
- `moderation_actions`
- `blocked_users`

### Configuration Tables

- `app_settings`

## Current Tables

The following tables have been created in the DB:

```sql
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

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text unique,
  civiq_code text unique,
  phone text,
  bio text,
  avatar_url text,
  county_id int references public.counties(id),
  subcounty_id int references public.subcounties(id),
  is_verified boolean not null default false,
  is_public boolean not null default false,
  is_online boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  ip_address text,
  device_id text,
  timestamp timestamptz not null default now()
);

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id text,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  media_url text,
  status text not null default 'draft',
  created_at timestamptz not null default now()
);

create table if not exists public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid references public.profiles(id) on delete set null,
  target_user_id uuid references public.profiles(id) on delete cascade,
  action text not null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.legal_acceptance_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  policy_type text not null,
  policy_name text not null,
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  ip_address text,
  device_id text,
  user_agent text
);

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  scheduled_purge_at timestamptz not null,
  cancelled_at timestamptz,
  completed_at timestamptz,
  unique (user_id)
);
```

## Deployed Migration

The Phase 1 security/compliance migration has been deployed to the linked Supabase project:

```text
supabase/migrations/20260521130000_phase1_security_compliance.sql
```

It adds or updates:

- `legal_acceptance_logs.policy_type`
- legal acceptance evidence fields: `ip_address`, `device_id`, `user_agent`
- `account_deletion_requests`
- `profiles.deleted_at`
- RLS policies for `notifications`, `legal_acceptance_logs`, and `account_deletion_requests`
- indexes for unread notification count, legal acceptance lookup, and scheduled account purge lookup

Verified remote migration state:

```text
Local          | Remote
20260521130000 | 20260521130000
```
