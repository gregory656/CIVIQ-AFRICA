# Phase 1.5 User Security And Privacy Infrastructure

Phase 1.5 hardens CIVIQ Africa before larger social surfaces are expanded. Rankings, feeds, projects, and social systems should stay secondary until local security, privacy controls, session management, export, and notification persistence are stable.

## Implemented Scope

### Security Order

Implemented in the required dependency order:

1. Session timeout
2. 4-digit app PIN
3. Biometrics
4. PIN reset flow
5. Notification persistence/settings
6. Visibility/privacy controls
7. Export data
8. Read receipts / online visibility settings

### Core Security Structure

Flutter security code is centralized under:

```text
lib/core/security/
├── app_lock_gate.dart
├── app_lock_service.dart
├── biometric_service.dart
├── pin_service.dart
├── secure_storage_service.dart
└── session_service.dart
```

### Secure Storage Keys

Stored only in `flutter_secure_storage`:

- `session_timeout_minutes`
- `last_active_timestamp`
- `app_lock_enabled`
- `hashed_pin`
- `pin_salt`
- `biometric_enabled`

No PIN or lock credential is stored in `SharedPreferences`.

### Session Timeout

Profile -> Security -> Session Timeout supports:

- Never
- Immediately
- 5 Minutes
- 10 Minutes
- 30 Minutes

The global `AppLockGate` observes app lifecycle transitions. On pause, inactive, or hidden, it stores `last_active_timestamp`. On resume, it compares the elapsed time against the secure timeout setting and shows the lock screen when required.

### PIN System

The PIN is a local app unlock credential. It does not replace Supabase authentication.

Rules:

- Must be exactly 4 numeric digits.
- Rejects repetitive PINs like `1111`, `0000`, and `2222`.
- Rejects sequential PINs like `1234` and descending sequences.
- Stores only a salted SHA-256 hash and salt in secure storage.
- PIN entry uses a custom on-screen numeric keypad with four animated indicator dots. It does not focus a text field or open the system keyboard.

### Biometrics

Biometrics use OS authentication through `local_auth`. Biometrics can only be enabled after a PIN exists, because PIN is the fallback unlock path.

Platform setup:

- Android uses `FlutterFragmentActivity`.
- Android manifest includes `USE_BIOMETRIC`.
- iOS `Info.plist` includes `NSFaceIDUsageDescription`.

### PIN Reset

PIN reset is available from Profile -> Security and from the lock screen.

Flow:

1. User taps Forgot PIN or PIN reset.
2. User reauthenticates with Supabase email/password.
3. Old local PIN is deleted.
4. Biometrics are disabled.
5. User sets a new PIN.
6. A security notification is inserted:

```text
Your security PIN was reset successfully.
If this was not you, secure your account immediately.
```

### Privacy & Visibility

Profile -> Privacy & Visibility persists:

- Public Profile
- Show Online Status
- Show Read Receipts
- Allow message requests via CIVIQ code
- Show civic engagement publicly

Launch defaults favor privacy:

- `is_public`: false
- `show_activity`: false

### Notification Settings

Profile -> Notifications persists:

- Push notifications master switch
- Notification sound: default, soft, alert, silent
- Messages
- Project updates
- Moderation alerts
- Rankings
- Security alerts

Security alerts are always enabled and enforced by both UI and database constraint.

### Export Data

Profile -> Export Data calls the Supabase Edge Function:

```text
export-user-data
```

The function:

- Authenticates the Supabase user.
- Enforces one export per 24 hours.
- Builds a ZIP archive with:
  - `profile.json`
  - `notifications.json`
  - `posts.json`
- Uploads it to the private `user-exports` storage bucket.
- Returns a one-hour signed download URL.

## Database Migration

Migration:

```text
supabase/migrations/20260522100000_phase15_user_security_privacy.sql
```

Follow-up hardening migration:

```text
supabase/migrations/20260522110000_fix_account_delete_export_rls.sql
```

Adds:

- Privacy columns on `profiles`
- `notifications.category`
- `notification_settings`
- `data_export_requests`
- Private `user-exports` storage bucket metadata
- RLS policies for user-scoped notification settings and export request reads
- RLS policies for user-owned `security_events`, `audit_logs`, and session tables when present
- Cascading deletes from `profiles` into `audit_logs` and `security_events`
- Defensive handling for deployments that use `user_sessions` instead of `sessions`

## Routes

Added:

- `/settings/security`
- `/settings/privacy`
- `/settings/notifications`
- `/settings/export`

## Guardrails

Still intentionally deferred:

- Custom encryption
- End-to-end encryption
- Advanced device fingerprinting
- AI moderation
- WebRTC
- Hidden chats
- Larger social mechanics

These should wait until Phase 1.5 has been tested on real devices.
