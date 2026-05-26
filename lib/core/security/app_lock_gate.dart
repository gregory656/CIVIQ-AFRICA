import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import 'app_lock_service.dart';
import 'pin_service.dart';
import 'pin_keypad.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLockServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = ref.read(appLockServiceProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      service.onPaused();
    }
    if (state == AppLifecycleState.resumed) {
      service.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockServiceProvider);
    return Stack(
      children: [
        widget.child,
        if (lock.initialized && lock.locked)
          const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String? _error;
  bool _busy = false;
  int _resetToken = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 54,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 18),
                  PinKeypad(
                    title: 'Enter SIVIQ PIN',
                    errorText: _error,
                    resetToken: _resetToken,
                    onCompleted: _unlockWithPin,
                    onCancel: _cancelPinEntry,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint_outlined),
                    label: const Text('Use fingerprint'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _showForgotPinHelp,
                    child: const Text('Forgot PIN?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _unlockWithPin(String pin) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(appLockServiceProvider).unlockWithPin(pin);
    if (!mounted) return ok;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Incorrect PIN';
    });
    return ok;
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(appLockServiceProvider).unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Biometric unlock is not available.';
    });
  }

  void _cancelPinEntry() {
    setState(() {
      _error = null;
      _resetToken++;
    });
  }

  Future<void> _showForgotPinHelp() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'Sign in again to reset your PIN.');
      return;
    }

    final password = await _requestPassword(email);
    if (password == null || password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      await ref.read(pinServiceProvider).clearPin();
      final pin = await _requestPin('Create new SIVIQ PIN');
      if (pin == null) return;
      final policyError = ref.read(pinServiceProvider).validatePinPolicy(pin);
      if (policyError != null) {
        setState(() => _error = policyError);
        return;
      }
      final confirm = await _requestPin('Confirm new SIVIQ PIN');
      if (confirm != pin) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
      await ref.read(pinServiceProvider).savePin(pin);
      await ref
          .read(notificationRepositoryProvider)
          .createSecurityPinResetNotification(user.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      await ref.read(appLockServiceProvider).unlockWithPin(pin);
    } catch (error) {
      if (mounted) setState(() => _error = 'Reset failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestPassword(String email) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reauthenticate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password for ${_maskEmail(email)}',
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _requestPin(String title) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 340,
          child: PinKeypad(
            title: title,
            onCancel: () => Navigator.of(context).pop(),
            onCompleted: (pin) async {
              Navigator.of(context).pop(pin);
              return true;
            },
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return 'this account';
    final local = parts.first;
    final visible = local.length <= 4 ? local[0] : local.substring(0, 4);
    return '$visible***@${parts.last}';
  }
}
