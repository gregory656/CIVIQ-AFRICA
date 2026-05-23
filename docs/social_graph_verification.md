# Social Graph And Verification

This phase separates popularity from civic trust.

## Profile Header

- The profile avatar appears first.
- The username row includes the CIVIQ verified badge when `profiles.is_verified = true`.
- The social row sits directly below the username and shows `Following | Followers`.
- Both social counts are tappable and open the full account list for that profile.
- Government identity uses both the badge and `profiles.role_label`, for example `Governor - Kakamega`.

## Verified Account Fields

`profiles` now supports:

```sql
is_verified boolean default false
verified_at timestamptz
verified_by uuid references auth.users(id)
verification_type text
role_label text
```

`is_verified` means CIVIQ reviewed the account identity. It does not mean the account is popular, official, premium, or more influential.

`role_label` is separate from the badge and should only describe an official role or public identity after review.

## Followers And Following

Followers are stored in `public.follows`:

```sql
follower_id uuid references profiles(id)
following_id uuid references profiles(id)
created_at timestamptz default now()
primary key (follower_id, following_id)
check (follower_id <> following_id)
```

Counts:

```sql
-- followers
select count(*) from follows where following_id = :profile_id;

-- following
select count(*) from follows where follower_id = :profile_id;
```

RLS allows authenticated users to read follow relationships, create follows from their own account, and remove only their own follows.

## Follow Discovery Algorithm

When a user opens their `Following` list, CIVIQ shows two layers:

- the accounts the user already follows
- a discovery section titled `Follow your fellow CIVIQ users`

The discovery section reads all CIVIQ profiles except the signed-in user, then removes accounts already followed by that user. Verified accounts sort first, then usernames sort alphabetically. Each row shows the profile avatar, `@username`, verified badge, CIVIQ code, and a deep-blue `Follow` button.

The row `Follow` button is constrained to a fixed compact width because CIVIQ's global filled-button theme is full-width for forms. Without that local constraint, profile rows can fail layout when discoverable accounts render.

## Current Following Screen Behavior

The Following screen now paints immediately before waiting on Supabase, so users do not see a blank page while data loads. It shows:

- a small loaded-state marker
- current following count
- discoverable CIVIQ user count
- already-followed accounts, if any
- discoverable CIVIQ profiles with compact blue `Follow` buttons

Each discoverable profile row includes:

- profile avatar
- `@username`
- blue verification badge when verified
- CIVIQ code
- compact deep-blue `Follow` button

When the user taps `Follow`, the app calls `public.follow_profile(target_user_id)`, refreshes the current profile counts, and refreshes the Following screen data.

## Layout Lesson

Do not place a globally themed full-width `FilledButton` directly inside `ListTile.trailing`. CIVIQ's filled buttons are full-width for form actions, which is correct in onboarding/profile forms but too large for list rows.

For row actions, wrap the button in a fixed-size box and override `minimumSize`, `padding`, and `tapTargetSize`.

Current row button rule:

```dart
SizedBox(
  width: 98,
  height: 40,
  child: FilledButton(...)
)
```

This fixed the blank/white screen that happened when discoverable accounts rendered.

## Future Search Bar

Next enhancement: add a search bar directly under `Follow your fellow CIVIQ users`.

Planned behavior:

- Search by username
- Search by CIVIQ code
- Search by role label
- Keep already-followed accounts excluded from discovery results
- Keep the same compact row button design
- Add debounce before querying Supabase once the profile graph grows

Current implementation:

```dart
rpc discover_civiq_profiles()
```

The RPC returns profiles where:

- the viewer is signed in
- the profile is not the viewer's own profile
- the viewer is not already following the profile

This is intentionally simple for the first social graph release. Later ranking can add locality, mutual follows, shared county, trusted accounts, or civic activity without changing the follow table.

The Following screen renders discovery rows as normal list items, not as a nested list. This prevents the blank/black-screen failure that can happen when a large nested profile list is built after loading.

## Follow Action And Notification

Following uses the Supabase RPC `public.follow_profile(target_user_id uuid)`.

The RPC:

- requires `auth.uid()`
- blocks self-follow
- inserts into `public.follows`
- ignores duplicate follows
- inserts a notification for the followed account only when a new follow is created

Notification example:

```text
{username} followed you
Tap to follow them back.
```

The notification stores:

```sql
category = 'social_follow'
action_route = '/profile/{follower_id}'
action_label = 'Follow back'
actor_profile_id = follower_id
```

The app opens `action_route` when the user taps the notification. That route loads the follower's profile and shows a `Follow back` button when the signed-in user is not already following them.

This RPC exists because normal RLS correctly prevents users from inserting notifications into another user's inbox directly.

## Username Rules

Usernames are limited to:

- ASCII letters
- numbers
- underscores
- 3 to 30 characters

Emoji and reserved civic names are blocked in Flutter and guarded in Postgres for new rows. Reserved examples include `admin`, `civiq`, `support`, `governor`, `president`, `mp`, `mca`, `government`, and `police`.

## Verification Requests

`public.verification_requests` stores requests for future admin review:

```sql
requested_role text
proof_document_url text
status text default 'pending'
reviewed_by uuid references auth.users(id)
reviewed_at timestamptz
```

Only users can create their own requests. Admins review and update requests.

## Security Rule

Frontend clients must never set verification fields. The migration adds a database trigger that blocks normal users from changing:

- `is_verified`
- `verified_at`
- `verified_by`
- `verification_type`
- `role_label`

For the current visual preview, the migration marks existing accounts as verified with `verification_type = 'preview'`. Future premium or official badge workflows should replace that preview value through an admin-only path.
