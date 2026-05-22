# Phase 1.6 Security Reliability Implementation

Date: 2026-05-22

## Deployment Result

Migration pushed successfully:

- `20260522123000_phase16_security_history_devices.sql`
- `20260522133000_notification_archive_actions.sql`

Edge Functions deployed successfully:

- `export-user-data` version `5`
- `log-security-event` version `1`

Verification commands run:

```bash
supabase migration list
supabase functions list --debug
flutter analyze --no-pub
flutter test --no-pub
```

Result:

- Local and remote migrations match through `20260522133000`.
- `export-user-data` is active.
- `log-security-event` is active.
- Flutter analyzer found no issues.
- Flutter widget test passed.

Note: Supabase CLI printed `WARNING: Docker is not running` during function deploy. The remote deploy still completed successfully.

## What I Built

### Security Activity

Added:

- `Profile -> Security -> Security Activity`
- Screen file: `lib/features/profile/presentation/screens/security_activity_screen.dart`
- Data access through `security_events`

This shows the logged-in user's security-sensitive events, newest first.

### Security Event Notifications

Added a new Edge Function:

```text
supabase/functions/log-security-event/index.ts
```

The function verifies the logged-in user, inserts a `security_events` row, and creates an unread `notifications` row with category `security`.

Events supported:

- `pin_enabled`
- `pin_reset`
- `biometrics_enabled`
- `account_deletion_requested`
- `account_deletion_cancelled`
- `password_reauthentication`
- `data_export_requested`
- `new_device_session`
- `password_changed`
- `email_changed`
- `session_revoked`

The app now calls this function after sensitive local actions so the bell icon receives an immediate unread security notification.

### Trusted Devices

Added:

- `Profile -> Security -> Devices`
- Screen file: `lib/features/profile/presentation/screens/devices_screen.dart`
- Table: `trusted_devices`

The app registers the current device, shows current and previous devices, and lets the user revoke non-current devices.

### Active Sessions

Added:

- `Profile -> Security -> Active Sessions`
- Screen file: `lib/features/profile/presentation/screens/active_sessions_screen.dart`

The screen shows active device/session records and supports:

- Revoke other sessions using Supabase Auth `SignOutScope.others`
- Revoke all sessions using Supabase Auth `SignOutScope.global`

The local `trusted_devices` rows are also marked revoked for visibility.

### Export Request History

Added export history inside:

```text
Profile -> Export Data
```

It shows:

- Requested date
- Completed date
- Expiry date
- Status

The migration adds `status` to `data_export_requests`, and `export-user-data` now updates requests to `completed` after the ZIP and signed URL are created.

### Account Status And Deletion Recovery

Added:

- `Profile -> Account Status`
- Screen file: `lib/features/profile/presentation/screens/account_status_screen.dart`

If account deletion is pending, the screen shows:

- Requested date
- Scheduled purge date
- Cancel deletion button

Cancelling clears `profiles.deleted_at` and records a security alert.

### Privacy Preview

Added a `Preview public profile` action under:

```text
Profile -> Privacy & Visibility
```

It previews how public profile, activity visibility, online status, and username discoverability affect what another user would see.

### Legal Acceptance History

Added:

- `Profile -> Legal History`
- Screen file: `lib/features/profile/presentation/screens/legal_history_screen.dart`

It reads from `legal_acceptance_logs` and shows policy type, accepted version, and accepted date.

### App Lock Grace Period Copy

Updated the security timeout row to include short helper copy:

- Never: app will not locally lock
- Immediately: locks when backgrounded
- 5/10/30 minutes: locks after inactivity

### Danger Zone Button

Changed the profile danger zone into a button. When tapped, it reveals:

- Logout
- Delete account

### Notification Sound And Actions

Added a realtime notification listener:

```text
lib/core/services/notification_realtime_listener.dart
```

When a row is inserted into `notifications` for the current user, the app now:

- Refreshes the notification list and unread count
- Reads the user's notification sound preference
- Shows a phone notification through `flutter_local_notifications`
- Plays sound unless the user selected `Silent`

Updated:

```text
lib/core/services/local_notification_service.dart
```

The app now uses separate Android notification channels for audible and silent alerts. This matters because Android notification channel sound behavior is sticky once a channel exists on a device.

Added notification long-press actions:

- Archive
- Report as spam
- Delete

Added notification read/detail view:

- Tapping a notification now marks it read and opens a full-screen detail view.
- The detail view includes the same actions as long-press: Archive, Report as spam, and Delete.
- This gives users a visible action path without requiring them to discover long-press.

Added notification archive:

