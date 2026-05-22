import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage_service.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref.watch(secureStorageServiceProvider));
});

enum SessionTimeoutOption {
  never(-1, 'Never'),
  immediately(0, 'Immediately'),
  fiveMinutes(5, '5 Minutes'),
  tenMinutes(10, '10 Minutes'),
  thirtyMinutes(30, '30 Minutes');

  const SessionTimeoutOption(this.minutes, this.label);

  final int minutes;
  final String label;

  static SessionTimeoutOption fromMinutes(int minutes) {
    return values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => tenMinutes,
    );
  }
}

class SessionService {
  SessionService(this._storage);

  static const timeoutKey = 'session_timeout_minutes';
  static const lastActiveKey = 'last_active_timestamp';
  static const appLockKey = 'app_lock_enabled';

  final SecureStorageService _storage;

  Future<SessionTimeoutOption> getTimeout() async {
    final value = await _storage.read(timeoutKey);
    return SessionTimeoutOption.fromMinutes(int.tryParse(value ?? '') ?? 10);
  }

  Future<void> setTimeout(SessionTimeoutOption option) async {
    await _storage.write(timeoutKey, option.minutes.toString());
  }

  Future<void> markLastActive({DateTime? at}) async {
    await _storage.write(
      lastActiveKey,
      (at ?? DateTime.now()).toUtc().toIso8601String(),
    );
  }

  Future<bool> shouldLock() async {
    final enabled = await _storage.readBool(appLockKey);
    if (!enabled) return false;

    final timeout = await getTimeout();
    if (timeout == SessionTimeoutOption.never) return false;
    if (timeout == SessionTimeoutOption.immediately) return true;

    final rawLastActive = await _storage.read(lastActiveKey);
    final lastActive = DateTime.tryParse(rawLastActive ?? '');
    if (lastActive == null) return false;

    final elapsed = DateTime.now().toUtc().difference(lastActive.toUtc());
    return elapsed.inMinutes >= timeout.minutes;
  }
}
