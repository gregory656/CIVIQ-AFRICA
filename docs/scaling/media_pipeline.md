# Media Pipeline

Chat media should stay out of Postgres.

- Upload compressed files to Cloudinary.
- Store only URLs and metadata in `messages`.
- Use thumbnails in chat lists and previews.
- Validate file size and MIME type before upload.
- Add moderation scanning before broad media rollout.
- Keep voice notes and documents behind server-side validation.

For 10k-100k users, Cloudinary CDN should handle delivery while Supabase stores references, permissions, and conversation state.
