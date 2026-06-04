# SIVIQ Africa Website Build Prompt

Use this prompt in the React website project. Do not edit the Flutter app from that project. Build the public company/Play Store support website for SIVIQ Africa using the extracted app information below.

## Role

You are building the official public website for **SIVIQ Africa** / **SIVIQ**.

Create a modern, responsive, professional React + TypeScript website for SIVIQ Africa. The website must support Play Store launch requirements by hosting public legal, privacy, terms, data safety, support, contact, and deletion information.

Build production-ready code, not mock-only screens.

## Extracted App Information

### App Name

Public name: **SIVIQ**

Company/product name: **SIVIQ Africa**

Android package: `com.siviq.africa`

### App Description

SIVIQ Africa is a civic accountability app for communities to report, discuss, verify, and track public projects across Kenya. It combines social discovery, evidence-based project reporting, leader rankings, direct messaging, notifications, and privacy/security controls into one civic participation platform.

The goal is simple: help citizens turn local observations into structured civic intelligence.

### Tagline

Use this tagline prominently:

```text
Building better community together
```

### Mission

Increase transparency, accountability, and civic engagement across Africa by helping citizens document public projects, discuss community issues, and participate responsibly in governance.

### Vision

A digitally empowered Africa where citizens actively participate in development and governance.

### Independence Disclaimer

SIVIQ is independent and is not affiliated with, endorsed by, or approved by the Government of Kenya, county governments, elected officials, public agencies, or any government institution.

### Core Features

Use these features throughout the website:

- Social Feed
- Project Tracking
- Stranded/Stalled Project Reporting
- Completed Project Showcase
- Evidence-based project reports with images
- County and sub-county civic context
- Rankings System
- Weekly leaderboard snapshots
- Leader detail pages
- Direct Messaging
- Group Chats
- Public profiles
- SIVIQ codes
- Follow/follower discovery
- Verified profile badges
- Notifications
- Notification settings
- Secure Authentication
- PIN app lock
- Biometric Authentication
- Session timeout controls
- Active sessions
- Trusted devices
- Security activity logs
- Data export
- Account deletion recovery flow
- Legal acceptance history
- Moderation System
- Appeals process

### Main App Sections

Home:

- Community discussion layer.
- Public posts, images, comments, likes, replies, sharing, reporting, and profile discovery.
- Tabs: For You, Trending, Discover.

Projects:

- Civic evidence layer.
- Users submit project reports with county, sub-county, location, status, description, and evidence image.
- Project statuses:
  - `ongoing`
  - `completed`
  - `stalled`
  - `excellent`
- Users can approve, disapprove, comment, reply, share, report, and discuss projects.

Rankings:

- Civic intelligence layer.
- Weekly score snapshots.
- Leader rankings by role and geography.
- Rankings are community SIVIQ sentiment analytics, not official government truth.
- Filters:
  - National
  - County
  - Sub-county / Constituency
  - Governors
  - MPs

Chats:

- Direct messages.
- Group chats.
- Chat search.
- Unread states.
- Favorites and archives.
- Delivery/read indicators.
- Online presence.

Profile:

- Public identity.
- SIVIQ code.
- Bio.
- County/sub-county.
- Followers/following.
- Verification badge.
- Privacy settings.
- Security tools.
- Legal records.
- Account controls.

### Authentication Methods

The Flutter app currently supports:

- Email and password signup/login.
- Signup requires accepting Terms, Privacy Policy, and Community Guidelines.
- Legal acceptance is recorded in `legal_acceptance_logs`.
- App copy says OTP/2FA may be added later.

Security features:

- 4-digit PIN app lock.
- Biometric unlock through device fingerprint or face unlock with PIN fallback.
- Session timeout.
- Lock now.
- PIN reset with password reauthentication.
- Security activity logs.
- Trusted devices.
- Active sessions.
- Secure local storage.
- Data export.
- Account deletion request/recovery period.

### User Roles

Use these role names when describing trust and moderation:

- `user`
- `moderator`
- `admin`
- `super_admin`

Admin contact currently verified in the live database:

- `adminsiviq@gmail.com`
- username: `official_siviq`
- role: `super_admin`
- role label: `SIVIQ Super Admin`
- account status: `active`

### Branding

Use the existing Flutter assets if this React project can access them:

- `assets/realicon.png`
- `assets/real_splash.png`
- `assets/app_icon_mark.png`

If the React repo does not have these files yet, ask the implementer to copy them from the Flutter project into the React public assets folder.

### App Colors

Prefer the actual Flutter brand palette:

