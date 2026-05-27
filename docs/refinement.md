# SIVIQ Play Store Refinement Checklist

This document captures the final bug fixes and polish work needed before pushing SIVIQ to the Play Store. No new major features should be added until these items are handled, tested, and confirmed stable.

The goal of this phase is simple:

> Make the current app reliable, understandable, and ready for real users.

## Launch Rule

Until the Play Store release is ready:

- Prioritize bug fixes, reliability, user trust, and basic polish.
- Avoid adding new feature ideas unless they directly fix a launch blocker.
- Every change should be small enough to test clearly.
- User-facing errors must be friendly and should not expose Supabase, stack traces, table names, API URLs, or developer wording.

## 1. Offline and Error Handling

When the user is offline or the network fails, the app should not show raw technical errors such as Supabase URLs, exception names, or backend messages.

Required user message:

```text
You're offline. Connect to WiFi or buy bundles to continue using SIVIQ.
```

Apply this to:

- Home feed loading
- Search
- Profile loading
- Project loading
- Post creation and editing
- Report actions
- Account deletion
- Any Supabase query or mutation that can fail because of network issues

Expected behavior:

- Show a friendly offline state, snackbar, dialog, or inline message.
- Keep the app usable where cached data already exists.
- Do not crash or show a red Flutter error screen.
- Do not expose implementation details to users.

## 2. Global Home Search

The home screen search bar should become a global search entry point.

When a user types a keyword such as `red`, the results should include:

- Profiles whose name, username, bio, location, or relevant searchable fields match `red`
- Posts containing `red`
- Nearby posts containing `red`, ordered by relevance and location where possible
- Older archived or hidden posts if they match the search

Search results should be grouped by category:

```text
Profiles
Posts Near You
All Matching Posts
```

Profile results should behave like the current following search experience:

- Show profile identity clearly.
- Show a follow button where appropriate.
- Let the user open the profile.

Post results should behave like Reddit-style search results:

- Show matching post content.
- Show author/profile context.
- Show distance or local context when available.
- Let the user open the post.

The user should be able to decide whether to read the post or follow the account from the same search flow.

## 3. Long Post Read More

Long posts should not display the entire text in the feed.

Required behavior:

- Collapse long text after a reasonable number of lines.
- Add a `Read more` action.
- Expanding should reveal the full post text.
- If expanded, show a `Show less` action if it fits the existing UI pattern.
- The collapsed feed should remain clean and easy to scan.

Apply this to:

- Home posts
- Project posts if they display long text in list form
- Any profile post list using the same post card component

## 4. Remove Red Error Screens After Successful Actions

Some actions complete successfully but briefly show a red Flutter error screen. This must be fixed before launch.

Known affected actions:

- Edit post, then save
- Delete account
- Report post

Expected behavior:

- If the action succeeds, show a normal success state or return to the correct screen.
- If the action fails, show a friendly error message.
- Never show a red Flutter error screen to the user.
- Confirm navigation does not reference disposed widgets, missing routes, stale context, or deleted records.

## 5. Home Feed Freshness and Infinite Scrolling

The home screen should support infinite scrolling.

Required behavior:

- Load posts in pages instead of all at once.
- Fetch more posts when the user scrolls near the bottom.
- Avoid duplicate posts while paging.
- Show a loading indicator at the bottom when loading more.
- Show a friendly empty state when there are no posts.

Feed freshness rules:

- The feed should show fresh content each time the user opens the app where possible.
- Posts older than 2 weeks should be hidden from the normal home feed.
- Older posts should not be deleted.
- Older posts should remain searchable by keyword, profile, or other search filters.

Recommended interpretation:

- Treat posts older than 14 days as archived for feed display.
- Keep archived posts available in global search and profile history where appropriate.

## 6. Menu Updates

Update the left menu with launch-ready pages and labels.

Required menu pages:

- FAQ
- About
- Appeals
- Contact

Appeals page purpose:

- Users should understand this is where they go if their account is suspended, restricted, or moderated unfairly.
- If a full appeals backend is not ready, provide clear instructions and contact options.

Contact details:

```text
WhatsApp: +254719637416
Email: gregorysteve656@gmail.com
```

## 7. FAQ Page Content

The FAQ page should feel alive and useful, not empty.

Suggested FAQ topics:

- What is SIVIQ?
- How do I create an account?
- How do posts work?
- How do project posts work?
- How do I follow people?
- How do I report harmful content?
- What happens when I report a post?
- Why was my post removed?
- What should I do if my account is suspended?
- How do I contact SIVIQ support?
- Is SIVIQ a government app?

Important message:

```text
SIVIQ is an independent civic platform and is not affiliated with any government institution.
```

## 8. About Page Content

The About page should explain SIVIQ clearly and simply.

Core message:

