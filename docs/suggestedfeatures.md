# Suggested Features And Supabase Playbook

This document lists strong next features for CIVIQ Africa after Phase 1.5, plus the database migration/function workflow .

## Product Direction

The app is now in a good foundation phase:

- Authentication exists.
- Legal pages exist.
- Profile setup exists.
- Local app lock exists.
- PIN and biometrics exist.
- Privacy settings exist.
- Notification settings exist.
- Data export exists.
- Account deletion has a safer request flow.

The next goal should be trust, recovery, observability, and reliability before building heavier social systems.

Avoid rushing into:

- Rankings
- Feeds
- Projects
- Social discovery
- Large chat systems

These features will create moderation, privacy, notification, and trust pressure. The current layer should become boring and reliable first.

## Missing Or Recommended Phase 1 Features

### 1. Security Event History Screen

Add a screen under:

```text
Profile -> Security -> Security Activity
```

Show user-visible security events:(Create a supabase function that will trigger each event below and sent a ping notification to the notification bell icon immediately when the folllowing actions has been made and document it)

- PIN enabled(Eg.. Hello {username},you have enabled pin....etc)
- PIN reset{Eg.. hello good({username})your password was reset}
- Biometrics enabled
- Account deletion requested
- Password reauthentication
- Data export requested
- New device/session created later

Why it matters:

Users trust apps more when sensitive events are visible.

### 2. Trusted Devices add this feature under profile,security,devices

Add a `trusted_devices` table later.

Fields could include:

- `id`
- `user_id`
- `device_label`
- `platform`
- `last_seen_at`
- `trusted_at`
- `revoked_at`

User flow:

```text
Profile -> Security -> Devices
```

Actions:

- View current device then list the current device
- View previous devices
- Revoke a device(allow users to logout the selected devices)


### 3. Session Management Screen

Add:

```text
Profile -> Security -> Active Sessions
```

Show:

- Current session
- Approximate login time
- Last active time
- Platform/device label

Actions:

- Revoke other sessions
- Revoke all sessions

This should come before serious chat/social features.

### 4. Security Notification Preference Rules

Security alerts are correctly always on.Help me define exactly which events trigger security alerts:(this events will automatically be sent to the notification icon use supabse functions he deploy then document it)

- PIN reset
- Account deletion request
- Data export request
- Password changed
- Email changed
- New device login
- Session revoked

These should also be stored in `notifications`.

### 5. Export Request History

The export system currently returns a signed link:

```text
Profile -> Export Data -> Export History
```

Show:

- Requested date
- Completed date
- Expiry date
- Status

Statuses:

- `pending`
- `completed`
- `failed`
- `expired`

### 6. Delete Account Recovery Screen

Since account deletion is a 30-day recovery request, add:

```text
Profile -> Account Status
```

If deletion is pending, show:

- Requested date
- Scheduled purge date
- Cancel deletion button

This prevents accidental permanent deletion.

### 7. Privacy Preview

Under Privacy & Visibility, add a small “Preview public profile” action.

It should show what another user would see based on:

- Public profile
- Activity visibility
- Online status
- Username discoverability

This makes privacy controls understandable.

### 8. Legal Acceptance History

Add:

```text
Profile -> Support & Legal -> Legal History
```

Show:

- Terms version accepted
- Privacy Policy version accepted
- Community Guidelines version accepted
- Accepted date

Useful for compliance and user transparency.

### 9. App Lock Grace Period Copy

The app has session timeout options.Add tiny helper text explaining what each means:

- Never: app will not locally lock
- Immediately: lock whenever app is backgrounded
- 5/10/30 minutes: lock after inactivity

Keep it short. Do not turn settings into a tutorial page.

### 10. Backup Recovery Path

Future idea:

- Recovery codes
- Device recovery confirmation
- Email verification before disabling PIN

Do not build this too early. PIN reset through full reauthentication is enough for now.

## Missing Backend Hardening

### 1. Database Functions For Sensitive Actions

Some sensitive flows are currently handled by the Flutter client plus RLS.

Later, move sensitive write chains into Postgres RPC functions or Edge Functions:

- Request account deletion
- Cancel account deletion
- Revoke sessions
- Request data export
- Insert security event

Why:

Backend functions give you one trusted execution path and fewer partial failures.

### 2. Audit Log Consistency

Normalize audit/security tables.

Recommended:

```text
security_events
```

For user-facing security history.

```text
audit_logs
```

For internal/admin traceability.

Do not mix the two too much.

