import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../features/legal/data/legal_repository.dart';
import '../../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode,
    this.initialLegalAccepted = false,
  });

  final String? initialMode;
  final bool initialLegalAccepted;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _CatMood { idle, attentive, covered, curious, error, success }

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final AnimationController _introController;

  bool _isLogin = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedLegal = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialMode == 'login';
    _acceptedLegal = widget.initialLegalAccepted;
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _emailFocus.addListener(_handleFocusChange);
    _passwordFocus.addListener(_handleFocusChange);
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_acceptedLegal) {
      setState(
        () => _error = 'Accept the legal terms before creating an account.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _success = false;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isLogin) {
        final response = await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        ref.read(currentAuthUserIdProvider.notifier).state = response.user?.id;
      } else {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final userId = response.user?.id ?? auth.currentUser?.id;
        ref.read(currentAuthUserIdProvider.notifier).state = userId;
        if (userId != null) {
          await ref
              .read(legalRepositoryProvider)
              .recordSignupAcceptances(userId);
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted) return;
      context.go(_isLogin ? '/home' : '/profile-setup');
    } catch (error) {
      setState(() {
        _error = friendlyErrorMessage(
          error,
          fallback: _isLogin
              ? 'We could not sign you in. Please try again.'
              : 'We could not create your account. Please try again.',
        );
        _loading = false;
      });
    }
  }

  void _switchMode(bool login) {
    if (_isLogin == login || _loading) return;
    setState(() {
      _isLogin = login;
      _error = null;
      _success = false;
    });
  }

  _CatMood get _catMood {
    if (_success) return _CatMood.success;
    if (_error != null) return _CatMood.error;
    if (_passwordFocus.hasFocus && _obscurePassword) return _CatMood.covered;
    if (_passwordFocus.hasFocus && !_obscurePassword) return _CatMood.curious;
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) {
      return _CatMood.attentive;
    }
    return _CatMood.idle;
  }

  int get _passwordScore {
    final value = _passwordController.text;
    var score = 0;
    if (value.length >= 6) score++;
    if (value.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(value) ||
        RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      score++;
    }
    return score.clamp(0, 4);
  }

  String get _strengthLabel {
    final score = _passwordScore;
    if (score <= 1) return 'Weak';
    if (score == 2) return 'Fair';
    if (score == 3) return 'Strong';
    return 'Excellent';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F8F4)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset * 0.12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(0, .42, curve: Curves.easeOut),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/intro'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        const BrandMark(size: 34),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(
                      .08,
                      .58,
                      curve: Curves.easeOutCubic,
                    ),
                    child: Center(child: _CivicHero(mood: _catMood)),
                  ),
                  const SizedBox(height: 18),
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(
                      .18,
                      .68,
                      curve: Curves.easeOutCubic,
                    ),
                    offset: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin ? 'Welcome back' : 'Create your account',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Stay connected to what matters in your community.'
                              : 'Join SIVIQ and follow the projects, voices, and updates that shape your community.',
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 15,
                            height: 1.38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(
                      .28,
                      .74,
                      curve: Curves.easeOutCubic,
                    ),
                    child: _SegmentedAuthSwitch(
                      isLogin: _isLogin,
                      onChanged: _switchMode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(
                      .38,
                      .82,
                      curve: Curves.easeOutCubic,
                    ),
                    offset: 14,
                    child: Column(
                      children: [
                        _AuthField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          label: 'Email address',
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (!RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                            ).hasMatch(text)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _AuthField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    key: ValueKey(_obscurePassword),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Use at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            Positioned(
                              right: 14,
                              top: -40,
                              child: _PasswordCat(mood: _catMood),
                            ),
                          ],
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _passwordController.text.isEmpty
                              ? const SizedBox(height: 8)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _PasswordStrength(
                                    score: _passwordScore,
                                    label: _strengthLabel,
                                  ),
                                ),
                        ),
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : () {},
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _acceptedLegal,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primaryGreen,
                            onChanged: _loading
                                ? null
                                : (value) => setState(
                                    () => _acceptedLegal = value ?? false,
                                  ),
                            title: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('I agree to the '),
                                _InlineLegalLink(
                                  label: 'Terms',
                                  route: '/legal/terms',
                                ),
                                const Text(', '),
                                _InlineLegalLink(
                                  label: 'Privacy Policy',
                                  route: '/legal/privacy-policy',
                                ),
                                const Text(', and '),
                                _InlineLegalLink(
                                  label: 'Community Guidelines',
                                  route: '/legal/community-guidelines',
                                ),
                                const Text('.'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _error == null
                        ? const SizedBox(height: 8)
                        : Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.dangerRed.withValues(
                                  alpha: .18,
                                ),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.dangerRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _AnimatedEntrance(
                    controller: _introController,
                    interval: const Interval(
                      .52,
                      .96,
                      curve: Curves.easeOutCubic,
                    ),
                    offset: 14,
                    child: FilledButton(
                      onPressed: _loading || (!_isLogin && !_acceptedLegal)
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: _loading ? 0 : 2,
                        shadowColor: AppColors.primaryGreen.withValues(
                          alpha: .25,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _loading
                            ? const SizedBox.square(
                                key: ValueKey('loading'),
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: AppColors.white,
                                ),
                              )
                            : _success
                            ? const Row(
                                key: ValueKey('success'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded),
                                  SizedBox(width: 8),
                                  Text('Welcome back'),
                                ],
                              )
                            : Text(
                                _isLogin ? 'Log in' : 'Create account',
                                key: ValueKey(_isLogin),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SocialAuthSection(isLogin: _isLogin),
                  const SizedBox(height: 14),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? "Don't have an account? "
                              : 'Already have an account? ',
                          style: const TextStyle(color: AppColors.grey),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(!_isLogin),
                          child: Text(
                            _isLogin ? 'Create one' : 'Log in',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({
    required this.controller,
    required this.interval,
    required this.child,
    this.offset = 0,
  });

  final AnimationController controller;
  final Curve interval;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final value = interval.transform(controller.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - value)),
            child: Transform.scale(scale: .96 + (.04 * value), child: child),
          ),
        );
      },
    );
  }
}

