# Minor Updates — Fixed Errors

## Data recovery

- Added `supabase/migrations/20260912100000_restore_leaderboard_snapshots.sql`.
- It rebuilds the current weekly leaderboard from the existing seeded Governor and MP directory, restoring rankings for all available leaders.
- Rankings now merge snapshot rows with the leader directory, so a partial or unavailable snapshot cannot hide leaders from the Rankings tab.
- The migration also rejects county/constituency pairs that do not belong together.
- Added `20260912110000_allow_multiple_profiles_per_subcounty.sql` to remove the erroneous single-profile-per-constituency constraint that blocked valid Machakos registrations.
- Added `20260912120000_fix_profile_location_trigger_rls.sql` so location validation can safely read the authoritative county data under row-level security.

## Safe errors and authentication

- Authentication accepts email addresses only and validates the address before a request is made.
- Authentication, profile setup, avatar upload, profile editing, interests, and rankings now show friendly messages instead of Supabase/PostgREST details.
- Network failures display: “Seems you're offline. Check your connection and try again.”
- Location availability is checked before profile creation, preventing invalid county or constituency references.
- Project reports and social posts show the offline message instead of backend error text when publishing fails without a connection.

## Onboarding and launch

- Moved interest selection to its own `Personalize SIVIQ` screen with Back, Continue, and Skip actions.
- Removed the Flutter splash screen and its launch artwork. Startup routes directly to Intro or Home.
- Added a 900 ms entrance animation on the Intro screen for a quick, non-blocking opening transition.
- Added explicit Back buttons throughout the account-creation steps and profile guidance for name, bio, and location.
- Profile setup now offers a safe “Continue without location for now” path if a location save fails; locations can be updated from Edit Profile.
- Interest selection now has an in-app fallback list and never blocks onboarding when the interests service is unavailable.
- Restored and verified 12 live interest records; `20260912130000_restore_interest_seed.sql` preserves this seed set in future deployments.

## Validation

- Ran `dart format` on all changed Dart files.
- `flutter analyze` could not complete in this environment because dependency resolution remained at `Resolving dependencies...` without returning analyzer output.
- Ran `supabase db push --include-all` against the configured project. The CLI returned no diagnostic output; verify the migration appears in the Supabase dashboard before releasing.
