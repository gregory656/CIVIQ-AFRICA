# Onboarding Flow

1. Splash screen
2. Intro slides
3. Terms agreement
4. Signup or login
5. Profile setup
6. Profile picture upload
7. CIVIQ code display
8. Notification prompt
9. Home feed shell

Notification permission is requested after onboarding, not at launch.

## Terms Agreement

The terms agreement screen must open readable pages before acceptance:

- `/legal/privacy-policy`
- `/legal/terms`
- `/legal/community-guidelines`

Signup is disabled until the user accepts the legal checkbox. After account creation, the app records acceptance rows in `legal_acceptance_logs` for:

- `privacy_policy`
- `terms`
- `community_guidelines`

The current policy version is `2026-05-21`.

## Welcome Notifications

Phase 1 creates two welcome notifications after onboarding:

1. `Welcome to CIVIQ Africa.`
2. `Create your first civic project report.`

Each welcome notification is written to Supabase `notifications` so it appears in the bell screen. The app also fires matching local device notifications through `flutter_local_notifications`, using the default Android notification sound.

Sound depends on:

- the user granting notification permission,
- the phone not being muted or in Do Not Disturb,
- the `CIVIQ Alerts` notification channel not being muted in Android settings.

Remote push notifications are not part of Phase 1. They come later through FCM/APNs.
