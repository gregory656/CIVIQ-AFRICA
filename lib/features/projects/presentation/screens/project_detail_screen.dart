import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../data/project_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final CiviqProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = project.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Project Report')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              SizedBox(
                height: 320,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.background,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 52,
                      color: AppColors.grey,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                color: AppColors.background,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 52,
                  color: AppColors.grey,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadge(type: project.projectType),
                  const SizedBox(height: 10),
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                          project.countyName,
                          project.subcountyName,
                          project.locationName,
                        ]
                        .whereType<String>()
                        .where((item) => item.isNotEmpty)
                        .join(' - '),
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LinkifiedText(
                    text: project.description?.trim().isNotEmpty == true
                        ? project.description!
                        : 'No description provided.',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _VoteButton(
                        icon: Icons.thumb_up_alt_outlined,
                        count: project.approvalCount,
                        label: 'Approve',
                        color: AppColors.primaryGreen,
                        onPressed: () => _vote(context, ref, true),
                      ),
                      const SizedBox(width: 10),
                      _VoteButton(
                        icon: Icons.thumb_down_alt_outlined,
                        count: project.disapprovalCount,
                        label: 'Disapprove',
                        color: AppColors.dangerRed,
                        onPressed: () => _vote(context, ref, false),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: '${project.title} on SIVIQ'),
                        ),
                        icon: const Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        tooltip: 'Report',
                        onPressed: () => _report(context, ref),
                        icon: const Icon(Icons.flag_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    bool isApproval,
  ) async {
    try {
      await ref
          .read(projectRepositoryProvider)
          .voteProject(project.id, isApproval);
      ref.invalidate(projectsProvider);
      ref.invalidate(localProjectFeedProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vote recorded')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(error, fallback: 'Could not record vote.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report project'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .reportProject(project.id, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report submitted')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                error,
                fallback: 'Could not report project.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(foregroundColor: color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(count.toString(), style: TextStyle(color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'completed' || 'excellent' => AppColors.success,
      'stalled' => AppColors.dangerRed,
      _ => AppColors.warning,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(type.replaceAll('_', ' ').toUpperCase()),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      side: BorderSide.none,
    );
  }
}