class _SegmentedAuthSwitch extends StatelessWidget {
  const _SegmentedAuthSwitch({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .5,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: .2),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _SegmentButton(
                active: isLogin,
                label: 'Login',
                onTap: () => onChanged(true),
              ),
              _SegmentButton(
                active: !isLogin,
                label: 'Create account',
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.active,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              color: active ? AppColors.white : AppColors.grey,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: .12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .035),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              icon,
              key: ValueKey(focused),
              color: focused ? AppColors.primaryGreen : AppColors.grey,
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: focused ? const Color(0xFFFBFFFC) : AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.dangerRed),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = score <= 1
        ? AppColors.dangerRed
        : score == 2
        ? AppColors.warning
        : score == 3
        ? AppColors.lightGreen
        : AppColors.primaryGreen;
    return Row(
      children: [
        const Text(
          'Password strength',
          style: TextStyle(
            color: AppColors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        ...List.generate(
          4,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: index < score ? color : AppColors.border,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialAuthSection extends StatelessWidget {
  const _SocialAuthSection({required this.isLogin});

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(color: AppColors.grey, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.black,
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(isLogin ? 'Continue with Google' : 'Sign up with Google'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CivicHero extends StatelessWidget {
  const _CivicHero({required this.mood});

  final _CatMood mood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      width: double.infinity,
      child: CustomPaint(painter: _CivicHeroPainter(mood)),
    );
  }
}

class _CivicHeroPainter extends CustomPainter {
  const _CivicHeroPainter(this.mood);

  final _CatMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = AppColors.primaryGreen;
    final mint = Paint()..color = const Color(0xFFDDF4E8);
    final pale = Paint()..color = const Color(0xFFF7FFFA);
    final charcoal = Paint()..color = AppColors.black;
    final stroke = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height * .55);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * .78, height: 118),
      mint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .18, 108, size.width * .64, 16),
        const Radius.circular(8),
      ),
      green,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .26, 64, size.width * .48, 52),
        const Radius.circular(12),
      ),
      pale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .39, 42, size.width * .22, 62),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFF17211D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .415, 48, size.width * .17, 50),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFE9FFF4),
    );

    canvas.drawCircle(
      Offset(size.width * .5, 34),
      25,
      Paint()..color = const Color(0xFFFFD8B6),
    );
    canvas.drawCircle(Offset(size.width * .49, 31), 2.2, charcoal);
    canvas.drawCircle(Offset(size.width * .515, 31), 2.2, charcoal);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .502, 39),
        width: 16,
        height: 8,
      ),
      0,
      3.14,
      false,
      Paint()
        ..color = AppColors.primaryGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawFloatingCard(canvas, Offset(size.width * .12, 32), _CivicGlyph.pin);
    _drawFloatingCard(canvas, Offset(size.width * .75, 36), _CivicGlyph.shield);
    _drawFloatingCard(
      canvas,
      Offset(size.width * .72, 100),
      _CivicGlyph.progress,
    );
    _drawFloatingCard(canvas, Offset(size.width * .15, 104), _CivicGlyph.chat);

    canvas.drawCircle(Offset(size.width * .24, 72), 4, green);
    canvas.drawCircle(Offset(size.width * .31, 52), 3, green);
    canvas.drawCircle(Offset(size.width * .75, 78), 4, green);
    canvas.drawLine(
      Offset(size.width * .24, 72),
      Offset(size.width * .31, 52),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .31, 52),
      Offset(size.width * .75, 78),
      stroke,
    );
    if (mood == _CatMood.success) {
      canvas.drawCircle(
        Offset(size.width * .62, 28),
        14,
        Paint()..color = AppColors.success.withValues(alpha: .18),
      );
    }
  }

  void _drawFloatingCard(Canvas canvas, Offset offset, _CivicGlyph glyph) {
    final rect = Rect.fromLTWH(offset.dx, offset.dy, 42, 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = AppColors.white.withValues(alpha: .86),
    );
    final paint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cx = offset.dx + 21;
    final cy = offset.dy + 16;
    switch (glyph) {
      case _CivicGlyph.pin:
        canvas.drawCircle(Offset(cx, cy - 3), 5, paint);
        canvas.drawLine(Offset(cx, cy + 2), Offset(cx, cy + 9), paint);
        break;
      case _CivicGlyph.shield:
        final path = Path()
          ..moveTo(cx, cy - 10)
          ..lineTo(cx + 10, cy - 6)
          ..quadraticBezierTo(cx + 8, cy + 8, cx, cy + 11)
          ..quadraticBezierTo(cx - 8, cy + 8, cx - 10, cy - 6)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(Offset(cx - 4, cy), Offset(cx - 1, cy + 3), paint);
        canvas.drawLine(Offset(cx - 1, cy + 3), Offset(cx + 5, cy - 4), paint);
        break;
      case _CivicGlyph.progress:
        canvas.drawLine(Offset(cx - 9, cy + 7), Offset(cx - 3, cy + 1), paint);
        canvas.drawLine(Offset(cx - 3, cy + 1), Offset(cx + 2, cy + 4), paint);
        canvas.drawLine(Offset(cx + 2, cy + 4), Offset(cx + 9, cy - 8), paint);
        break;
      case _CivicGlyph.chat:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy - 1), width: 23, height: 16),
            const Radius.circular(6),
          ),
          paint,
        );
        canvas.drawLine(Offset(cx - 2, cy + 7), Offset(cx - 7, cy + 12), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CivicHeroPainter oldDelegate) {
    return oldDelegate.mood != mood;
  }
}

