# Rate Limits

Current server-side chat guard:

- `send_message()` rejects bursts of 8 or more messages in 10 seconds.

Recommended next limits:

- Messaging: 20 messages per minute per user.
- Search: 10 searches per 10 seconds per user.
- Login: 5 failed attempts per 15 minutes per account/device.
- Follows: burst detection for mass-follow patterns.
- Reports: throttle repeated identical reports.

Prefer Edge Functions or database-backed counters for sensitive limits. Flutter-side debounce is useful for UX but is not a security boundary.