### 3. Error Logging Table

Add an internal table later:

```text
app_error_logs
```

Fields:

- `id`
- `user_id`
- `area`
- `message`
- `metadata`
- `created_at`

This helps debug production issues without relying only on screenshots.

### 4. Storage Policies

You already have a private export bucket. Later, review all storage buckets:

- avatars
- exports
- report media
- future chat attachments

Each bucket should have clear policies for:

- upload
- read
- update
- delete

### 5. Rate Limits

You already rate-limit exports to one per 24 hours.

Add Rate limits for:

- PIN reset attempts
- Account deletion requests
- Notification spam
- Profile username changes
- Avatar uploads
- Report creation

## Phase 2 Readiness Checklist

Before Phase 2 social/product features, confirm:

- App lock works after real device background/resume.
- PIN reset works from lock screen and settings.
- Biometrics work on Android and iOS physical devices.
- Export returns a valid ZIP with expected JSON files.
- Account deletion request succeeds without RLS errors.
- Notification settings persist after app restart.
- Privacy settings persist after app restart.
- Security alerts cannot be disabled.
- Docs match the deployed schema.

## Supabase Mental Model

Supabase has several moving parts:

```text
Flutter app
  -> Supabase Auth
  -> Supabase Postgres
  -> Supabase Storage
  -> Supabase Edge Functions
```

The database is controlled through migrations.

Edge Functions are separate deployable backend functions.

Storage buckets may also need SQL policies.

## Supabase Files In This Project

Important paths:

```text
supabase/config.toml
```

Local Supabase project config. Includes the linked project ID.

```text
supabase/migrations/
```

Ordered SQL migration files. These define database changes.

```text
supabase/functions/
```

Edge Functions. Each function has its own folder.

Example:

```text
supabase/functions/export-user-data/index.ts
```

## Migration Naming

Migration files use timestamps:

```text
YYYYMMDDHHMMSS_short_description.sql
```

Example:

```text
20260522110000_fix_account_delete_export_rls.sql
```

Supabase applies migrations in timestamp order.

Never rename a migration after it has been pushed to remote.

Never edit an already-pushed migration to change production behavior unless you know it has not been applied anywhere important.

Safer pattern:

```text
Create a new migration that fixes the previous migration.
```

## Common Supabase Commands

### Check CLI Version

```bash
supabase --version
```

### See Linked Project

```bash
supabase status
```

or check:

```text
supabase/config.toml
```

Look for:

```text
project_id = "..."
```

### See Migration State

```bash
supabase migration list
```

This shows local and remote migration versions.

Good state:

```text
Local          | Remote
20260521130000 | 20260521130000
20260522100000 | 20260522100000
20260522110000 | 20260522110000
```

If a migration appears only under Local, it has not been pushed.

If it appears only under Remote, your local repo is missing a migration file.

### Push Local Migrations To Remote

```bash
supabase db push --include-all
```

What it does:

- Reads local files in `supabase/migrations`.
- Compares them with remote migration history.
- Applies missing migrations to the linked remote database.

What to expect:

- It may ask for confirmation.
- It prints the migration files it will apply.
- It may show notices for `if exists` or `if not exists`.

Good notices:

```text
column already exists, skipping
policy does not exist, skipping
```

Those are normal when migrations are defensive.

Bad errors:

```text
ERROR: relation does not exist
ERROR: column does not exist
ERROR: permission denied
ERROR: violates foreign key constraint
```

If you see those, stop and fix the migration.

### Pull Remote Schema

```bash
supabase db pull
```

What it does:

- Reads the current remote database schema.
- Generates a local migration representing remote changes not already captured locally.

Use this when:

- You changed something manually in Supabase Dashboard.
- Someone else changed the remote database.
- Local migrations and remote schema are out of sync.

Be careful:

`db pull` can create a large migration file. Read it before committing.

### Create A New Migration

```bash
supabase migration new migration_name_here
```

Example:

```bash
supabase migration new add_trusted_devices
```

This creates a timestamped SQL file under:

```text
supabase/migrations/
```

Then you edit that SQL file.

### Deploy Edge Function

```bash
supabase functions deploy export-user-data
```

What it does:

- Uploads the function folder.
- Deploys it to the linked Supabase project.

Function path:

```text
supabase/functions/export-user-data/index.ts
```

### List Functions

```bash
supabase functions list
```

### View Function Logs

```bash
supabase functions logs export-user-data
```

Use logs when:

- Flutter says export failed.
- The function returns 500.
- You need the exact backend error.

