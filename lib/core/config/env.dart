import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');
  static String get cloudinaryCloudName => _required('CLOUDINARY_CLOUD_NAME');
  static String get cloudinaryUploadPreset =>
      _required('CLOUDINARY_UPLOAD_PRESET');

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value.trim();
  }
}
