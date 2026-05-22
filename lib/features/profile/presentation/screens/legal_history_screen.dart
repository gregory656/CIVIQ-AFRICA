import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/security_repository.dart';

class LegalHistoryScreen extends ConsumerWidget {
  const LegalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(legalHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Legal History')),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load: $error')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No legal acceptances recorded yet.',
                  style: TextStyle(color: AppColors.grey),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(
                    Icons.gavel_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(_policyLabel(item.policyType)),
                  subtitle: Text(
                    'Version ${item.policyVersion} • ${_dateLabel(item.acceptedAt)}',
                  ),
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }

  String _policyLabel(String value) {
    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
