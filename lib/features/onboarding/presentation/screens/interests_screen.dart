import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../monetization/data/monetization_repository.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final Set<String> _selectedIds = {};
  bool _saving = false;
  String? _error;

  Future<void> _continue() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      setState(() => _error = 'Your session has ended. Please sign in again.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(monetizationRepositoryProvider)
          .saveUserInterests(userId: user.id, interestIds: _selectedIds);
      if (mounted) context.go('/avatar-upload');
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorMessage(
            error,
            fallback: 'We could not save your interests. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interests = ref.watch(interestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize SIVIQ'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : () => context.go('/profile-setup'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What matters to you?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose up to five interests to personalize your experience. You can change these later.',
                style: TextStyle(color: AppColors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: interests.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      friendlyErrorMessage(
                        error,
                        fallback: 'Could not load interests. Please try again.',
                      ),
                      style: const TextStyle(color: AppColors.dangerRed),
                    ),
                  ),
                  data: (items) => SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: items
                          .map((interest) {
                            return FilterChip(
                              label: Text(interest.name),
                              selected: _selectedIds.contains(interest.id),
                              onSelected: _saving
                                  ? null
                                  : (selected) {
                                      if (selected &&
                                          _selectedIds.length >= 5) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Choose up to 5 interests.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        selected
                                            ? _selectedIds.add(interest.id)
                                            : _selectedIds.remove(interest.id);
                                      });
                                    },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.dangerRed),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _continue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(_saving ? 'Saving...' : 'Continue'),
              ),
              TextButton(
                onPressed: _saving ? null : _continue,
                child: const Center(child: Text('Skip for now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