## Safe Workflow For You

When changing the database:

```text
1. Create a new migration.
2. Write SQL.
3. Read the SQL carefully.
4. Push it.
5. Run migration list.
6. Test the app feature.
7. Commit the migration file.
```

Commands:

```bash
supabase migration new my_change
supabase db push --include-all
supabase migration list
```

When changing an Edge Function:

```text
1. Edit function code.
2. Deploy the function.
3. Test from Flutter.
4. Check logs if it fails.
```

Commands:

```bash
supabase functions deploy export-user-data
supabase functions logs export-user-data
```

## What I Usually Check Before DB Push

Before pushing a migration, check:

- Does every table referenced actually exist?
- If a table may not exist, did I use defensive SQL?
- Does every column referenced actually exist?
- Are RLS policies needed for select/insert/update/delete?
- Are foreign keys using the correct `on delete` behavior?
- Is this migration safe to run once?
- Is this migration safe if part of the schema already exists?

Useful defensive SQL patterns:

```sql
alter table public.profiles
  add column if not exists deleted_at timestamptz;
```

```sql
drop policy if exists "Policy name" on public.notifications;
```

```sql
create index if not exists idx_notifications_user_unread
  on public.notifications (user_id, is_read, created_at desc);
```

For optional tables:

```sql
do $$
begin
  if to_regclass('public.some_table') is not null then
    -- safe SQL here
  end if;
end $$;
```

## RLS Basics

RLS means Row Level Security.

When enabled, users can only access rows allowed by policies.

Common policy pattern:

```sql
create policy "Users can read own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);
```

Meaning:

The logged-in user can select rows where `user_id` equals their Supabase Auth user ID.

Insert policy:

```sql
create policy "Users can create own notifications"
  on public.notifications for insert
  with check (auth.uid() = user_id);
```

Update policy:

```sql
create policy "Users can update own notifications"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

Delete policy:

```sql
create policy "Users can delete own row"
  on public.table_name for delete
  using (auth.uid() = user_id);
```

Security rule:

Do not add broad policies like:

```sql
using (true)
```

unless it is intentionally public data.

## Service Role Basics

The service role key bypasses RLS.

Use it only in trusted backend code:

- Edge Functions
- server-side jobs
- admin scripts

Never put service role keys in Flutter client code.

Flutter should use:

```text
SUPABASE_ANON_KEY
```

Backend functions can use:

```text
SUPABASE_SERVICE_ROLE_KEY
```

## Edge Function Expectations

An Edge Function should:

- Read the Authorization header.
- Verify the user with Supabase Auth.
- Use service role only after user verification.
- Return clear JSON errors.
- Avoid leaking secrets.

Good response:

```json
{
  "download_url": "https://..."
}
```

Good error:

```json
{
  "error": "Only one export is allowed every 24 hours."
}
```

## Current Important Migrations

```text
20260521130000_phase1_security_compliance.sql
```

Adds Phase 1 security/compliance basics.

```text
20260522100000_phase15_user_security_privacy.sql
```

Adds privacy settings, notification settings, data export requests, and export bucket metadata.

```text
20260522110000_fix_account_delete_export_rls.sql
```

Hardens account deletion, RLS, security/audit events, and cascade behavior.

## Current Important Function

```text
export-user-data
```

Path:

```text
supabase/functions/export-user-data/index.ts
```

Deploy:

```bash
supabase functions deploy export-user-data
```

Purpose:

- Verify logged-in user.
- Rate-limit exports to one per 24 hours.
- Query user data with service-role access.
- Create ZIP.
- Upload ZIP to private storage.
- Return signed URL.

## Common Mistakes To Avoid

Do not:

- Edit remote database manually and forget to pull or document it.
- Put service role key in Flutter.
- Store PIN in normal preferences.
- Disable RLS just to make an error disappear.
- Delete old migration files that have already been pushed.
- Rename pushed migrations.
- Assume docs match the real remote schema without checking.
- Add social features before privacy, notifications, and moderation are stable.

## Recommended Next Documentation Files

Later, create:

```text
docs/supabase_operations.md
```

For pure CLI operations.

```text
docs/security_event_taxonomy.md
```

For all security event names and meanings.

```text
docs/privacy_model.md
```

For exactly how privacy settings affect search, profile display, messages, activity, and future chats.

```text
docs/release_checklist.md
```

For pre-launch checks before every production release.

Lastly one request let That danger zone be a button which when clicked then so it displays the two danger zones,logout and delete account