```text
SIVIQ is a civic community platform built to help people share local issues, projects, ideas, and public updates in one place.
```

The page should mention:

- Community posts
- Local civic discussions
- Project updates
- Following profiles
- Reporting unsafe or harmful content
- Independent civic purpose
- Contact details

Avoid overclaiming. Keep it warm, direct, and trustworthy.

## 9. Appeals Page Content

The Appeals page should help users who believe their account or content was restricted unfairly.

Required content:

- Explain that users can appeal account suspension, content removal, or restrictions.
- Ask users to include their phone/email, username, and a short explanation.
- Provide WhatsApp and email contact details.
- Mention that abusive appeals or false information may be ignored.

Contact details:

```text
WhatsApp: +254719637416
Email: gregorysteve656@gmail.com
```

## 10. Home Post Three-Dot Menu

Each home post should have a three-dot menu with useful moderation and privacy actions.

Required actions:

- Save to device
- Block post
- Report post
- Hide post

Expected behavior:

- `Save to device` saves media where supported.
- `Block post` prevents the post from appearing for that user again.
- `Report post` opens the reporting flow.
- `Hide post` removes the post from the current user's feed without reporting it.

Use clear confirmation or undo behavior where appropriate.

## 11. Project Post Three-Dot Menu

Project posts should support owner actions.

For the poster/owner:

- Edit project post
- Delete project post

For other users:

- Report project post
- Hide project post

Expected behavior:

- Edit should be fully functional.
- Delete should ask for confirmation before removing the project post.
- After edit or delete, the app should update the UI cleanly without red error screens.
- Non-owners should not see owner-only actions.

## 12. Open Project Rendering Bug

Fix the bug where tapping `Open project` shows a blank screen.

Expected behavior:

- Tapping `Open project` opens the correct project detail screen.
- The screen should show project title, description, status, author/context, media if available, and actions.
- If the project cannot be found, show a friendly not-found state.
- If offline, show the standard offline message.

## 13. Profiles Tab Polish

The profiles tab needs more life and utility before launch.

Top-right three-dot menu actions:

- Refresh
- Report issue
- Share
- Sort

Search bar:

- Make the search bar visually polished and useful.
- Search profiles by name, username, location, or bio where available.
- Show follow buttons in profile results where appropriate.
- Show an empty state when no profiles match.

Sort options:

- Suggested
- Recently active
- Nearby, if location data is available
- A to Z

Expected behavior:

- Refresh reloads profile results.
- Report issue opens a simple support/report flow.
- Share opens the platform share sheet where supported.
- Sort changes the result order without breaking search.

## 14. QA Checklist Before Play Store

Before release, test these flows on a real Android device:

- Open app while offline.
- Load home feed while offline.
- Search while offline.
- Search for a common keyword and confirm profiles plus posts appear.
- Create a long post and confirm `Read more` works.
- Edit a post and confirm there is no red error screen.
- Report a post and confirm there is no red error screen.
- Delete account on a test account and confirm there is no red error screen.
- Scroll home feed until more posts load.
- Confirm posts older than 14 days do not appear in the normal feed.
- Confirm older posts can still be found through search.
- Open FAQ, About, Appeals, and Contact pages.
- Use every home post three-dot menu action.
- Use every project post three-dot menu action as owner and non-owner.
- Tap `Open project` and confirm the detail page renders.
- Search and sort profiles.
- Use profiles tab three-dot menu actions.

## Implementation Priority

1. Fix red error screens and offline error handling.
2. Fix `Open project` blank rendering.
3. Add long-post `Read more`.
4. Add home feed infinite scrolling and 14-day archive behavior.
5. Upgrade global home search.
6. Update home and project post menus.
7. Polish profiles tab search, sort, and menu actions.
8. Add FAQ, About, Appeals, and Contact content.
9. Run real-device QA before Play Store upload.

## 15. Launch Polish Completed

Completed before the Play Store push:

- App naming corrected to SIVIQ in launch documentation.
- Splash screen now uses `assets/real_splash.png`; the old `assets/splash_screen.png` reference was removed.
- Android native launch background uses the real splash image in full-screen fill mode.
- Flutter splash screen uses the real splash image with `BoxFit.cover` and hides system bars while the splash is visible.
- Social post text, social post detail text, project feed text, project detail descriptions, and comment text now detect `http://` and `https://` links.
- Detected links are blue and open through the device browser.
- Comment reply UI now shows reply context, focuses the input immediately, and reply notifications say `{username} mentioned you in a comment`.
- Group chat swipe-to-reply now opens the typing box immediately.

Last verification notes:

- `flutter analyze` passed.
- `flutter test` passed.
- A real-device launch on `SM A135F` installed package `com.siviq.africa` successfully.
- Startup log review after relaunch showed no `FATAL EXCEPTION`, no `AndroidRuntime` crash, and no `E/flutter` crash line.
