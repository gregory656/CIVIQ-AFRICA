# SIVIQ Backend Handbook

This is a practical guide to how SIVIQ works behind the Flutter screens. Read it as a map of the app: what lives on the phone, what lives in Supabase, how requests move between them, and where to change each part safely.

## 1. The Big Picture

```text
Flutter screen
  -> Riverpod provider (loading/data/error state)
  -> repository (feature data operations)
  -> Supabase client / Cloudinary client
  -> Supabase Auth, PostgREST API, PostgreSQL, Realtime, or Edge Function
```

SIVIQ is a Flutter client with a Supabase backend. Flutter owns the UI. Supabase owns accounts, database records, database rules, scheduled ranking jobs, realtime updates, and Edge Functions. Cloudinary stores uploaded images.

The client never needs the database password or Supabase service-role key. It uses a public `anon` key and is limited by database Row Level Security (RLS) rules.

## 2. Important Folders

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Starts Flutter, loads `.env.client`, initializes Supabase and local notifications. |
| `lib/core/services/supabase_service.dart` | Exposes the one shared `SupabaseClient`. |
| `lib/features/*/data/` | Repositories and Riverpod providers for each feature. |
| `lib/features/*/presentation/` | Screens and widgets; these should ask repositories for data rather than write raw database logic. |
| `supabase/migrations/` | Ordered SQL history that defines and evolves PostgreSQL. |
| `supabase/functions/` | Supabase Edge Functions (server-side TypeScript). |
| `supabase/config.toml` | Local Supabase CLI configuration and linked project ID. |
| `.env.client` | Safe mobile-app configuration: URL, anon key, Cloudinary public upload settings. |
| `.env` | Development-only backend secrets. Never bundle or commit service-role/API-secret values. |

## 3. Startup and Configuration

`lib/main.dart` runs in this order:

1. `WidgetsFlutterBinding.ensureInitialized()` prepares Flutter plugins.
2. `dotenv.load(fileName: '.env.client')` reads the client configuration.
3. `Supabase.initialize(...)` creates the Auth/database client.
4. `LocalNotificationService.initialize()` configures notifications on the device.
5. `runApp(const ProviderScope(...))` starts the app and Riverpod state container.

`lib/core/config/env.dart` validates required configuration. A missing value throws early instead of silently pointing production traffic to the wrong backend.

