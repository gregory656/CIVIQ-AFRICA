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

## Important Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Loads `.env.client`, initializes Supabase, starts the app. |
| `lib/core/config/env.dart` | Central accessors for required environment variables. |
| `lib/core/services/supabase_service.dart` | Riverpod provider for `Supabase.instance.client`. |
| `lib/features/auth/data/auth_repository.dart` | Thin wrapper around Supabase Auth. |
| `lib/features/auth/presentation/screens/auth_screen.dart` | Login/create account UI. Includes password visibility toggle. |
| `lib/features/onboarding/presentation/screens/splash_screen.dart` | App splash routing. Sends logged-in users to `/home`. |
| `lib/features/onboarding/presentation/screens/profile_setup_screen.dart` | Searchable onboarding form for profile, county, sub-county, leaders. |
| `lib/features/onboarding/presentation/screens/avatar_upload_screen.dart` | Uploads avatar to Cloudinary and saves URL in `profiles.avatar_url`. |
| `lib/features/onboarding/presentation/screens/civiq_code_screen.dart` | Shows stored CIVIQ code, generating one only if missing. |
| `lib/features/profile/data/profile_repository.dart` | Reads/writes `profiles` and exposes `currentProfileProvider`. |
| `lib/features/locations/data/location_repository.dart` | Reads `v_geographic_governance` and maps it into app models. |
| `lib/shared/models/kenya_location.dart` | County/sub-county model with governor/MP fields. |
| `docs/supabase_signup_fix.sql` | Repair script for auth/profile trigger, RLS policies, grants. |
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

County reference table. The full 47-county seed comes from the SQL you already have in the `.md` instructions file.

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

Phase 1 was verified with:

```powershell
dart analyze <touched files>
```

Result:

```text
No issues found
```

Android build:

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
- Notification delivery is in-app only; FCM/APNs is future work.
- Production signing and release icon validation still need a release build pass.
