# CIVIQ Africa Phase 1 Architecture

The mobile app uses Flutter with a feature-first structure.

## Client

- Flutter UI
- Riverpod for dependency injection and state access
- GoRouter for navigation
- flutter_dotenv for public client configuration

## Backend Services

- Supabase Auth for email/password authentication and session persistence
- Supabase Postgres for profiles, notifications, legal logs, audit logs, and moderation records
- Cloudinary unsigned uploads for profile images and later report media

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
