const siviqOfflineMessage =
    "Seems you're offline. Check your connection and try again.";

String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('timed out') ||
      text.contains('xmlhttprequest') ||
      text.contains('supabase.co')) {
    return siviqOfflineMessage;
  }
  if (text.contains('invalid login credentials') ||
      text.contains('invalid_credentials') ||
      text.contains('invalid password')) {
    return 'The email or password is incorrect.';
  }
  if (text.contains('email not confirmed')) {
    return 'Please confirm your email before signing in.';
  }
  if (text.contains('user already registered') ||
      text.contains('already been registered')) {
    return 'An account already exists for this email. Try signing in instead.';
  }
  if (text.contains('invalid email') ||
      text.contains('email_address_invalid')) {
    return 'Enter a valid email address.';
  }
  if (text.contains('foreign key') ||
      text.contains('subcounty_id') ||
      text.contains('county_id')) {
    return 'Oops, that county or constituency is not available right now. Please choose another location.';
  }
  if (text.contains('relation') && text.contains('does not exist')) {
    return 'This service is temporarily unavailable. Please try again shortly.';
  }
  return fallback;
}
