# SIVIQ Africa

SIVIQ Africa is a civic accountability app for communities to report, discuss, verify, and track public projects across Kenya. It combines social discovery, evidence-based project reporting, leader rankings, direct messaging, notifications, and privacy/security controls into one civic participation platform.

The goal is simple: help citizens turn local observations into structured civic intelligence.

## What SIVIQ Does

- Lets users create civic project reports with county, sub-county, location, status, description, and evidence images.
- Supports project approvals, disapprovals, comments, replies, sharing, reporting, and moderation.
- Shows localized home feeds with `For You`, `Trending`, and `Discover` tabs.
- Provides leader rankings based on weekly SIVIQ score snapshots, project links, and community signals.
- Includes leader detail pages with associated projects and transparency metadata.
- Supports public profiles, SIVIQ codes, follow/follower discovery, direct chats, group chats, and verified badges.
- Includes notification settings, security activity, trusted devices, active sessions, app lock, PIN, biometrics, data export, legal history, and account deletion recovery flows.

## Product Vision

SIVIQ is not built to be ordinary social media. It is designed as civic infrastructure:

- Citizens report what they see.
- Communities discuss and validate evidence.
- Leaders and offices can be evaluated through public project outcomes.
- Moderators protect the platform from abuse.
- Rankings remain transparent, snapshot-based, and independent from paid influence.

## Core App Areas

### Home

The Home tab is the community discussion layer. It supports public posts, images, comments, likes, replies, sharing, reporting, and profile discovery.

### Projects

The Projects tab is the civic evidence layer. Users can submit project reports such as:

- `ongoing`
- `completed`
- `stalled`
- `excellent`

Reports can include location context, an evidence image, approval/disapproval signals, and comment discussions.

### Rankings

The Rankings tab is the civic intelligence layer. It shows leaders by role and geography using weekly score snapshots. Rankings are designed to be read as community SIVIQ sentiment analytics, not official government truth.

Supported ranking filters include:

- National
- County
- Sub-county / Constituency
- Governors
- MPs

### Chats

The Chats tab supports direct and group conversations, search, unread states, favorites, archives, delivery/read indicators, and online presence.

### Profile

Profiles include public identity, SIVIQ code, bio, location, followers/following, verification badges, privacy settings, security tools, legal records, and account controls.

## Design Identity

SIVIQ uses a clean civic palette inspired by trust, public service, clarity, and Kenyan civic context.

| Token | Hex | Use |
| --- | --- | --- |
| Primary Green | `#0B6E4F` | Main brand color, buttons, selected tabs, civic trust actions |
| Light Green | `#2E8B57` | Supporting green accents |
| White | `#FFFFFF` | App bars, cards, form surfaces |
| Black | `#121212` | Primary text |
| Danger Red | `#C1121F` | Reports, deletion, danger states, negative actions |
| Background | `#F7F9F8` | Main scaffold background |
| Grey | `#6B7280` | Secondary text and muted UI |
| Success | `#198754` | Positive project states and completion |
| Warning | `#FFB703` | Ongoing/pending attention states |
| Border | `#E5E7EB` | Card and input borders |

The UI uses Material 3, 8px border radius, compact civic cards, clear status badges, and restrained visual hierarchy. The app avoids making accountability screens feel like entertainment feeds.

## Tech Stack

- Flutter
- Dart
- Riverpod
- GoRouter
- Supabase Auth
- Supabase Postgres
- Supabase Realtime
- Supabase Edge Functions
- Cloudinary uploads
- Local notifications
- Secure storage
- Local authentication for PIN/biometrics

## Environment Setup

The app loads public client configuration from:

```text
.env.client
```

Required values:

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_UPLOAD_PRESET=
```

Do not put backend-only secrets in the Flutter app. Keep service-role keys and Cloudinary secrets server-side only.

## Running The App

Install dependencies:

```bash
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Run tests:

```bash
flutter test
```

Build Android release app bundle:

```bash
flutter build appbundle --release
```

## Supabase Structure

Important paths:

```text
supabase/migrations/
supabase/functions/
supabase/config.toml
```

Migrations define the database schema, policies, ranking functions, moderation logic, notifications, security records, profiles, projects, chats, and leader data.

Edge functions currently support backend workflows such as user data export and security logging.

## Assets

Main app assets:

```text
assets/realicon.png
assets/real_splash.png
assets/app_icon_mark.png
```

## Trust And Safety Notes

SIVIQ deals with sensitive civic speech, political accountability, local identity, and public reputation. The platform should always protect:

- user privacy
- ranking transparency
- moderation auditability
- evidence quality
- legal compliance
- clear disclaimers
- separation between paid tools and public rankings

Paid features must never buy ranking influence, report removal, or suppression of legitimate civic criticism.

## Project Status

SIVIQ Africa is under active development. Current work focuses on strengthening civic reporting, rankings, moderation, privacy, security, notifications, and scalable Supabase-backed workflows.
