# SIVIQ Play Store Launch Audit

This document converts the production-readiness checklist into a practical status board for SIVIQ. Brand note: use `SIVIQ` in public copy, not `CIVIQ`.

Status key:

- `[x] Solid enough for MVP`
- `[~] Partially done / needs hardening`
- `[ ] Not done yet`

## What Was Fixed In This Pass

- [x] Splash asset now uses `assets/real_splash.png`.
- [x] Stale Flutter asset state was cleaned with `flutter clean` and `flutter pub get`.
- [x] Old `assets/splash_screen.png` is no longer referenced.
- [x] Removed Android legacy external storage request.
- [x] Enabled release `minifyEnabled` and `shrinkResources`.
- [x] Added upload max-size guard at 6 MB.
- [x] Reduced picked image dimensions/quality for posts, projects, avatars, and group photos.
- [x] Made social post reports and project reports idempotent with `upsert`.
- [x] Changed unread notification count to use database count instead of fetching all IDs.
- [x] Replaced the default Android package `com.example.civiqafrica` with `com.siviq.africa`.

## Play Console Setup

- [ ] Google Play Developer account
- [ ] Organization account
- [ ] Final legal/developer contact details

Notes:

- Use `SIVIQ` as the app name.
- The Android package is now `com.siviq.africa`.

## Legal Pages

- [~] Privacy Policy exists in-app
- [~] Terms of Service exists in-app
- [~] Community Guidelines exists in-app
- [~] FAQ, About, Appeals, and Contact exist in-app
- [ ] Public hosted Privacy Policy URL
- [ ] Public hosted Terms URL
- [ ] Public hosted Community Guidelines URL

Fix:

- Host these pages publicly on GitHub Pages, Vercel, Netlify, or a future SIVIQ domain.
- Play Store requires a public Privacy Policy URL.

## Data Protection

- [x] Delete account flow exists
- [~] Export data flow exists, but needs production hardening
- [x] Consent checkbox exists
- [~] Privacy text explains data collection
- [ ] Full production data retention policy
- [ ] Moderation appeal tracking backend

Fix:

- Make export more complete and less memory-heavy.
- Explain uploaded images, notifications, location/county data, device identifiers, and security logs in the hosted Privacy Policy.

## Android Permissions

- [x] Internet available by Flutter/network use
- [x] Android 13 notification permission declared
- [x] Biometric permission declared
- [x] No contacts permission
- [x] No microphone permission
- [x] No call permission
- [x] Legacy storage request removed
- [~] Gallery saving/upload permissions should be tested on Android 10, 11, 12, 13, and 14

Current manifest:

- `POST_NOTIFICATIONS`
- `USE_BIOMETRIC`

Fix:

- Do not add camera permission unless camera capture is actually enabled.
- Keep media/gallery access through Android scoped storage and plugins.

## Firebase

- [ ] Crashlytics
- [ ] Analytics
- [ ] FCM push notifications

Fix:

- Add Firebase after current launch blockers are stable.
- Crashlytics is the most urgent Firebase item.

## Environment Variables

- [x] `.env` and `.env.client` are gitignored
- [~] `.env.client` still ships client config
- [ ] Separate development and production Supabase projects documented
- [ ] Remove unused `CLOUDINARY_API_KEY` from client env

Fix:

- Keep only public client values in Flutter.
- Move signing/upload secrets to Supabase Edge Functions.

## Security Hardening

- [~] RLS exists across many tables
- [~] Views need explicit `security_invoker`/RLS audit
- [~] Cloudinary upload has client size checks now
- [ ] Signed Cloudinary uploads
- [~] Chat has rate limiting
- [ ] Social post/comment/report/follow/vote rate limiting
- [~] Admin role helpers exist
- [ ] Full admin/moderator dashboard
- [x] No service-role key in Flutter app

Fix:

- Prioritize signed uploads, rate limits, and view/RLS audit before public promotion.

## App Signing

- [ ] Release keystore
- [ ] `key.properties`
- [ ] Release signing config
- [ ] Encrypted backup of keystore/passwords

Current risk:

- Release build still signs with debug config.

Fix:

- Generate release keystore before uploading to Play Console.
- Never lose the keystore.

## Android Release Optimization

- [x] `minifyEnabled true`
- [x] `shrinkResources true`
- [ ] Release signing
- [ ] Release app bundle tested

Command:

```bash
flutter build appbundle --release
```

## Performance

- [~] Splash/startup is simple
- [~] Home feed has paging
- [~] Image compression improved
- [ ] Full low-end Android performance test
- [ ] Memory leak testing
- [ ] Chat open under 1 second test

Fix:

- Test on low-end Android phones and unstable networks.
- Replace offset pagination with keyset pagination.

## Offline Strategy

- [~] Friendly offline message exists in some important places
- [ ] Offline cache for profile
- [ ] Offline cache for recent chats
- [ ] Offline cache for feed thumbnails

Fix:

- Apply friendly errors app-wide first.
- Add local cache later with Hive, Isar, or Drift.

## Notifications

- [x] Local notifications exist
- [~] Foreground notification flow exists
- [ ] Background push through FCM
- [ ] Notification tap routing fully verified
- [ ] Grouped chat notifications

Fix:

- Add FCM when moving beyond MVP.
- Test notification taps on Android 13 and 14.

## Moderation

- [x] Report project
- [x] Report post
- [~] Hide post
- [~] Block post copy locally/per-user
- [~] Report comments
- [ ] Report user
- [ ] Block user from profile surface
- [ ] Admin moderation dashboard

Fix:

- Add report user and block user buttons on profile screens.
- Build moderation queue before major promotion.

## Play Store Assets

- [~] App icon exists
- [~] Splash exists
- [ ] 512x512 Play Store icon verified
- [ ] Feature graphic 1024x500
- [ ] Phone screenshots
- [ ] Short description
- [ ] Full description
- [ ] Privacy Policy URL

Fix:

- Prepare Play Store listing assets after app UI is stable.

## App Content Risk

- [~] Legal copy says SIVIQ is independent
- [~] Rankings disclaimer exists
- [ ] Final Play Store description reviewed for political sensitivity

Safe framing:

```text
SIVIQ is an independent civic transparency and community reporting platform.
```

Avoid:

- Political attack wording
- Election manipulation framing
- Claims that rankings are official truth

## Testing Checklist

- [ ] Account recovery
- [ ] PIN reset
- [ ] Biometrics failure
- [ ] Group creation
- [ ] Realtime reconnect
- [ ] Message delivery states
- [ ] Rankings calculations
- [ ] Delete account
- [ ] Export data
- [ ] Blocking/reporting
- [ ] Low-end Android
- [ ] Unstable mobile network

## Production Database

- [~] Indexes exist for many MVP paths
- [~] `pg_cron` ranking job exists
- [ ] Backup/PITR decision
- [ ] Slow query review
- [ ] View/RLS audit
- [ ] Search indexes for global search
- [ ] Rate-limit tables/functions

## Deployment Reality

- [x] No Render/Vercel backend needed right now
- [x] Supabase + Cloudinary is enough for MVP backend
- [ ] Hosted legal pages still needed

## Post-Launch Monitoring

- [ ] Crashlytics
- [ ] Supabase slow query monitoring
- [ ] Supabase Realtime reports
- [ ] Cloudinary upload/bandwidth alerts
- [ ] Spam/moderation queue metrics
- [ ] Signup failure tracking

## Final Readiness

Solid for controlled testing:

- Authentication
- Onboarding
- Basic chats/groups
- Projects
- Rankings snapshots
- Notifications basics
- Delete account
- Security PIN/biometrics
- Core RLS foundations

Needs work before public promotion:

- Release signing
- Hosted legal URLs
- Signed media uploads
- App-wide friendly errors
- Rate limiting outside chat
- View/RLS audit
- Pagination across all historical lists
- FCM/Crashlytics
- Moderation dashboard

Recommended next move:

- Run closed testing with 20 to 50 trusted users before public launch.
- Include low-end Android phones, unstable internet, and users from different counties.