enum _CivicGlyph { pin, shield, progress, chat }

class _PasswordCat extends StatelessWidget {
  const _PasswordCat({required this.mood});

  final _CatMood mood;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: mood == _CatMood.success ? 1.08 : 1,
      child: SizedBox(
        width: 70,
        height: 58,
        child: CustomPaint(painter: _CatPainter(mood)),
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  const _CatPainter(this.mood);

  final _CatMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final fur = Paint()..color = const Color(0xFFFFDFBD);
    final accent = Paint()..color = const Color(0xFFCD8C55);
    final ink = Paint()..color = AppColors.black;
    final green = Paint()..color = AppColors.primaryGreen;
    final head = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .54),
      width: 48,
      height: 42,
    );

    final leftEar = Path()
      ..moveTo(18, 24)
      ..lineTo(23, 4)
      ..lineTo(34, 24)
      ..close();
    final rightEar = Path()
      ..moveTo(36, 24)
      ..lineTo(48, 4)
      ..lineTo(52, 25)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(rightEar, fur);
    canvas.drawOval(head, fur);
    canvas.drawCircle(Offset(29, 31), 2.6, ink);
    canvas.drawCircle(Offset(43, 31), 2.6, ink);

    if (mood == _CatMood.covered) {
      _paw(canvas, const Offset(27, 31), true);
      _paw(canvas, const Offset(45, 31), false);
    } else {
      final eyeShift = mood == _CatMood.attentive
          ? -1.5
          : mood == _CatMood.curious
          ? 1.5
          : 0.0;
      final shine = Paint()..color = AppColors.white;
      canvas.drawCircle(Offset(29 + eyeShift, 31), 1.2, shine);
      canvas.drawCircle(Offset(43 + eyeShift, 31), 1.2, shine);
    }

    canvas.drawCircle(const Offset(36, 38), 2, accent);
    canvas.drawArc(
      const Rect.fromLTWH(28, 38, 16, 8),
      .15,
      2.85,
      false,
      Paint()
        ..color = mood == _CatMood.error
            ? AppColors.dangerRed
            : AppColors.primaryGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    if (mood == _CatMood.success) {
      canvas.drawCircle(const Offset(54, 16), 7, green);
      canvas.drawLine(
        const Offset(50, 16),
        const Offset(53, 19),
        Paint()
          ..color = AppColors.white
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(53, 19),
        const Offset(59, 13),
        Paint()
          ..color = AppColors.white
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paw(Canvas canvas, Offset center, bool left) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 15, height: 12),
      Paint()..color = const Color(0xFFFFC58F),
    );
  }

  @override
  bool shouldRepaint(covariant _CatPainter oldDelegate) {
    return oldDelegate.mood != mood;
  }
}

class _InlineLegalLink extends StatelessWidget {
  const _InlineLegalLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
