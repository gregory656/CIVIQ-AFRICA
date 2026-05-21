# CIVIQ Africa Phase 1 Architecture

The mobile app uses Flutter with a feature-first structure.

## Phase 1 Boundary

Treat Phase 1 as identity, security, compliance, and recovery infrastructure. Do not let these concerns collapse into one "auth" feature.

Keep the boundaries strict:

- Onboarding logic owns first-run screens, profile setup, terms checkbox state, CIVIQ code display, and notification prompt.
- Security logic owns authentication, sessions, device trust, app lock, PIN reset, audit/security events, account recovery, and destructive account actions.
- Legal compliance owns policy pages, policy versions, acceptance logs, community guidelines, dispute evidence, moderation records, and right-of-reply flows.

The UI may connect these concerns, but it should not become the source of truth for them. Supabase RLS, database records, secure storage, and future edge functions are the enforcement layer.

## Client

- Flutter UI
- Riverpod for dependency injection and state access
- GoRouter for navigation
- flutter_dotenv for public client configuration
- flutter_local_notifications for local device alerts, default notification sound, and notification permission prompts

## Backend Services

- Supabase Auth for email/password authentication and session persistence
- Supabase Postgres for profiles, notifications, legal logs, audit logs, and moderation records
- Cloudinary unsigned uploads for profile images and later report media

## Implemented Phase 1 Routes

- `/legal/privacy-policy`
- `/legal/terms`
- `/legal/community-guidelines`
- `/notifications`
- `/settings/security`

## Notification Architecture

Phase 1 now has two notification layers:

- Persistent in-app notifications are stored in Supabase `notifications`.
- Local device notifications are shown with `flutter_local_notifications` when welcome notifications are created.

The bell icon reads Supabase, shows an unread count, opens the notifications screen, and can mark all notifications read. The local device notifications use the Android default sound, provided the user grants notification permission and the device notification channel is not muted.

Remote push through FCM/APNs remains future work.

## Supabase Deployment

The project is linked to Supabase project ref:

```text
jbydwuvdxbmadyrfuljk
```

The deployed migration is:

```text
supabase/migrations/20260521130000_phase1_security_compliance.sql
```

Verified with:

```powershell
supabase migration list
```

Result:

```text
Local          | Remote
20260521130000 | 20260521130000
```

## Security Boundary

Flutter may load:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_UPLOAD_PRESET`
- `CLOUDINARY_API_KEY`

Flutter must not use:

- `SUPABASE_SERVICE_ROLE`
- `CLOUDINARY_API_SECRET`

Those backend-only values stay for future edge functions or server workflows.
