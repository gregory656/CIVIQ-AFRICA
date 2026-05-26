import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class PinKeypad extends StatefulWidget {
  const PinKeypad({
    required this.onCompleted,
    this.title = 'Enter SIVIQ PIN',
    this.errorText,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.resetToken,
    super.key,
  });

  final String title;
  final String? errorText;
  final Future<bool> Function(String pin) onCompleted;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final Object? resetToken;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  String _pin = '';
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PinKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _pin = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: index < _pin.length
                    ? AppColors.primaryGreen
                    : Colors.transparent,
                border: Border.all(
                  color: index < _pin.length
                      ? AppColors.primaryGreen
                      : AppColors.border,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: widget.errorText == null
              ? const SizedBox(height: 18)
              : Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    widget.errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.dangerRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _KeypadGrid(
          busy: _busy,
          onDigit: _addDigit,
          onBackspace: _backspace,
          onCancel: widget.onCancel,
          cancelLabel: widget.cancelLabel,
        ),
      ],
    );
  }

  Future<void> _addDigit(String digit) async {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length != 4) return;

    setState(() => _busy = true);
    final pin = _pin;
    final ok = await widget.onCompleted(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _pin = '';
    });
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.busy,
    required this.onDigit,
    required this.onBackspace,
    required this.onCancel,
    required this.cancelLabel,
  });

  final bool busy;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _DigitButton(
          label: digit,
          enabled: !busy,
          onPressed: () => onDigit(digit),
        ),
      _ActionButton(
        label: cancelLabel,
        enabled: !busy && onCancel != null,
        onPressed: onCancel,
      ),
      _DigitButton(label: '0', enabled: !busy, onPressed: () => onDigit('0')),
      _IconKeyButton(
        icon: Icons.backspace_outlined,
        enabled: !busy,
        onPressed: onBackspace,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: buttons,
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      enabled: enabled,
      onPressed: onPressed,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _IconKeyButton extends StatelessWidget {
  const _IconKeyButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      enabled: enabled,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 72,
        height: 72,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.black,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.grey,
          ),
          child: child,
        ),
      ),
    );
  }
}