Client values:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<public-anon-key>
CLOUDINARY_CLOUD_NAME=<cloud-name>
CLOUDINARY_UPLOAD_PRESET=<unsigned-upload-preset>
```

Never put these in `.env.client`:

- `SUPABASE_SERVICE_ROLE`
- database password
- Cloudinary API secret
- Firebase server credentials

Those keys bypass protections or allow destructive operations.

## 4. Supabase Services Used

### Auth

Auth provides email/password signup, login, sessions, refresh tokens, and the current user.

The code lives in `lib/features/auth/data/auth_repository.dart`.

```dart
client.auth.signUp(email: email, password: password);
client.auth.signInWithPassword(email: email, password: password);
client.auth.currentUser;
client.auth.currentSession;
```

After a successful signup/login, Supabase gives Flutter a session. The app stores it through `supabase_flutter`; requests automatically carry that session's JWT. PostgreSQL reads its owner with `auth.uid()`.

Sign-out calls `auth.signOut()`. The app also attempts to mark chat presence offline first, but sign-out is not blocked if that best-effort request fails.

### PostgreSQL Database

PostgreSQL stores the app's persistent data: profiles, locations, leaders, projects, posts, conversations, notifications, security records, and more.

Database access from Flutter normally uses PostgREST query builders:

```dart
client.from('profiles').select();
client.from('profiles').update({'bio': '...'}).eq('id', userId);
client.from('projects').insert(payload);
client.from('notifications').delete().eq('id', notificationId);
```

### PostgREST REST API

Supabase automatically exposes PostgreSQL tables, views, and functions through REST.

```text
https://<project-ref>.supabase.co/rest/v1/<table-or-view>
https://<project-ref>.supabase.co/rest/v1/rpc/<function-name>
```

Flutter's `.from()` calls use this API under the hood; the app does not need to hand-build HTTP URLs for normal database work.

Examples:

| Flutter query | REST resource | Meaning |
| --- | --- | --- |
| `.from('counties').select()` | `/rest/v1/counties` | Read counties. |
| `.from('v_geographic_governance').select()` | `/rest/v1/v_geographic_governance` | Read county, constituency, Governor, and MP data together. |
| `.from('v_latest_leaderboard').select()` | `/rest/v1/v_latest_leaderboard` | Read latest weekly rankings. |
| `.rpc('discover_civiq_profiles')` | `/rest/v1/rpc/discover_civiq_profiles` | Call a database function. |

A `404` from PostgREST normally means a wrong table/view/function name, a schema cache not refreshed after a migration, an API schema configuration issue, or a request targeting the wrong project URL. A `401` usually means no valid session; a `403` usually means RLS denied access; a `409` commonly means a duplicate/unique-constraint conflict; and a `23503` or `23514` PostgreSQL code means a foreign-key/check constraint failed.

### Row Level Security (RLS)

RLS is the most important backend security layer. It is enabled per table, then policies decide which rows a signed-in user can read or change.

Typical policy pattern:

```sql
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
```

In plain language: an authenticated user may update only the profile whose `id` matches their logged-in Auth user ID.

Important SIVIQ examples:

- Users own their profiles and privacy preferences.
- Project/social-post authors own their own content.
- Conversation participants can read/send only in their conversations.
- Public directory/feed views expose only safe data.
- Ranking snapshot writes remain server-side; mobile users can only read them.

Do not fix an RLS failure by disabling RLS or putting the service-role key in Flutter. Add a minimal, explicit policy or server-side function instead.

### Realtime

Supabase Realtime is used for live notification behavior through `lib/core/services/notification_realtime_listener.dart`. Realtime listens for allowed database changes and invalidates/refetches local state so the UI updates.

Realtime does not replace RLS: subscriptions are also constrained by the user's permissions.

### Edge Functions

Edge Functions are Deno/TypeScript server endpoints under `supabase/functions/`.

| Function | Purpose |
| --- | --- |
| `export-user-data` | Builds/returns a user's data export workflow. |
| `log-security-event` | Records security-sensitive events without trusting a client-side direct write. |

Use an Edge Function when an operation needs a secret, privileged work, third-party API access, complex validation, or an audit trail that must not be client-controlled.

### Scheduled Jobs

`20260527100000_phase4_rankings_engine.sql` configures PostgreSQL `pg_cron` to run `public.execute_weekly_rankings_snapshot()` weekly.

The function calculates scores from leader-project links, project states, and community votes, then writes `leaderboard_snapshots`. The `v_latest_leaderboard` view exposes the newest snapshot.

Directory data is separate from scores:

- `leaders`, `counties`, and `subcounties` are the source directory.
- `leaderboard_snapshots` is historical weekly scoring data.
- A missing snapshot should not erase leaders from the app; `RankingsRepository` merges directory and snapshot data.

### Cloudinary

`lib/core/services/cloudinary_service.dart` uploads profile, social-post, and project images. The upload uses an unsigned preset, checks a 6 MB client limit, then returns a `secure_url`. The URL is transformed with `f_auto,q_auto` so Cloudinary selects a suitable format and quality when clients load it.

Cloudinary holds image bytes; Supabase tables store the returned URL.

## 5. Core Data Model

This is a conceptual map, not every column.

```text
auth.users
  └─ profiles (one app profile per Auth user)
       ├─ counties ─┬─ subcounties
       │            └─ leaders (Governor / MP)
       ├─ projects ── project_votes / project_comments / leader_projects
       ├─ social_posts ── likes / comments / reports
       ├─ follows
       ├─ notifications / notification_settings
       ├─ conversations ── messages / participants
       ├─ user_interests ── interests
       └─ security, device, legal, and export records
