import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/locations/data/location_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../shared/models/kenya_location.dart';
import '../../data/project_repository.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIVIQ Projects'),
        actions: [
          IconButton(
            tooltip: 'Create project',
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProjectError(error: error),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(projectsProvider),
          child: items.isEmpty
              ? const _EmptyProjects()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return ProjectFeedCard(project: items[index]);
                  },
                ),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
    );
  }
}

class ProjectFeedCard extends ConsumerStatefulWidget {
  const ProjectFeedCard({super.key, required this.project});

  final CiviqProject project;

  @override
  ConsumerState<ProjectFeedCard> createState() => _ProjectFeedCardState();
}

class _ProjectFeedCardState extends ConsumerState<ProjectFeedCard> {
  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    final isOwner = currentUserId != null && currentUserId == project.creatorId;
    final imageUrl = project.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      project.countyName,
                      project.subcountyName,
                    ].whereType<String>().join(' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _CompactStatus(type: project.projectType),
                const SizedBox(width: 6),
                _VerificationBadge(status: project.verificationStatus),
                IconButton(
                  tooltip: 'Project actions',
                  onPressed: () => _showProjectActions(isOwner: isOwner),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 6),
            _ProjectReadMoreText(
              text: project.description?.trim().isNotEmpty == true
                  ? project.description!
                  : 'No description provided.',
            ),
            if (hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 250,
                      color: AppColors.background,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 250,
                    color: AppColors.background,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.grey,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _ProjectAction(
                  icon: Icons.thumb_up_alt_outlined,
                  count: project.approvalCount,
                  label: 'Approve',
                  color: AppColors.primaryGreen,
                  onTap: () => _vote(true),
                ),
                const SizedBox(width: 10),
                _ProjectAction(
                  icon: Icons.thumb_down_alt_outlined,
                  count: project.disapprovalCount,
                  label: 'Disapprove',
                  color: AppColors.dangerRed,
                  onTap: () => _vote(false),
                ),
                const Spacer(),
                _ProjectAction(
                  icon: Icons.chat_bubble_outline,
                  label: project.commentCount == 0
                      ? 'Comment'
                      : project.commentCount.toString(),
                  onTap: _openComments,
                ),
              ],
            ),
            const Divider(height: 18),
            _OpenProjectCommentBox(onTap: _openComments),
          ],
        ),
      ),
    );
  }

  void _openDetail() {
    final project = widget.project;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(project: project),
      ),
    );
  }

  Future<void> _showProjectActions({required bool isOwner}) async {
    final action = await _showCenteredProjectActions(context, isOwner: isOwner);
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        if (mounted) _openDetail();
        break;
      case 'share':
        await SharePlus.instance.share(
          ShareParams(text: '${widget.project.title} on SIVIQ'),
        );
        break;
      case 'report':
        await _reportProject();
        break;
      case 'hide':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Project hidden')));
        break;
      case 'edit':
        await _editProject();
        break;
      case 'delete':
        await _deleteProject();
        break;
    }
  }

  Future<void> _reportProject() async {
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
          .reportProject(widget.project.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, fallback: 'Could not report project.'),
          ),
        ),
      );
    }
  }

  Future<void> _vote(bool isApproval) async {
    await ref
        .read(projectRepositoryProvider)
        .voteProject(widget.project.id, isApproval);
    ref.invalidate(projectsProvider);
  }

  Future<void> _editProject() async {
    final titleController = TextEditingController(text: widget.project.title);
    final descriptionController = TextEditingController(
      text: widget.project.description ?? '',
    );
    var type = widget.project.projectType;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ongoing', label: Text('Ongoing')),
                    ButtonSegment(value: 'completed', label: Text('Done')),
                    ButtonSegment(value: 'stalled', label: Text('Stalled')),
                    ButtonSegment(value: 'excellent', label: Text('Excellent')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setDialogState(() => type = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (saved != true || title.isEmpty) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .updateProject(
            widget.project.id,
            CreateProjectInput(
              title: title,
              description: description,
              projectType: type,
              countyId: widget.project.countyId,
              subcountyId: widget.project.subcountyId,
              locationName: widget.project.locationName,
              imageUrl: widget.project.imageUrl,
              confirmedAccuracy: true,
            ),
          );
      ref.invalidate(projectsProvider);
      ref.invalidate(localProjectFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, fallback: 'Could not update project.'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text('This will remove the project post from SIVIQ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .deleteProject(widget.project.id);
      ref.invalidate(projectsProvider);
      ref.invalidate(localProjectFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, fallback: 'Could not delete project.'),
          ),
        ),
      );
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProjectCommentsSheet(project: widget.project),
    );
    ref.invalidate(projectsProvider);
  }
}

