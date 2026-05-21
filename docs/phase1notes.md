# CIVIQ Africa Phase 1 Notes

This document records what was built and repaired in Phase 1, why the changes were made, and how the main pieces fit together. It is meant as a future reference before adding Phase 2 features.

## Phase 1 Goal

Phase 1 focused on making the app buildable, branded, sign-up capable, and usable through the first onboarding path:

- Android debug build runs reliably on the test phone.
- Supabase Auth can create users without database trigger failures.
- New users get a profile row and CIVIQ code.
- Onboarding saves username, bio, county, sub-county, avatar URL, and CIVIQ code.
- Profile tab reads saved data back from Supabase.
- County/sub-county selection uses the governance data from Supabase.
- Sessions persist until the user explicitly logs out.
- Android launcher icon and native splash use CIVIQ assets.
- Legal policy routes are readable before acceptance.
- Signup logs legal acceptance with policy version.
- Welcome notifications are stored in Supabase and shown as local device notifications.
- Profile no longer exposes full email publicly.
- Danger Zone supports password-confirmed soft-delete requests.

## Important Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Loads `.env.client`, initializes Supabase, starts the app. |
| `lib/core/config/env.dart` | Central accessors for required environment variables. |
| `lib/core/services/supabase_service.dart` | Riverpod provider for `Supabase.instance.client`. |
| `lib/core/services/local_notification_service.dart` | Initializes local notifications and shows device alerts with sound. |
| `lib/features/auth/data/auth_repository.dart` | Thin wrapper around Supabase Auth. |
| `lib/features/auth/presentation/screens/auth_screen.dart` | Login/create account UI. Includes password visibility toggle. |
| `lib/features/auth/presentation/screens/terms_screen.dart` | Pre-signup legal agreement screen with links to real legal pages. |
| `lib/features/legal/data/legal_repository.dart` | Records policy acceptance rows for signup. |
| `lib/features/legal/presentation/screens/legal_document_screen.dart` | Displays Privacy Policy, Terms, and Community Guidelines. |
| `lib/features/notifications/data/notification_repository.dart` | Creates, reads, counts, and marks notification rows. |
| `lib/features/notifications/presentation/screens/notifications_screen.dart` | Displays database-backed notifications and mark-all-read action. |
| `lib/features/account/data/account_repository.dart` | Creates account deletion requests and security events. |
| `lib/features/profile/presentation/screens/security_screen.dart` | Shows masked account email and Phase 1 security settings. |
| `lib/features/onboarding/presentation/screens/splash_screen.dart` | App splash routing. Sends logged-in users to `/home`. |
| `lib/features/onboarding/presentation/screens/profile_setup_screen.dart` | Searchable onboarding form for profile, county, sub-county, leaders. |
| `lib/features/onboarding/presentation/screens/avatar_upload_screen.dart` | Uploads avatar to Cloudinary and saves URL in `profiles.avatar_url`. |
| `lib/features/onboarding/presentation/screens/civiq_code_screen.dart` | Shows stored CIVIQ code, generating one only if missing. |
| `lib/features/profile/data/profile_repository.dart` | Reads/writes `profiles` and exposes `currentProfileProvider`. |
| `lib/features/locations/data/location_repository.dart` | Reads `v_geographic_governance` and maps it into app models. |
| `lib/shared/models/kenya_location.dart` | County/sub-county model with governor/MP fields. |
| `docs/supabase_signup_fix.sql` | Repair script for auth/profile trigger, RLS policies, grants. |
| `supabase/migrations/20260521130000_phase1_security_compliance.sql` | Deployed migration for legal logs, account deletion requests, RLS, and indexes. |
| `android/app/src/main/res/...` | Native Android launcher icon and splash resources. |

## Constants And Assets

### Environment

The app loads runtime client config from `.env.client`.

