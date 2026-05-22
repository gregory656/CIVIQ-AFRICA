import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
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

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedLegal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialMode == 'login';
    _acceptedLegal = widget.initialLegalAccepted;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
      context.go(_isLogin ? '/home' : '/profile-setup');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const BrandMark(size: 48),
                const SizedBox(height: 42),
                Text(
                  _isLogin ? 'Welcome back' : 'Create your account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in with your email and password.'
                      : 'Start with email and password.Add OTP, biometrics, and 2FA  later.',
                  style: const TextStyle(color: AppColors.grey),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration:
                      const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
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
                if (!_isLogin) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acceptedLegal,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primaryGreen,
                    onChanged: _loading
                        ? null
                        : (value) =>
                              setState(() => _acceptedLegal = value ?? false),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('I agree to the '),
                        _InlineLegalLink(label: 'Terms', route: '/legal/terms'),
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
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.dangerRed),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading || (!_isLogin && !_acceptedLegal)
                      ? null
                      : _submit,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Login' : 'Create Account'),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        }),
                  child: Text(
                    _isLogin
                        ? 'New Here? Create An Account'
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