```ts
const colors = {
  primaryGreen: '#0B6E4F',
  lightGreen: '#2E8B57',
  white: '#FFFFFF',
  black: '#121212',
  dangerRed: '#C1121F',
  background: '#F7F9F8',
  grey: '#6B7280',
  success: '#198754',
  warning: '#FFB703',
  border: '#E5E7EB',
};
```

The requested website theme can also use `#16A34A` as a brighter web accent, but keep `#0B6E4F` as the primary SIVIQ brand color unless there is a strong design reason.

Design tone:

- Clean
- Modern
- Government-tech inspired
- Mobile-first
- Trustworthy
- Professional
- Accessible
- Fast loading
- Not flashy political campaign design

## Website Technical Requirements

Use:

- React
- TypeScript
- React Router
- Responsive design
- SEO metadata per page
- Accessible components
- Reusable layouts
- Clean folder structure
- Fast loading images
- Mobile navigation
- Footer on every page
- Public legal pages crawlable by search engines and accessible without login

Recommended structure:

```text
src/
  app/
    router.tsx
  components/
    layout/
      Header.tsx
      Footer.tsx
      PageShell.tsx
    ui/
      Button.tsx
      Card.tsx
      Section.tsx
      Seo.tsx
  pages/
    HomePage.tsx
    AboutPage.tsx
    LeadershipPage.tsx
    ContactPage.tsx
    PrivacyPolicyPage.tsx
    TermsPage.tsx
    CommunityGuidelinesPage.tsx
    DataSafetyPage.tsx
    AccountDeletionPage.tsx
    MaintenancePage.tsx
    NotFoundPage.tsx
  data/
    legal.ts
    team.ts
    features.ts
  styles/
    globals.css
```

## Required Public Routes

Create these exact public routes:

```text
/
/about
/leadership
/contact
/privacy-policy
/terms
/community-guidelines
/data-safety
/account-deletion
/maintenance
```

These URLs are required for Play Store support:

- Privacy Policy URL: `https://siviq.africa/privacy-policy`
- Terms URL: `https://siviq.africa/terms`
- Community Guidelines URL: `https://siviq.africa/community-guidelines`
- Data Safety URL: `https://siviq.africa/data-safety`
- Account Deletion URL: `https://siviq.africa/account-deletion`
- Contact URL: `https://siviq.africa/contact`

If the production domain differs, make all links configurable in one constants file.

## Website Pages

### 1. Home Page

Hero section:

- Show SIVIQ logo.
- H1: `SIVIQ Africa`
- Tagline: `Building better community together`
- Brief description:

```text
SIVIQ is an independent civic accountability platform helping communities report, discuss, verify, and track public projects across Kenya.
```

- Primary button: `Download App`
- Secondary button: `Learn More`
- Include a note that app store links can be connected when available.

Features section:

Display these feature cards:

- Social Feed
- Project Tracking
- Stalled Project Reporting
- Completed Project Showcase
- Rankings System
- Private Messaging
- Group Chats
- Secure Authentication
- PIN and Biometric App Lock
- Moderation and Appeals

How It Works section:

Steps:

1. Join SIVIQ
2. Discover Projects
3. Report Progress
4. Engage Communities
5. Hold Leaders Accountable

Security section:

Highlight:

- Secure account access
- Biometric login
- PIN app lock
- Session timeout
- Trusted devices
- Security activity history
- Secure cloud infrastructure powered by Supabase

Statistics section:

Use animated/stat cards. Use neutral placeholders until backend stats are connected:

- Registered Users: `Coming soon`
- Projects Tracked: `Coming soon`
- Counties Covered: `47`
- Reports Submitted: `Coming soon`

CTA section:

```text
Join a community built for civic transparency, evidence, and accountability.
```

### 2. About Us Page

Use:

Mission:

```text
SIVIQ exists to increase transparency, accountability, and civic engagement across Africa by helping communities document public projects, discuss local issues, and participate responsibly in governance.
```

Vision:

```text
A digitally empowered Africa where citizens actively participate in development and governance.
```

Core values:

- Transparency
- Accountability
- Innovation
- Community
- Integrity

Include the independence disclaimer:

```text
SIVIQ is independent and is not affiliated with any government institution, county office, elected leader, or public agency.
```

### 3. Leadership Team Page

Create professional profile cards with circular profile images.

Founder & Creator:

- Gregory Steve

Co-Founders:

- Lenox Okoth
- Chloe Jane

Assistant Leads:

- Steven Khayadi
- Emmanuel Blessing

Each profile card must contain:

- Circular profile photo placeholder
- Name
- Position
- Short biography placeholder
- LinkedIn placeholder
- Email placeholder
- WhatsApp placeholder

