import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/data/security_repository.dart';
import '../../data/export_repository.dart';

class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  bool _busy = false;
  String? _downloadUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.archive_outlined, color: AppColors.primaryGreen),
                  SizedBox(height: 12),
                  Text(
                    'Export My Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your archive includes profile.json, notifications.json, and posts.json when posts are available. Exports are limited to one request every 24 hours.',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _requestExport,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_busy ? 'Preparing export...' : 'Export My Data'),
            ),
            if (_downloadUrl != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                _downloadUrl!,
                style: const TextStyle(color: AppColors.primaryGreen),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Export History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final history = ref.watch(exportHistoryProvider);
                return history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load history: $error'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text(
                        'No exports requested yet.',
                        style: TextStyle(color: AppColors.grey),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items) _HistoryTile(request: item),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestExport() async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(exportRepositoryProvider).requestExport();
      if (!mounted) return;
      setState(() => _downloadUrl = url);
      ref.invalidate(exportHistoryProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export archive is ready.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not export: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request});

  final DataExportRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.history_outlined,
          color: AppColors.primaryGreen,
        ),
        title: Text(request.status.toUpperCase()),
        subtitle: Text(
          'Requested ${_dateLabel(request.requestedAt)}\n'
          'Completed ${_optionalDate(request.completedAt)} • '
          'Expires ${_optionalDate(request.expiresAt)}',
        ),
        isThreeLine: true,
      ),
    );
  }

  String _optionalDate(DateTime? value) {
    if (value == null) return 'pending';
    return _dateLabel(value);
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