class _ProjectAction extends StatelessWidget {
  const _ProjectAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.color = AppColors.black,
  });

  final IconData icon;
  final int? count;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = count;
    if (value == null) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      );
    }

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 4),
              Text(value.toString(), style: TextStyle(color: color)),
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

class _ProjectReadMoreText extends StatefulWidget {
  const _ProjectReadMoreText({required this.text});

  final String text;

  @override
  State<_ProjectReadMoreText> createState() => _ProjectReadMoreTextState();
}

class _ProjectReadMoreTextState extends State<_ProjectReadMoreText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > 180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinkifiedText(
          text: widget.text,
          maxLines: _expanded || !isLong ? null : 4,
          overflow: _expanded || !isLong
              ? TextOverflow.clip
              : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        if (isLong)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final verified =
        status == 'community_verified' || status == 'officially_verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.primaryGreen.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: verified ? AppColors.primaryGreen : AppColors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Future<String?> _showCenteredProjectActions(
  BuildContext context, {
  required bool isOwner,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Project actions',
    barrierColor: AppColors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Material(
              color: AppColors.white,
              elevation: 10,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Project actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.open_in_full_outlined),
                      title: const Text('Open project'),
                      onTap: () => Navigator.of(dialogContext).pop('open'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.ios_share_outlined),
                      title: const Text('Share'),
                      onTap: () => Navigator.of(dialogContext).pop('share'),
                    ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit project'),
                        onTap: () => Navigator.of(dialogContext).pop('edit'),
                      ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppColors.dangerRed,
                        ),
                        title: const Text(
                          'Delete project',
                          style: TextStyle(color: AppColors.dangerRed),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop('delete'),
                      ),
                    if (!isOwner)
                      ListTile(
                        leading: const Icon(Icons.visibility_off_outlined),
                        title: const Text('Hide project'),
                        onTap: () => Navigator.of(dialogContext).pop('hide'),
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.flag_outlined,
                        color: AppColors.dangerRed,
                      ),
                      title: const Text(
                        'Report',
                        style: TextStyle(color: AppColors.dangerRed),
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('report'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _OpenProjectCommentBox extends StatelessWidget {
  const _OpenProjectCommentBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Write a comment...',
                style: TextStyle(color: AppColors.grey),
              ),
            ),
            Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

class ProjectCommentsSheet extends ConsumerStatefulWidget {
  const ProjectCommentsSheet({super.key, required this.project});

  final CiviqProject project;

  @override
  ConsumerState<ProjectCommentsSheet> createState() =>
      _ProjectCommentsSheetState();
}

class _ProjectCommentsSheetState extends ConsumerState<ProjectCommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToName;
  bool _loading = true;
  bool _sending = false;
  List<ProjectComment> _comments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comments = await ref
        .read(projectRepositoryProvider)
        .fetchComments(widget.project.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Project comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh comments',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(child: Text('No comments yet.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      children: _threadedComments().map((item) {
                        final parent = item.comment.parentCommentId == null
                            ? null
                            : _commentById()[item.comment.parentCommentId];
                        return _ProjectCommentTile(
                          comment: item.comment,
                          parentComment: parent,
                          depth: item.depth,
                          indent: item.depth * 18,
                          onReply: () => _replyTo(item.comment),
                          onChanged: _load,
                        );
                      }).toList(),
                    ),
            ),
            if (_replyToName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                color: AppColors.background,
                child: Row(
                  children: [
                    Expanded(child: Text('Replying to $_replyToName')),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: () => setState(() {
                        _replyToCommentId = null;
                        _replyToName = null;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _replyToName == null
                      ? 'Write a comment...'
                      : 'Write a reply...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ThreadedProjectComment> _threadedComments() {
    final byParent = <String?, List<ProjectComment>>{};
    for (final comment in _comments) {
      byParent.putIfAbsent(comment.parentCommentId, () => []).add(comment);
    }
    final result = <_ThreadedProjectComment>[];
    void visit(String? parentId, int depth) {
      for (final comment in byParent[parentId] ?? const <ProjectComment>[]) {
        result.add(_ThreadedProjectComment(comment, depth));
        visit(comment.id, depth + 1);
      }
    }

    visit(null, 0);
    return result;
  }

  Map<String, ProjectComment> _commentById() {
    return {for (final comment in _comments) comment.id: comment};
  }

  void _replyTo(ProjectComment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToName = comment.displayName;
    });
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(projectRepositoryProvider)
          .addComment(
            widget.project.id,
            body,
            parentCommentId: _replyToCommentId,
          );
      _controller.clear();
      _replyToCommentId = null;
      _replyToName = null;
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ThreadedProjectComment {
  const _ThreadedProjectComment(this.comment, this.depth);

  final ProjectComment comment;
  final int depth;
}

class _ProjectCommentTile extends ConsumerWidget {
  const _ProjectCommentTile({
    required this.comment,
    required this.parentComment,
    required this.depth,
    required this.indent,
    required this.onReply,
    required this.onChanged,
  });

  final ProjectComment comment;
  final ProjectComment? parentComment;
  final int depth;
  final double indent;
  final VoidCallback onReply;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    final isOwner = currentUserId != null && currentUserId == comment.authorId;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0)
            Container(
              width: 2,
              height: 74,
              margin: const EdgeInsets.only(right: 8, top: 2),
              color: AppColors.primaryGreen.withValues(alpha: 0.28),
            ),
          _SmallAvatar(url: comment.authorAvatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showCommentActions(context, ref, isOwner),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              _projectTimeAgo(comment.createdAt),
                              style: const TextStyle(
                                color: AppColors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (parentComment != null) ...[
                          const SizedBox(height: 7),
                          _ProjectCommentReplyLink(
                            username: parentComment!.displayName,
                            body: parentComment!.body,
                          ),
                        ],
                        const SizedBox(height: 4),
                        LinkifiedText(text: comment.body),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(projectRepositoryProvider)
                            .toggleCommentLike(comment.id);
                        await onChanged();
                      },
                      icon: Icon(
                        comment.viewerHasLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                      ),
                      label: Text(comment.likeCount.toString()),
                    ),
                    TextButton(onPressed: onReply, child: const Text('Reply')),
                    IconButton(
                      tooltip: 'Report',
                      onPressed: () async {
                        await ref
                            .read(projectRepositoryProvider)
                            .reportComment(comment.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment reported')),
                          );
                        }
                      },
                      icon: const Icon(Icons.flag_outlined, size: 18),
                    ),
                    if (isOwner)
                      PopupMenuButton<String>(
                        tooltip: 'Comment actions',
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _editComment(context, ref);
                          } else if (value == 'delete') {
                            await ref
                                .read(projectRepositoryProvider)
                                .deleteComment(comment.id);
                          }
                          await onChanged();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
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

  Future<void> _editComment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: comment.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: controller, minLines: 3, maxLines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    await ref.read(projectRepositoryProvider).updateComment(comment.id, body);
  }

  Future<void> _showCommentActions(
    BuildContext context,
    WidgetRef ref,
    bool isOwner,
  ) async {
    final action = await _showCenteredProjectCommentActions(
      context,
      isOwner: isOwner,
    );
    if (action == null) return;
    if (!context.mounted) return;
    switch (action) {
      case 'reply':
        onReply();
        break;
      case 'report':
        await ref.read(projectRepositoryProvider).reportComment(comment.id);
        break;
      case 'edit':
        await _editComment(context, ref);
        break;
      case 'delete':
        await ref.read(projectRepositoryProvider).deleteComment(comment.id);
        break;
    }
    await onChanged();
  }
}

class _ProjectCommentReplyLink extends StatelessWidget {
  const _ProjectCommentReplyLink({required this.username, required this.body});

  final String username;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(7),
        border: const Border(
          left: BorderSide(color: AppColors.primaryGreen, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to $username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          LinkifiedText(
            text: body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showCenteredProjectCommentActions(
  BuildContext context, {
  required bool isOwner,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Comment actions',
    barrierColor: AppColors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Material(
              color: AppColors.white,
              elevation: 10,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reply),
                      title: const Text('Reply'),
                      onTap: () => Navigator.of(dialogContext).pop('reply'),
                    ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit'),
                        onTap: () => Navigator.of(dialogContext).pop('edit'),
                      ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppColors.dangerRed,
                        ),
                        title: const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.dangerRed),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop('delete'),
                      )
                    else
                      ListTile(
                        leading: const Icon(
                          Icons.report_gmailerrorred_outlined,
                          color: AppColors.dangerRed,
                        ),
                        title: const Text(
                          'Report spam',
                          style: TextStyle(color: AppColors.dangerRed),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop('report'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.border,
        child: Icon(Icons.person_outline, size: 18),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
      ),
    );
  }
}

String _projectTimeAgo(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${value.day}/${value.month}/${value.year}';
}

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  String _type = 'ongoing';
  KenyaCounty? _county;
  KenyaSubcounty? _subcounty;
  XFile? _image;
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final locations = ref.watch(governanceLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: locations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _form(context, kenyaCounties, profile),
        data: (counties) => _form(context, counties, profile),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    List<KenyaCounty> counties,
    CiviqProfile? profile,
  ) {
    _county ??= _findCounty(counties, profile?.countyId) ?? counties.first;
    _subcounty ??=
        _findSubcounty(_county, profile?.subcountyId) ??
        _county!.subcounties.first;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ongoing', label: Text('Ongoing')),
            ButtonSegment(value: 'completed', label: Text('Completed')),
            ButtonSegment(value: 'stalled', label: Text('Stalled')),
            ButtonSegment(value: 'excellent', label: Text('Excellent')),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() => _type = value.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            prefixIcon: Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Description',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 12),
        _ReadonlyPicker(
          label: 'County',
          value: _county?.name ?? '',
          icon: Icons.location_on_outlined,
          onTap: () async {
            final county = await _chooseCounty(context, counties);
            if (county == null) return;
            setState(() {
              _county = county;
              _subcounty = county.subcounties.first;
            });
          },
        ),
        const SizedBox(height: 12),
        _ReadonlyPicker(
          label: 'Sub-county / Constituency',
          value: _subcounty?.name ?? '',
          icon: Icons.map_outlined,
          onTap: () async {
            final subcounty = await _chooseSubcounty(
              context,
              _county?.subcounties ?? const [],
            );
            if (subcounty != null) setState(() => _subcounty = subcounty);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_image == null ? 'Add evidence image' : 'Change image'),
        ),
        if (_image != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_image!.path),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          onChanged: (value) => setState(() => _confirmed = value ?? false),
          title: const Text(
            'I confirm this information is accurate to my knowledge.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'Submitting SIVIQ report...' : 'Submit'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 72,
    );
    if (image != null) setState(() => _image = image);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a project title.');
      return;
    }
    if (!_confirmed) {
      setState(() => _error = 'Confirm the report accuracy before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadMedia(File(_image!.path), folder: 'siviq/projects');
      }
      await ref
          .read(projectRepositoryProvider)
          .createProject(
            CreateProjectInput(
              title: title,
              description: _descriptionController.text.trim(),
              projectType: _type,
              countyId: _county?.id,
              subcountyId: _subcounty?.id,
              locationName: _locationController.text.trim(),
              imageUrl: imageUrl,
              confirmedAccuracy: _confirmed,
            ),
          );
      ref.invalidate(projectsProvider);
      ref.invalidate(localProjectFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<KenyaCounty?> _chooseCounty(
    BuildContext context,
    List<KenyaCounty> counties,
  ) {
    return showModalBottomSheet<KenyaCounty>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: counties
            .map(
              (county) => ListTile(
                title: Text(county.name),
                subtitle: Text('${county.subcounties.length} constituencies'),
                onTap: () => Navigator.of(context).pop(county),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<KenyaSubcounty?> _chooseSubcounty(
    BuildContext context,
    List<KenyaSubcounty> subcounties,
  ) {
    return showModalBottomSheet<KenyaSubcounty>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: subcounties
            .map(
              (subcounty) => ListTile(
                title: Text(subcounty.name),
                subtitle: Text(
                  subcounty.mpName == null
                      ? 'MP details pending'
                      : 'MP: ${subcounty.mpName}',
                ),
                onTap: () => Navigator.of(context).pop(subcounty),
              ),
            )
            .toList(),
      ),
    );
  }

  KenyaCounty? _findCounty(List<KenyaCounty> counties, int? id) {
    if (id == null) return null;
    for (final county in counties) {
      if (county.id == id) return county;
    }
    return null;
  }

  KenyaSubcounty? _findSubcounty(KenyaCounty? county, int? id) {
    if (county == null || id == null) return null;
    for (final subcounty in county.subcounties) {
      if (subcounty.id == id) return subcounty;
    }
    return null;
  }
}

class _ReadonlyPicker extends StatelessWidget {
  const _ReadonlyPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.expand_more),
      ),
      onTap: onTap,
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'completed' || 'excellent' => AppColors.success,
      'stalled' => AppColors.dangerRed,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.work_outline, size: 62, color: AppColors.primaryGreen),
        SizedBox(height: 12),
        Text(
          'No project reports yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}

class _ProjectError extends StatelessWidget {
  const _ProjectError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          friendlyErrorMessage(error, fallback: 'Could not load projects.'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
