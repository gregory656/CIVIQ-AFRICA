import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/security_repository.dart';

class SecurityActivityScreen extends ConsumerWidget {
  const SecurityActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(securityEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Security Activity')),
      body: SafeArea(
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load: $error')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No security activity yet.',
                  style: TextStyle(color: AppColors.grey),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(securityEventsProvider),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: Text(_eventLabel(item.eventType)),
                    subtitle: Text(_dateLabel(item.createdAt)),
                  );
                },
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemCount: items.length,
              ),
            );
          },
        ),
      ),
    );
  }

  String _eventLabel(String value) {
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
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
