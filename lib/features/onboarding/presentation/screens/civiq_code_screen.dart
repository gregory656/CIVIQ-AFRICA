import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';

class CiviqCodeScreen extends ConsumerStatefulWidget {
  const CiviqCodeScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<CiviqCodeScreen> createState() => _CiviqCodeScreenState();
}

class _CiviqCodeScreenState extends ConsumerState<CiviqCodeScreen> {
  late String _code = widget.code;

  @override
  void initState() {
    super.initState();
    if (_code.isEmpty) {
      _code = ref.read(profileRepositoryProvider).generateCiviqCode();
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        ref
            .read(profileRepositoryProvider)
            .upsertProfile(
              userId: user.id,
              email: user.email ?? '',
              civiqCode: _code,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your CIVIQ Code')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.key_outlined,
                size: 72,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(height: 24),
              Text(
                _code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use this code to connect privately with others.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CIVIQ code copied')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/notifications-permission'),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