Required:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_UPLOAD_PRESET`

Optional in the client:

- `CLOUDINARY_API_KEY`

Server-only values, such as `SUPABASE_SERVICE_ROLE` and `CLOUDINARY_API_SECRET`, should stay out of `.env.client`.

### Notification Dependency

Phase 1 uses:

```yaml
flutter_local_notifications: ^21.0.0
```

This is used for local device alerts only. Remote push delivery through FCM/APNs is future work.

### Asset Constants

Defined in `lib/core/constants/app_assets.dart`:

- `AppAssets.appIcon`
- `AppAssets.appIcon3d`
- `AppAssets.splashScreen`
- `AppAssets.splashScreen3d`

These are used in Flutter UI. Native Android launcher/splash assets are generated into `android/app/src/main/res/mipmap-*`.

### Color Constants

Defined in `lib/core/constants/app_colors.dart`:

- `primaryGreen`
- `lightGreen`
- `white`
- `black`
- `dangerRed`
- `background`
- `grey`
- `success`
- `warning`
- `border`

Use these instead of one-off colors so the app stays consistent.

## Database Entities

### `auth.users`

Managed by Supabase Auth. The app does not insert directly into this table. User creation is done through:

```dart
_client.auth.signUp(email: email, password: password)
```

### `profiles`

App-owned user profile data.

Important columns:

- `id`: UUID primary key, references `auth.users(id)`.
- `email`: copied from Supabase Auth.
- `username`: user-selected public handle.
- `civiq_code`: unique CIVIQ identity code.
- `bio`: onboarding bio.
- `avatar_url`: Cloudinary URL.
- `county_id`: selected county.
- `subcounty_id`: selected sub-county/constituency.
- `is_verified`, `is_public`, `is_online`: future state flags.

### `counties`

County reference table. The full 47-county seed comes from the SQL I already have in the `.md` instructions file.

### `subcounties`

Sub-county/constituency table. Each row belongs to one county.

### `leaders`

Governance table from the `.md` SQL. Stores governors and MPs.

Important shape:

- `role = 'Governor'`: has `county_id`, no `subcounty_id`.
- `role = 'MP'`: has both `county_id` and `subcounty_id`.

### `notifications`

In-app notification rows.

Important columns:

- `user_id`: references `profiles(id)`.
- `title`
- `body`
- `is_read`

The bell icon reads this table and shows an unread badge. The notifications screen can mark all rows read for the current user.

### `legal_acceptance_logs`

Policy acceptance proof.

Important columns:

- `user_id`: references `profiles(id)`.
- `policy_type`: `privacy_policy`, `terms`, or `community_guidelines`.
- `policy_name`: backward-compatible policy name field.
- `policy_version`: current version string, currently `2026-05-21`.
- `accepted_at`
- `ip_address`, `device_id`, `user_agent`: evidence fields for later backend capture.

### `account_deletion_requests`

Soft-delete request table.

Important columns:

- `user_id`
- `requested_at`
- `scheduled_purge_at`
- `cancelled_at`
- `completed_at`

Phase 1 creates a row here after password confirmation. Permanent purge is a later backend job.

### `v_geographic_governance`

Read model used by the app for searchable county/sub-county selection.

Expected fields:

- `county_id`
- `county_name`
- `subcounty_id`
- `subcounty_name`
- `governor_name`
- `governor_party`
- `mp_name`
- `mp_party`

The app prefers this view over local hardcoded data. If the view fails, it falls back to the small local list in `kenya_location.dart` so the UI does not crash.

## ERD

```text
auth.users
  id uuid PK
    |
    | 1:1
    v
public.profiles
  id uuid PK/FK -> auth.users.id
  county_id FK -> public.counties.id
  subcounty_id FK -> public.subcounties.id
    |
    | 1:N
    v
public.notifications
  user_id FK -> public.profiles.id

public.profiles
  id uuid PK/FK -> auth.users.id
    |
    | 1:N
    v
public.legal_acceptance_logs
  user_id FK -> public.profiles.id

public.profiles
  id uuid PK/FK -> auth.users.id
    |
    | 1:1 active request
    v
public.account_deletion_requests
  user_id FK -> public.profiles.id

public.counties
  id int PK
    |
    | 1:N
    v
public.subcounties
  id int PK
  county_id FK -> public.counties.id

public.counties
  id int PK
    |
    | 1:N
    v
public.leaders
  county_id FK -> public.counties.id
  subcounty_id FK -> public.subcounties.id nullable

public.v_geographic_governance
  read view joining:
  counties + subcounties + governor leader + mp leader
