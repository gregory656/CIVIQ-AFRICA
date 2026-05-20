# Security Model

## Client-Safe Values

The Flutter client may use Supabase anon access and Cloudinary unsigned upload presets. All database access must still be protected by Supabase Row Level Security policies.

## Backend-Only Values

Service role keys and Cloudinary API secrets are never referenced from Flutter code. They are reserved for future Supabase Edge Functions or another backend.

## Compliance Logs

The database includes audit logs, security events, legal acceptance logs, sessions, moderation actions, and appeals. These support account recovery, disputes, abuse handling, and policy acceptance proof.
