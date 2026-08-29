import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
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
  late final Animation<double> _scale;
  late final Animation<double> _turn;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _scale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: .72, end: 1.04), weight: 72),
        TweenSequenceItem(tween: Tween(begin: 1.04, end: 1), weight: 28),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _turn = Tween<double>(
      begin: -.16,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.splashScreen, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .82),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .001)
                      ..rotateY(_turn.value)
                      ..scale(_scale.value),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: .22),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Image.asset(AppAssets.appIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
