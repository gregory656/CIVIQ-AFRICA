import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final value = await read(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<void> writeBool(String key, bool value) {
    return write(key, value ? 'true' : 'false');
  }
}
