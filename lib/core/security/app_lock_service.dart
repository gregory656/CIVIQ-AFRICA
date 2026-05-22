import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'biometric_service.dart';
import 'pin_service.dart';
import 'secure_storage_service.dart';
import 'session_service.dart';

final appLockServiceProvider = ChangeNotifierProvider<AppLockService>((ref) {
  return AppLockService(
    storage: ref.watch(secureStorageServiceProvider),
    sessionService: ref.watch(sessionServiceProvider),
    pinService: ref.watch(pinServiceProvider),
    biometricService: ref.watch(biometricServiceProvider),
  );
});

class AppLockService extends ChangeNotifier {
  AppLockService({
    required SecureStorageService storage,
    required SessionService sessionService,
    required PinService pinService,
    required BiometricService biometricService,
  }) : _storage = storage,
       _sessionService = sessionService,
       _pinService = pinService,
       _biometricService = biometricService;

  static const _biometricKey = 'biometric_enabled';

  final SecureStorageService _storage;
  final SessionService _sessionService;
  final PinService _pinService;
  final BiometricService _biometricService;

  bool _locked = false;
  bool _initialized = false;

  bool get locked => _locked;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _locked = await _sessionService.shouldLock();
    _initialized = true;
    notifyListeners();
  }

  Future<void> onPaused() => _sessionService.markLastActive();

  Future<void> onResumed() async {
    if (await _sessionService.shouldLock()) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<void> lockNow() async {
    if (!await _pinService.hasPin()) return;
    _locked = true;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _pinService.verifyPin(pin);
    if (ok) await _unlock();
    return ok;
  }

  Future<bool> unlockWithBiometrics() async {
    final enabled = await _storage.readBool(_biometricKey);
    if (!enabled) return false;
    final ok = await _biometricService.authenticate();
    if (ok) await _unlock();
    return ok;
  }

  Future<void> _unlock() async {
    _locked = false;
    await _sessionService.markLastActive();
    notifyListeners();
  }
}
