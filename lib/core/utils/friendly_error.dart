const siviqOfflineMessage =
    "You're offline. Connect to WiFi or buy bundles to continue using SIVIQ.";

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
  return fallback;
}