```

## Auth And Profile Flow

### Sign Up

The Flutter app now only calls Supabase Auth during sign-up. It no longer immediately double-writes the profile from the auth screen.

Reason:

Supabase Auth inserts into `auth.users`, then the database trigger creates the `profiles` row. Double-writing from Flutter during sign-up made the flow more fragile and could race with the trigger.

Database trigger:

```sql
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();
```

The trigger inserts:

- `profiles.id`
- `profiles.email`
- `profiles.civiq_code`

After signup, Flutter records legal acceptance rows for:

- `privacy_policy`
- `terms`
- `community_guidelines`

The app writes both `policy_type` and `policy_name` when the deployed migration is present. It falls back to the older `policy_name` shape if the migration is not present, so signup does not break in older databases.

### Legal Pages

Implemented routes:

- `/legal/privacy-policy`
- `/legal/terms`
- `/legal/community-guidelines`

These are readable from the terms screen and app drawer. Text is a product baseline and still needs qualified Kenyan legal review before launch.

### Profile Setup

The onboarding screen updates the existing profile row with:

- `username`
- `bio`
- `county_id`
- `subcounty_id`

The screen uses `LocationRepository.fetchGovernanceLocations()` to read counties/sub-counties/leaders from `v_geographic_governance`.

### Avatar Upload

The avatar screen uploads the selected image to Cloudinary, then saves only the returned URL in Supabase:

```dart
avatar_url = uploadedCloudinaryUrl
```

The app does not store image bytes in Supabase.

### CIVIQ Code

The code screen first reads `profiles.civiq_code`. It generates a local code only if the database row has no code.

Reason:

The database trigger should be the primary code creator. This keeps one stable unique code per user.

The profile screen also exposes a copy button for the CIVIQ code and shows `CIVIQ code copied` after copying.

### Notifications

After onboarding, the app creates two Supabase notification rows:

1. `Welcome to CIVIQ Africa.`
2. `Create your first civic project report.`

The same two messages are also shown through `flutter_local_notifications`. On Android, this uses the `CIVIQ Alerts` channel with `Importance.high`, `Priority.high`, and default sound enabled.

The user will hear sound only when:

- notification permission is granted,
- the phone is not muted or in Do Not Disturb,
- Android settings have not muted the `CIVIQ Alerts` channel.

The `POST_NOTIFICATIONS` permission is declared in `android/app/src/main/AndroidManifest.xml` for Android 13+.

### Profile Security And Danger Zone

The public profile area no longer shows the full email. Email is shown only in:

```text
Profile -> Security -> Account Information
```

The email is masked, for example:

```text
greg***@gmail.com
```

Danger Zone now contains delete account and logout. Delete account requires password confirmation, creates an `account_deletion_requests` row, writes a `security_events` row, and signs the user out.

### Session Persistence

Supabase Flutter persists sessions locally. The app splash now checks:

```dart
ref.read(authRepositoryProvider).currentSession
```

If a session exists, the user goes to `/home`. If not, they go to `/intro`.

Logout is now explicit from the Profile tab:

```dart
await ref.read(authRepositoryProvider).signOut();
```

## Riverpod Providers

### `supabaseClientProvider`

Provides the shared Supabase client.

### `authRepositoryProvider`

Wraps auth actions:

- `signUp`
- `signIn`
- `signOut`
- `currentSession`
- `currentUser`

### `profileRepositoryProvider`

Wraps profile reads/writes.

### `currentProfileProvider`

Fetches the current signed-in user's profile.

Invalidated after onboarding writes so the Profile tab refreshes:

```dart
ref.invalidate(currentProfileProvider);
```

### `governanceLocationsProvider`

Fetches counties, sub-counties, governors, and MPs from `v_geographic_governance`.

## SQL Repair Script

`docs/supabase_signup_fix.sql` exists to repair sign-up and permissions without re-seeding the whole governance dataset.

It does:

- Creates `profiles` if missing.
- Creates `notifications` if missing.
- Recreates `generate_unique_civiq_code()`.
- Recreates `handle_new_user_profile()`.
- Recreates `on_auth_user_created`.
- Enables RLS on `profiles` and `notifications`.
- Adds policies needed by the app.
- Grants read access to `counties`, `subcounties`, `leaders`, and `v_geographic_governance` where present.

It intentionally does not seed counties/sub-counties anymore. The full governance seed belongs to the `.md` SQL dataset.

Correct order:

1. Run the full governance SQL from the `.md` file.
2. Run `docs/supabase_signup_fix.sql`.
3. Test sign-up with a fresh email.

## Supabase CLI And Deployment

Supabase CLI is installed manually at:

```text
C:\SupabaseCLI
```

The default `supabase.exe` from the downloaded Windows release crashed on this machine, so the working `supabase-go.exe` binary was copied to `supabase.exe`.

Verified CLI:

```powershell
supabase --version
```

Result:

```text
2.101.0
```

Remote project linked:

```powershell
supabase link --project-ref jbydwuvdxbmadyrfuljk
```

Migration pushed:

```powershell
supabase db push
```

Verified:

```powershell
supabase migration list
```

Result:

```text
Local          | Remote
20260521130000 | 20260521130000
```

## Android Build Fixes

Gradle was hanging because `android/gradle.properties` had memory settings too large for the machine.

Changed to:

```properties
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.workers.max=2
```

Reason:

The machine has around 8 GB RAM. The old settings allowed Gradle/Kotlin to starve Windows and leave stale locks.

## Branding

### Launcher Icon

The default Flutter `ic_launcher.png` files were replaced with generated PNGs from `assets/app_icon.png`.

The generated launcher icons use softened rounded corners so the white background is not a sharp square.

Locations:

- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### Native Splash

The native Android launch background now references:

```xml
@mipmap/launch_image
```

Generated from `assets/splash_screen.png`.

Android 12+ splash resources live in:

```text
android/app/src/main/res/values-v31/styles.xml
```

## Current Verification

Current analysis was verified with:

```powershell
flutter analyze --no-pub
```

Result:

```text
No errors. Six existing style infos remain in lib/features/profile/data/profile_repository.dart about null-aware map elements.
```

Earlier Android build verification:

```powershell
cd android
.\gradlew.bat assembleDebug --no-daemon --console=plain
```

Result:

```text
BUILD SUCCESSFUL
```

## Known Follow-Ups

- The app currently depends on `v_geographic_governance` being present and readable in Supabase.
- The local `kenya_location.dart` list is only a fallback and is not the source of truth.
- Some tabs are placeholders: Home Feed, Rankings, Projects, Chats.
- Local notification sound has been added for onboarding welcome messages, but remote push delivery through FCM/APNs is future work.
- Full PIN/biometric app lock is designed in the security screen but not fully implemented yet.
- Production signing and release icon validation still need a release build pass.