```

### Geography and leaders

- `counties`: 47 Kenyan counties.
- `subcounties`: 290 constituencies linked to a county.
- `leaders`: seeded Governors and MPs.
- `v_geographic_governance`: read-optimized view combining all four.
- `leaderboard_snapshots`: weekly ranking result rows.

Profile location must be a valid county/constituency pair. The trigger `validate_profile_governance_location()` protects that invariant. It uses `SECURITY DEFINER` so it can read the official location tables even when the signed-in user cannot read every row directly.

### Civic content

- `projects`: structured public-project reports.
- `project_votes`: approval/disapproval signals.
- `project_comments`, likes, reports: discussion and moderation.
- `leader_projects`: connects a report to the relevant public leader.
- `social_posts`, comments, likes, reports: community feed content.

### Identity and safety

- `profiles`: public app identity, username, bio, photo, location, privacy fields.
- `follows`: social graph.
- `legal_acceptance_logs`: accepted legal documents/version history.
- `security_events`, trusted devices, sessions: security history.
- deletion/export tables: privacy controls and account recovery/deletion workflows.

## 6. Repository Pattern

Every feature keeps server interaction in a repository. Screens should not contain raw Supabase queries unless there is a compelling local-only reason.

| Repository | Main responsibility |
| --- | --- |
| `AuthRepository` | Signup, login, logout, current session/user. |
| `ProfileRepository` | Profiles, follow graph, visibility, profile updates. |
| `LocationRepository` | County/constituency directory and safe local fallback. |
| `ProjectRepository` | Project feeds, creation, votes, comments. |
| `SocialPostRepository` | Posts, feed, likes, comments, search. |
| `RankingsRepository` | Leader directory, weekly snapshots, leader projects. |
| `ChatRepository` | Conversations, messages, group members, read/delivery state. |
| `NotificationRepository` | Notifications and unread counts. |
| `SecurityRepository` | Devices, sessions, exports, legal/security history. |
| `MonetizationRepository` | Interests, search history, ads/trends. |

This separation makes it easier to test, replace APIs, and keep UI error messages friendly.

## 7. Riverpod State: How the UI Knows What to Show

Riverpod providers are scoped state objects. The app starts with `ProviderScope` in `main.dart`; widgets use `ref.watch(...)` to react to state or `ref.read(...)` for one-off commands.

### Provider types used here

| Type | Use in SIVIQ | Example |
| --- | --- | --- |
| `Provider<T>` | Creates a stable service/repository. | `supabaseClientProvider`, `profileRepositoryProvider` |
| `FutureProvider<T>` | Loads asynchronous data and gives `loading`, `data`, or `error`. | `currentProfileProvider`, `projectsProvider`, `rankingsProvider` |
| `FutureProvider.family<T, Arg>` | Loads data for one supplied ID. | `publicProfileProvider(userId)`, `leaderProjectsProvider(leaderId)` |
| `StateProvider<T>` | Holds small mutable UI state. | `currentAuthUserIdProvider`, `rankingFilterProvider` |
| `ChangeNotifierProvider<T>` | Wraps a mutable service that notifies listeners. | `appLockServiceProvider` |

Example:

```dart
final currentProfileProvider = FutureProvider<CiviqProfile?>((ref) async {
  final userId = ref.watch(currentAuthUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});
```

The UI uses:

```dart
profile.when(
  loading: () => const CircularProgressIndicator(),
  error: (error, _) => Text('Could not load your profile.'),
  data: (profile) => ProfileView(profile: profile),
);
```

After a write, call `ref.invalidate(provider)` to fetch fresh data. Example: after changing a profile, invalidate `currentProfileProvider`; after posting, invalidate the feed provider.

## 8. Sessions, Local Security, and Routing

There are two different concepts:

1. **Supabase session:** proves who the user is to the backend. It contains a JWT and refresh behavior managed by `supabase_flutter`.
2. **App lock:** local PIN/biometric protection managed by `AppLockGate`, `PinService`, `BiometricService`, and secure storage. It does not replace the Supabase session.

At startup, `appRouterProvider` checks `auth.currentSession`:

- no session → `/intro`
- session exists → `/home`

Restricted profiles route to account-status handling. GoRouter owns app navigation; route definitions are in `lib/core/routes/app_router.dart`.

## 9. Migrations: The Database's Source Code

Every schema/data change belongs in a new timestamped `.sql` file in `supabase/migrations/`.

Good migration rules:

1. Never edit an already-applied production migration to change history.
2. Create a later migration for the correction.
3. Make repeatable seed commands idempotent with `on conflict do nothing`.
4. Enable RLS and add explicit policies for new user-facing tables.
5. Test a migration on a non-production project first when possible.

Recent recovery migrations:

| Migration | Purpose |
| --- | --- |
| `20260912100000_restore_leaderboard_snapshots.sql` | Rebuilds latest ranking snapshot and validates geography pairs. |
| `20260912110000_allow_multiple_profiles_per_subcounty.sql` | Removes incorrect one-profile-per-constituency uniqueness. |
| `20260912120000_fix_profile_location_trigger_rls.sql` | Lets validation safely read official geography under RLS. |
| `20260912130000_restore_interest_seed.sql` | Restores the standard interest list. |

Useful commands:

```powershell
supabase login
supabase link --project-ref <project-ref>
supabase db push
supabase migration list
```

If CLI access has no database privilege, use the Supabase Dashboard SQL Editor with care. Do not paste service-role keys into source files or screenshots.

## 10. Error Handling and Offline Behavior

`lib/core/utils/friendly_error.dart` maps technical failures to user-safe messages.

The normal pattern is:

```dart
try {
  await repository.saveSomething();
} catch (error) {
  setState(() {
    message = friendlyErrorMessage(
      error,
      fallback: 'We could not save that. Please try again.',
    );
  });
}
```

Network exceptions map to:

> Seems you're offline. Check your connection and try again.

Never render `error.toString()` to users. It can expose PostgreSQL constraints, endpoint names, or internal implementation details. Log diagnostic detail privately/server-side when needed, but display a clear action a human can understand.

## 11. Practical Debugging Checklist

When a screen is empty or an action fails, diagnose in this order:

1. Confirm device internet connection and current Supabase URL in `.env.client`.
2. Confirm the user has a valid session: `Supabase.instance.client.auth.currentUser`.
3. Check the table/view exists in Supabase Dashboard → Table Editor or SQL Editor.
4. Check RLS policies for the signed-in role, not only for `service_role`.
5. Check whether the required migration is applied.
6. Check invalid foreign keys, especially county/subcounty combinations.
7. Check provider cache: after a successful change, invalidate the relevant provider or hot restart.
8. Check Edge Function logs for server-side workflows.

Safe test strategy:

- Test with a normal authenticated test account, not only the service role.
- Verify RLS with an account that does not own the row.
- Test offline mode for post/project/profile writes.
- Test all new migrations on a development project before production.

## 12. Release Checklist

Before a Play Store release:

1. Apply and verify migrations.
2. Confirm interest, county, subcounty, and leader seed counts.
3. Create/login with a normal account and complete onboarding.
4. Create a social post and project report while online and offline.
5. Open Rankings without relying on a weekly snapshot.
6. Run `flutter analyze`, `flutter test`, and a release build.
7. Verify `.env.client` has only public values; check Git status for accidental `.env` changes.
8. Increment `version:` in `pubspec.yaml`.
9. Build the Android bundle:

```powershell
flutter build appbundle --release
```

The output is normally:

```text
build/app/outputs/bundle/release/app-release.aab
```

## 13. Key Mental Model

Think of SIVIQ's backend as five cooperating layers:

```text
Flutter UI       -> pages, forms, cards, buttons
Riverpod         -> loading/data/error state and refreshes
Repositories     -> app-specific data methods
Supabase API     -> Auth, REST, Realtime, Functions
PostgreSQL + RLS -> permanent data, rules, automation, rankings
```

When adding a feature, work from bottom to top:

1. design the table/view/function and RLS migration;
2. add repository methods and models;
3. add providers for UI state;
4. build the screen/widget;
5. add friendly errors, offline behavior, and tests.

That order prevents a beautiful screen from depending on an insecure or incomplete backend.
