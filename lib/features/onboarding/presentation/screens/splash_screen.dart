import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../profile/data/profile_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fall;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _fall = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    unawaited(_routeAfterSplash());
  }

  Future<void> _routeAfterSplash() async {
    final session = ref.read(authRepositoryProvider).currentSession;
    final profileFuture = session == null
        ? Future.value(null)
        : ref
              .read(currentProfileProvider.future)
              .timeout(
                const Duration(milliseconds: 2500),
                onTimeout: () => null,
              )
              .catchError((_) => null);

    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final profile = await profileFuture;
    if (!mounted) return;

    _restoreSystemUi();
    if (profile?.isRestricted ?? false) {
      context.go('/settings/account-status');
      return;
    }
    context.go(session == null ? '/intro' : '/home');
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _restoreSystemUi();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, -24 + (24 * _fall.value)),
              child: child,
            ),
          );
        },
        child: SizedBox.expand(
          child: Image.asset(AppAssets.splashScreen, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
