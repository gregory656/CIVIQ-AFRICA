import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/project_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final CiviqProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Report')),
      body: ListView(
        children: [
          if (project.imageUrl?.isNotEmpty == true)
            CachedNetworkImage(
              imageUrl: project.imageUrl!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
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
                Text(
                  project.description?.trim().isNotEmpty == true
                      ? project.description!
                      : 'No description provided.',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _VoteButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: project.approvalCount.toString(),
                      onPressed: () => _vote(context, ref, true),
                    ),
                    const SizedBox(width: 10),
                    _VoteButton(
                      icon: Icons.thumb_down_alt_outlined,
                      label: project.disapprovalCount.toString(),
                      onPressed: () => _vote(context, ref, false),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: '${project.title} on CIVIQ Africa'),
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
    );
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    bool isApproval,
  ) async {
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
    await ref.read(projectRepositoryProvider).reportProject(project.id, reason);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted')));
    }
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
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
