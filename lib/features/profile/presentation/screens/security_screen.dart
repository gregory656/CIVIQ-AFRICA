import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/security/pin_service.dart';
import '../../../../core/security/pin_keypad.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/security/session_service.dart';
import '../../../../core/widgets/confirmation_popup.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/notifications/data/notification_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/security_repository.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  SessionTimeoutOption _timeout = SessionTimeoutOption.tenMinutes;
  bool _hasPin = false;
  bool _biometricsEnabled = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionServiceProvider);
    final pin = ref.read(pinServiceProvider);
    final storage = ref.read(secureStorageServiceProvider);
    final timeout = await session.getTimeout();
    final hasPin = await pin.hasPin();
    final biometricsEnabled = await storage.readBool('biometric_enabled');
    if (!mounted) return;
    setState(() {
      _timeout = timeout;
      _hasPin = hasPin;
      _biometricsEnabled = biometricsEnabled;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle('Account Information'),
              _SecurityTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _maskEmail(profile?.email ?? ''),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Session Timeout'),
              _ChoiceTile(
                icon: Icons.lock_clock_outlined,
                title: 'Require unlock after',
                value: '${_timeout.label} - ${_timeoutHelp(_timeout)}',
                onTap: _busy ? null : _chooseTimeout,
              ),
              _ChoiceTile(
                icon: Icons.history_outlined,
                title: 'Security Activity',
                value: 'Sensitive account events',
                onTap: () => context.push('/settings/security/activity'),
              ),
              _ChoiceTile(
                icon: Icons.devices_outlined,
                title: 'Devices',
                value: 'Trusted and previous devices',
                onTap: () => context.push('/settings/security/devices'),
              ),
              _ChoiceTile(
                icon: Icons.laptop_mac_outlined,
                title: 'Active Sessions',
                value: 'Current and other sessions',
                onTap: () => context.push('/settings/security/sessions'),
              ),
              const SizedBox(height: 20),
              _SectionTitle('App Lock'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.pin_outlined,
                  color: AppColors.primaryGreen,
                ),
                title: const Text('4-digit PIN'),
                subtitle: Text(_hasPin ? 'Enabled' : 'Required for app lock'),
                value: _hasPin,
                onChanged: _busy
                    ? null
                    : (value) => value ? _setupPin() : _disablePin(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.fingerprint_outlined,
                  color: AppColors.primaryGreen,
                ),
                title: const Text('Biometrics'),
                subtitle: Text(
                  _hasPin
                      ? 'OS fingerprint or face unlock with PIN fallback'
                      : 'Enable a PIN first',
                ),
                value: _biometricsEnabled,
                onChanged: !_hasPin || _busy
                    ? null
                    : (value) => _setBiometrics(value),
              ),
              OutlinedButton.icon(
                onPressed: _hasPin && !_busy ? _lockNow : null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock now'),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Recovery'),
              _ChoiceTile(
                icon: Icons.restart_alt_outlined,
                title: 'PIN reset',
                value: 'Requires account password',
                onTap: _hasPin && !_busy ? _resetPin : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTimeout() async {
    final selected = await showModalBottomSheet<SessionTimeoutOption>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in SessionTimeoutOption.values)
              ListTile(
                leading: Icon(
                  option == _timeout
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.primaryGreen,
                ),
                title: Text(option.label),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(sessionServiceProvider).setTimeout(selected);
    setState(() => _timeout = selected);
  }

  Future<void> _setupPin() async {
    final first = await _requestPin(title: 'Create CIVIQ PIN');
    if (first == null) return;
    final error = ref.read(pinServiceProvider).validatePinPolicy(first);
    if (error != null) {
      _snack(error);
      return;
    }
    final confirm = await _requestPin(title: 'Confirm CIVIQ PIN');
    if (confirm == null) return;
    if (first != confirm) {
      _snack('PINs do not match.');
      return;
    }
    await ref.read(pinServiceProvider).savePin(first);
    await ref.read(sessionServiceProvider).markLastActive();
    await ref.read(securityRepositoryProvider).logSecurityEvent('pin_enabled');
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(securityEventsProvider);
    await _load();
    _confirmed('PIN enabled');
  }

  Future<void> _disablePin() async {
    final ok = await _confirm(
      'Disable app PIN?',
      'Biometrics will also turn off.',
    );
    if (!ok) return;
    await ref.read(pinServiceProvider).clearPin();
    await _load();
    _confirmed('PIN disabled');
  }

  Future<void> _setBiometrics(bool enabled) async {
    if (!enabled) {
      await ref
          .read(secureStorageServiceProvider)
          .writeBool('biometric_enabled', false);
      await _load();
      return;
    }
    final canUse = await ref.read(biometricServiceProvider).canUseBiometrics();
    if (!canUse) {
      _snack('Biometrics are not available on this device.');
      return;
    }
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Enable biometrics for CIVIQ Africa');
    if (!ok) return;
    await ref
        .read(secureStorageServiceProvider)
        .writeBool('biometric_enabled', true);
    await ref
        .read(securityRepositoryProvider)
        .logSecurityEvent('biometrics_enabled');
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(securityEventsProvider);
    await _load();
    _confirmed('Biometrics enabled');
  }

  Future<void> _resetPin() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final email = user?.email;
    if (user == null || email == null) return;

    final password = await _requestPassword(email);
    if (password == null || password.isEmpty) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      await ref
          .read(securityRepositoryProvider)
          .logSecurityEvent('password_reauthentication');
      await ref.read(pinServiceProvider).clearPin();
      final newPin = await _requestPin(title: 'Create new CIVIQ PIN');
      if (newPin == null) {
        await _load();
        return;
      }
      final error = ref.read(pinServiceProvider).validatePinPolicy(newPin);
      if (error != null) {
        _snack(error);
        await _load();
        return;
      }
      final confirm = await _requestPin(title: 'Confirm new CIVIQ PIN');
      if (confirm != newPin) {
        _snack('PINs do not match.');
        await _load();
        return;
      }
      await ref.read(pinServiceProvider).savePin(newPin);
      await ref.read(securityRepositoryProvider).logSecurityEvent('pin_reset');
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(securityEventsProvider);
      await _load();
      _confirmed('PIN reset confirmed');
    } catch (error) {
      _snack('Reauthentication failed: $error');
    }
  }

  Future<void> _lockNow() => ref.read(appLockServiceProvider).lockNow();

  String _timeoutHelp(SessionTimeoutOption option) {
    return switch (option) {
      SessionTimeoutOption.never => 'app will not locally lock',
      SessionTimeoutOption.immediately => 'locks when backgrounded',
      SessionTimeoutOption.fiveMinutes ||
      SessionTimeoutOption.tenMinutes ||
      SessionTimeoutOption.thirtyMinutes => 'locks after inactivity',
    };
  }

  Future<String?> _requestPin({required String title}) async {
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

  Future<String?> _requestPassword(String email) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reauthenticate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Confirm the password for ${_maskEmail(email)}.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
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

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmed(String message) async {
    await showConfirmationPopup(context, message: message);
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return 'Not available';
    final local = parts.first;
    final visible = local.length <= 4 ? local[0] : local.substring(0, 4);
    return '$visible***@${parts.last}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
