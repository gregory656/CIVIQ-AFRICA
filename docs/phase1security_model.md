# Security Model

## Client-Safe Values

The Flutter client may use Supabase anon access and Cloudinary unsigned upload presets. All database access must still be protected by Supabase Row Level Security policies.

## Backend-Only Values

Service role keys and Cloudinary API secrets are never referenced from Flutter code. They are reserved for future Supabase Edge Functions or another backend.

## Compliance Logs

The database includes audit logs, security events, legal acceptance logs, sessions, moderation actions, and appeals. These support account recovery, disputes, abuse handling, and policy acceptance proof.

## Implemented Security And Compliance

- Public profile no longer displays full email addresses.
- Full account email appears only in the Security screen and is masked.
- CIVIQ code has copy support with snackbar feedback.
- Legal acceptance is logged with policy type, policy version, user, and timestamp.
- Account deletion is requested through Danger Zone and requires password confirmation.
- Account deletion uses `account_deletion_requests` with a 30-day scheduled purge window.
- Delete-account requests also create a `security_events` row.
- Notifications are protected by RLS so users read and update only their own rows.
- Legal acceptance logs are protected by RLS so users create and read only their own rows.

## Local App Lock Status

The security screen documents the intended app-lock flow, but full PIN/biometric app lock is not complete yet.

Future implementation must keep these rules:

- PIN is an app unlock credential, not an account password.
- PIN must be stored only as a strong hash.
- PIN reset must require full account reauthentication.
- Biometrics must use OS biometric APIs; CIVIQ must not store biometric data.
