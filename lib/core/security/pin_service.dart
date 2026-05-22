import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage_service.dart';

final pinServiceProvider = Provider<PinService>((ref) {
  return PinService(ref.watch(secureStorageServiceProvider));
});

class PinService {
  PinService(this._storage);

  static const _hashKey = 'hashed_pin';
  static const _saltKey = 'pin_salt';
  static const _biometricKey = 'biometric_enabled';
  static const _appLockKey = 'app_lock_enabled';

  final SecureStorageService _storage;

  Future<bool> hasPin() async {
    final hash = await _storage.read(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  String? validatePinPolicy(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return 'PIN must be exactly 4 digits.';
    }
    if (_isRepetitive(pin)) return 'PIN cannot use the same digit four times.';
    if (_isSequential(pin)) return 'PIN cannot be sequential.';
    if ({'0000', '1111', '2222', '1234'}.contains(pin)) {
      return 'Choose a less predictable PIN.';
    }
    return null;
  }

  Future<void> savePin(String pin) async {
    final error = validatePinPolicy(pin);
    if (error != null) throw ArgumentError(error);

    final salt = _newSalt();
    await _storage.write(_saltKey, salt);
    await _storage.write(_hashKey, _hash(pin, salt));
    await _storage.writeBool(_appLockKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(_saltKey);
    final hash = await _storage.read(_hashKey);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    await _storage.delete(_hashKey);
    await _storage.delete(_saltKey);
    await _storage.writeBool(_biometricKey, false);
    await _storage.writeBool(_appLockKey, false);
  }

  bool _isRepetitive(String pin) => pin.split('').toSet().length == 1;

  bool _isSequential(String pin) {
    final digits = pin.split('').map(int.parse).toList(growable: false);
    var ascending = true;
    var descending = true;
    for (var i = 1; i < digits.length; i++) {
      ascending = ascending && digits[i] == digits[i - 1] + 1;
      descending = descending && digits[i] == digits[i - 1] - 1;
    }
    return ascending || descending;
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