- Archive button in the notifications app bar
- Restore action inside the archive

Migration:

```text
supabase/migrations/20260522133000_notification_archive_actions.sql
```

Adds:

- `notifications.archived_at`
- `notifications.deleted_at`
- `notifications.spam_reported_at`
- Indexes for active and archived notification lists

## Database Changes

Migration:

```text
supabase/migrations/20260522123000_phase16_security_history_devices.sql
```

Adds:

- `trusted_devices`
- `app_error_logs`
- `data_export_requests.status`
- Notification archive/action columns
- Indexes for trusted devices, export history, and app errors
- RLS policies for trusted devices and app error logs
- `public.create_security_alert(...)` Postgres helper function

## Important Code Paths

New repository:

```text
lib/features/profile/data/security_repository.dart
```

It centralizes:

- Security event fetching
- Trusted device registration and revocation
- Export history fetching
- Account deletion recovery fetching/cancel
- Legal history fetching

Updated router:

```text
lib/core/routes/app_router.dart
```

New routes:

- `/settings/security/activity`
- `/settings/security/devices`
- `/settings/security/sessions`
- `/settings/account-status`
- `/settings/legal-history`

## How I Deployed

I pushed the new migration:

```bash
supabase db push --include-all
```

Supabase applied:

```text
20260522123000_phase16_security_history_devices.sql
```

I deployed the functions:

```bash
supabase functions deploy export-user-data
supabase functions deploy log-security-event
```

Then I confirmed deployment:

```bash
supabase migration list
supabase functions list --debug
```

## Remaining Future Work

The backup recovery path from `suggestedfeatures.md` is intentionally still future work:

- Recovery codes
- Device recovery confirmation
- Email verification before disabling PIN

Storage policy review and broader rate limits are also still future hardening items. The current implementation focuses on the concrete Phase 1 trust, recovery, observability, and reliability features.

## 2026-05-22 Account Switch Fix

Issue found:

After logging out and signing into another account, the app could still show the previous account's notification list. The database policies were not the problem; the issue was local Riverpod state. Some user-scoped providers read `Supabase.auth.currentUser` once and could keep the previous Future result cached across logout/login.

Fix:

- Added `currentAuthUserIdProvider` in `lib/features/auth/data/auth_repository.dart`.
- Updated notification, profile, security, export-history, account-status, and legal-history providers to watch that auth user id.
- Updated the realtime notification listener to set the auth user id and invalidate all user-scoped providers on every auth state change.
- Updated login/logout flows to set or clear the auth user id immediately instead of waiting for cached providers to refresh.

Files updated:

- `lib/features/auth/data/auth_repository.dart`
- `lib/core/services/notification_realtime_listener.dart`
- `lib/features/notifications/data/notification_repository.dart`
- `lib/features/notifications/data/notification_settings_repository.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/data/security_repository.dart`
- `lib/features/home/presentation/screens/app_shell.dart`
- `lib/features/auth/presentation/screens/auth_screen.dart`
- `lib/features/profile/presentation/screens/active_sessions_screen.dart`

Delete-account red screen hardening:

- Added mounted checks between async account-deletion steps.
- Cleared user-scoped providers before sign-out/navigation after deletion request.
- This prevents the UI from trying to read or update a disposed profile screen while the account is being signed out.

Verification:

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Result:

- Analyzer: no issues found.
- Tests: all passed.

## 2026-05-22 Notification Detail And Security Confirmation UX

Notification detail update:

- Updated `lib/features/notifications/presentation/screens/notifications_screen.dart`.
- Notification tap now opens `NotificationDetailScreen`.
- The full-screen read view includes Archive, Report as spam, and Delete.
- Long-press quick actions still work.

Security confirmation update:

- Updated `lib/features/profile/presentation/screens/security_screen.dart`.
- PIN enabled, PIN disabled, PIN reset, and biometrics enabled now show a centered animated confirmation card with a green tick.
- Error messages still use normal snackbars.

Verification:

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Result:

- Analyzer: no issues found.
- Tests: all passed.

## 2026-05-22 Shared Confirmation Popup

Added:

```text
lib/core/widgets/confirmation_popup.dart
```

This gives the app one shared animated tick confirmation instead of bottom snackbars for successful actions.

Updated behavior:

- Notification Archive, Report as spam, Delete, Restore, and Mark all as read show the centered tick confirmation.
- Security confirmations reuse the same shared popup.
- Error messages still use snackbars so failures remain visually distinct from successful confirmations.

Verification:

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Result:

- Analyzer: no issues found.
- Tests: all passed.