Do not invent private personal emails or phone numbers. Use placeholders until the owner provides them.

### 4. Contact Page

Include a contact form:

- Name
- Email
- Subject
- Message

Company contacts:

- `support@siviq.africa`
- `info@siviq.africa`
- `adminsiviq@gmail.com`
- WhatsApp: `+254719637416`

Office address:

- Use placeholder: `Office address to be updated`

Social media links:

- Facebook placeholder
- Instagram placeholder
- X / Twitter placeholder
- LinkedIn placeholder

Google Maps:

- Add a styled map placeholder section.
- Do not embed a fake address.

### 5. Privacy Policy Page

This page must be public, SEO-indexable, searchable, and suitable for Play Store privacy URL submission.

Requirements:

- Preserve the in-app legal wording below.
- Add a table of contents.
- Add search/filter functionality for sections.
- Show `Last Updated: June 4, 2026`.
- Show `Version 1.0.0`.
- Include contact email `adminsiviq@gmail.com`.
- Add a clear note that this policy should receive legal review before public launch.

Use this exact in-app Privacy Policy wording as the baseline:

#### Privacy Policy

Version 1.0.0

##### Data We Collect

SIVIQ collects account details such as email, display name, username, SIVIQ code, county, sub-county, profile image URL, and app activity needed to operate SIVIQ features.

##### Why We Collect It

We use this information to verify accounts, reduce abuse, personalize local SIVIQ content, secure your account, and support moderation, appeals, and recovery.

##### Location And Identity

County and sub-county selections are used for local relevance. Full email addresses are not shown publicly. Public profile identity can show your display name, username, and SIVIQ code.

##### Your Choices

You can request data export or account deletion from Settings. Deletion may use a recovery period before permanent purge to protect against mistakes and disputes.

##### Kenya Data Protection

SIVIQ is designed to follow the Kenya Data Protection Act 2019, including purpose limitation, access control, and user data rights.

Add the following website-specific Play Store data details after preserving the baseline wording:

##### Additional Data Safety Details

SIVIQ may process uploaded project images, social post images, notification preferences, security logs, trusted device records, active session records, legal acceptance records, moderation reports, comments, messages, follows, project votes, age group, selected interests, in-app search terms, and ad impressions/clicks where monetization features are active.

SIVIQ does not intentionally collect contacts, SMS history, installed apps, constant precise GPS, microphone recordings, call logs, or browsing history outside SIVIQ.

### 6. Terms and Conditions Page

This page must be public, SEO-indexable, searchable, and suitable for Play Store/legal review.

Preserve this in-app Terms of Service baseline:

#### Terms of Service

Version 1.0.0

##### User-Generated Content

Posts, ratings, comments, and reports are created by users. SIVIQ does not guarantee that user submissions are true, complete, or official.

##### No Government Affiliation

SIVIQ is not affiliated with, endorsed by, or approved by the Government of Kenya, county governments, elected officials, or public agencies.

##### Accuracy

Users are responsible for posting truthful information. Posts without evidence such as photos, location, or sources may be marked unverified or given lower ranking weight.

##### Liability

You are responsible for your posts and comments. SIVIQ may remove reported content that violates these terms or community guidelines.

##### Right of Reply

Public leaders and authorized representatives may request verification and respond to ratings or project reports through the app process.

Also add comprehensive website terms covering:

- Account registration
- Email/password authentication
- Legal acceptance during signup
- User-generated content license
- Project reporting and evidence requirements
- Messaging and group chats
- Profile visibility
- Rankings disclaimer
- Moderation actions
- Account suspension/bans
- Appeals
- Data export and deletion
- Prohibited conduct
- No paid ranking influence
- Limitation of liability
- Changes to terms
- Contact information

Keep language professional and legally cautious.

### 7. Community Guidelines Page

Preserve this exact in-app baseline:

#### Community Guidelines

Version 1.0.0

##### What Is Allowed

Post real SIVIQ projects, photos, ratings, comments, and local observations. Keep discussion factual, local, and respectful.

##### What Is Not Allowed

Fake projects, fake photos, spam, fraud, pornography, hate speech, incitement to violence, betting content, and coordinated rating manipulation are not allowed.

##### Defamation And Proof

Do not make serious accusations without evidence. Claims about corruption, theft, or criminal conduct should include a source, location, or supporting material.

##### Enforcement

Reported posts may be hidden, reviewed, removed, or escalated. Repeated false or abusive activity can lead to account restrictions or bans.

##### Your Responsibility

You are responsible for what you post. If you are unsure whether something is true, do not publish it as fact.

### 8. Data Safety Page

Create a Play Store-friendly data safety page.

