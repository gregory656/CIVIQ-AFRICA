# Message And Comment Actions

Implemented on 2026-05-26.

## Chat Messages

- Long-pressing a message opens a centered action sheet.
- Swiping a message from left to right starts a reply.
- Own messages support Reply, Star, Delete for me, Delete for everyone, and Edit while the message is under 5 minutes old.
- Other people's messages support Reply, Star, Delete for me, and Report spam.
- Replies are sent with `reply_to_message_id` and render an inline preview above the message body.
- Group-chat replies create a notification for the author of the replied-to message: `{username} replied to your message`.
- Direct-chat replies do not create the special reply notification; they only show the local reply preview in the conversation.

## Chat List

- Long-pressing a chat row opens a centered action sheet.
- Chat rows support Archive and `Delete chat with {username/title}`.
- Delete chat is scoped to the current user through `delete_conversation_for_me`.

## Comments

- Social post and project comments remain threaded under the replied comment.
- Long-pressing a comment opens a centered action sheet.
- Own comments support Reply, Edit, and Delete.
- Other people's comments support Reply and Report spam.
- Social post comment notifications:
  - `{username} commented on your post`
  - `{username} replied to your comment`
- Project comment notifications:
  - `{username} commented on your project`
  - `{username} replied to your comment`

## Backend Contract

The migration `supabase/migrations/20260526150000_chat_message_actions_and_comment_notifications.sql` owns the server behavior:

- `edit_message` enforces the 5-minute edit window.
- `delete_message_for_me` hides one user's copy.
- `delete_message_for_everyone` soft-deletes the sender's message for all participants.
- `report_message_spam` records spam reports.
- `archive_conversation_for_me` and `delete_conversation_for_me` manage chat-list actions.
- `send_message` validates reply targets and creates group reply notifications.
- comment triggers create post/project comment and reply notifications.

The notification badge now displays numbers (`1` to `9+`) instead of a plain red dot.

## Account-Scoped Feed State

Fix added on 2026-05-26:

- `socialHomeFeedProvider` now watches `currentAuthUserIdProvider` and the active Supabase auth user before fetching feed rows.
- Auth changes and logout now invalidate `socialHomeFeedProvider`.
- This prevents `viewer_has_liked` from being reused across accounts, so a post liked by one account does not appear as a red liked heart after signing into another account.

## Post Save And Action UX

Fixes added on 2026-05-26:

- Post `Save to device` opens from a centered action dialog, matching notification/comment/message action positioning.
- Save requests gallery/photo album access and writes the rendered watermarked PNG directly to the device's gallery.
- The visible feed card no longer shows the `SIVIQ` watermark near the comment box; the watermark is enabled only while rendering the saved image.
- The notification unread number badge ignores pointer events so it cannot block the notification bell tap target.
- If the gallery plugin is unavailable on the current runtime, saving falls back to writing the PNG directly into the device Downloads/Documents location instead of surfacing `MissingPluginException`.

## Project Card Fixes

Fixes added on 2026-05-26:

- Project cards now use centered 3-dot actions with Open project, Share, and Report.
- Approve and Disapprove controls show small colored labels under the vote counts: green for Approve and red for Disapprove.
- Project card and detail image rendering no longer force-unwrap image URLs.
- Project detail image rendering is bounded and uses plain `BoxFit.contain` during first paint, avoiding blank pages and paint-boundary assertion crashes from unconstrained zoom layout.
- Opening a project from the centered action dialog now waits briefly for the dialog transition to finish before pushing on the root navigator.