Include these sections:

- Data collected
- Why data is collected
- Data not collected
- Data sharing
- Security practices
- User controls
- Account deletion
- Data export
- Contact

Data collected:

- Email
- Display name
- Username
- SIVIQ code
- County
- Sub-county
- Profile image URL
- Uploaded post/project images
- App activity needed for posts, comments, votes, reports, follows, projects, rankings, notifications, moderation, appeals, and recovery
- Chat and group message data needed to provide messaging
- Notification preferences
- Security activity
- Trusted device/session metadata
- Legal acceptance logs
- Age group
- Selected interests
- In-app search terms
- Ad impressions/clicks where sponsored content is active

Data not collected:

- Contacts
- SMS history
- Installed apps
- Constant precise GPS tracking
- Microphone recordings
- Call logs
- Browsing history outside SIVIQ
- Exact date of birth
- Exact age

### 9. Account Deletion Page

Create a public Play Store account deletion instruction page.

Content:

```text
SIVIQ users can request account deletion from inside the app.
```

Steps:

1. Open the SIVIQ app.
2. Go to Profile.
3. Open Danger Zone.
4. Choose Delete account.
5. Confirm your password.
6. Your account will be scheduled for deletion with a recovery period before permanent purge.

Also provide manual support:

```text
If you cannot access your account, email adminsiviq@gmail.com with your username, account email, and deletion request.
```

Explain:

- Some records may be retained temporarily for disputes, legal compliance, abuse prevention, and account recovery.
- Public user-generated content may be removed, anonymized, or retained where legally necessary.
- Deletion is not instant because the app uses a recovery period.

### 10. Maintenance Page

Create a dedicated maintenance page.

Content:

```text
SIVIQ is currently undergoing scheduled maintenance.
```

Additional text:

```text
We are working to improve your experience. Please check back shortly.
```

Include:

- Countdown component placeholder
- Status indicator
- Return Home button
- No emoji unless the design system uses it cleanly

### 11. Footer

Footer appears on every page.

Quick Links:

- Home
- About
- Leadership
- Privacy Policy
- Terms
- Community Guidelines
- Data Safety
- Account Deletion
- Contact

Legal:

```text
Copyright © SIVIQ Africa
All Rights Reserved
```

Contact:

- `adminsiviq@gmail.com`

Social icons:

- Facebook
- Instagram
- X / Twitter
- LinkedIn

Use placeholder URLs until official links are provided.

## SEO Requirements

Add metadata for each page:

- title
- description
- canonical URL
- Open Graph title
- Open Graph description
- Open Graph image using SIVIQ logo/splash asset
- Twitter card metadata

Homepage title:

```text
SIVIQ Africa | Building better community together
```

Homepage description:

```text
SIVIQ is an independent civic accountability platform helping communities report, discuss, verify, and track public projects across Kenya.
```

Privacy page title:

```text
Privacy Policy | SIVIQ Africa
```

Terms page title:

```text
Terms of Service | SIVIQ Africa
```

## Accessibility Requirements

- Semantic HTML.
- Keyboard navigable menus.
- Visible focus states.
- Proper heading hierarchy.
- Alt text for logos and images.
- Color contrast must pass WCAG AA.
- Forms need labels, validation messages, and accessible error states.
- Legal page search must be accessible.

## Design Requirements

- Mobile-first responsive layout.
- Desktop max-width around 1120px to 1200px.
- Use 8px border radius for cards/buttons unless a component needs a circle, such as profile photos.
- Avoid visual clutter.
- Use subtle transitions.
- Do not make the website look like a political campaign.
- Use civic/product visuals and the real app logo assets.
- Use clean cards for feature lists and leadership profiles.
- Keep legal pages highly readable.

## Content Rules

- Use `SIVIQ`, not `CIVIQ`, in public copy.
- Do not claim SIVIQ is an official government app.
- Do not claim rankings are official truth.
- Say rankings are community sentiment/accountability analytics.
- Do not invent official social media URLs, personal phone numbers, personal emails, or physical office addresses.
- Do not publish fake download links. Use placeholder buttons or disabled buttons until Play Store/App Store URLs exist.
- Preserve the legal wording above exactly where instructed.

## Final Deliverable

Generate production-ready React + TypeScript code for the complete website:

- Routes
- Pages
- Components
- Layout
- Navigation
- Footer
- SEO metadata
- Responsive styling
- Legal search/table of contents
- Contact form UI
- Maintenance page
- Play Store support pages

After implementation, provide:

- File tree
- Commands to run
- Build command
- Any values that need replacement before deploy, such as domain, app download links, official social media URLs, team profile photos, and office address.
