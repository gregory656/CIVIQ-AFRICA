import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/confirmation_popup.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/social_post_repository.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(socialHomeFeedProvider);
    return Column(
      children: [
        TabBar(
          controller: _controller,
          labelColor: AppColors.primaryGreen,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Trending'),
            Tab(text: 'Following'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              _SocialFeedList(posts: feed),
              _SocialFeedList(posts: feed, trending: true),
              const _FollowingPlaceholder(),
            ],
          ),
        ),
      ],
    );
  }
}

class CreateSocialPostScreen extends ConsumerStatefulWidget {
  const CreateSocialPostScreen({super.key});

  @override
  ConsumerState<CreateSocialPostScreen> createState() =>
      _CreateSocialPostScreenState();
}

class _CreateSocialPostScreenState
    extends ConsumerState<CreateSocialPostScreen> {
  final _bodyController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What should people discuss?',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.forum_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_image == null ? 'Add image' : 'Change image'),
          ),
          if (_image != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_image!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _posting ? null : _submit,
            icon: _posting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_posting ? 'Posting...' : 'Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image != null) setState(() => _image = image);
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _image == null) {
      setState(() => _error = 'Write something meaningful or add an image.');
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadMedia(File(_image!.path), folder: 'siviq/social-posts');
      }
      await ref
          .read(socialPostRepositoryProvider)
          .createPost(body: body, imageUrl: imageUrl);
      ref.invalidate(socialHomeFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

class _SocialFeedList extends ConsumerWidget {
  const _SocialFeedList({required this.posts, this.trending = false});

  final AsyncValue<List<SocialPost>> posts;
  final bool trending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load feed: $error')),
      data: (items) {
        final sorted = [...items];
        if (trending) {
          sorted.sort(
            (a, b) => (b.likeCount + b.commentCount + b.shareCount).compareTo(
              a.likeCount + a.commentCount + a.shareCount,
            ),
          );
        }
        if (sorted.isEmpty) return const _EmptyFeed();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(socialHomeFeedProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return SocialPostCard(post: sorted[index]);
            },
          ),
        );
      },
    );
  }
}

class SocialPostCard extends ConsumerStatefulWidget {
  const SocialPostCard({super.key, required this.post});

  final SocialPost post;

  @override
  ConsumerState<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends ConsumerState<SocialPostCard> {
  final _captureKey = GlobalKey();
  bool _showWatermarkForCapture = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    final isOwner = currentUserId != null && currentUserId == post.authorId;
    return RepaintBoundary(
      key: _captureKey,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openExpandedPost,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Avatar(url: post.authorAvatarUrl),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          post.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (post.authorIsVerified) ...[
                                        const SizedBox(width: 4),
                                        const CiviqVerifiedBadge(size: 15),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    _timeAgo(post.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'More',
                              onPressed: () =>
                                  _showPostActions(isOwner: isOwner),
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (post.body.isNotEmpty)
                          Text(post.body, style: const TextStyle(fontSize: 15)),
                        if (post.imageUrl?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: post.imageUrl!,
                              width: double.infinity,
                              height: 260,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InteractionButton(
                          icon: post.viewerHasLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: post.likeCount.toString(),
                          color: post.viewerHasLiked
                              ? AppColors.dangerRed
                              : AppColors.black,
                          onTap: _toggleLike,
                        ),
                      ),
                      Expanded(
                        child: _InteractionButton(
                          icon: Icons.chat_bubble_outline,
                          label: post.commentCount.toString(),
                          onTap: _openComments,
                        ),
                      ),
                      Expanded(
                        child: _InteractionButton(
                          icon: Icons.ios_share_outlined,
                          label: post.shareCount == 0
                              ? 'Share'
                              : post.shareCount.toString(),
                          onTap: _share,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  _OpenCommentBox(onTap: _openComments),
                ],
              ),
            ),
          ),
          if (_showWatermarkForCapture)
            const Positioned(right: 14, bottom: 12, child: _WatermarkPill()),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    await ref.read(socialPostRepositoryProvider).toggleLike(widget.post.id);
    ref.invalidate(socialHomeFeedProvider);
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: '${widget.post.body}\n\nShared from SIVIQ'),
    );
    await ref.read(socialPostRepositoryProvider).recordShare(widget.post.id);
    ref.invalidate(socialHomeFeedProvider);
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SocialCommentsSheet(post: widget.post),
    );
    ref.invalidate(socialHomeFeedProvider);
  }

  Future<void> _showPostActions({required bool isOwner}) async {
    final action = await _showCenteredPostActions(
      context: context,
      isOwner: isOwner,
    );
    if (!mounted) return;
    if (action == 'save') await _saveWatermarkedPost();
    if (action == 'edit') await _editPost();
    if (action == 'delete') await _deletePost();
  }

  void _openExpandedPost() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SocialPostDetailScreen(post: widget.post),
      ),
    );
  }

  Future<void> _saveWatermarkedPost() async {
    try {
      setState(() => _showWatermarkForCapture = true);
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Post is not ready to save.');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Could not render post image.');
      final imageBytes = bytes.buffer.asUint8List();
      await _saveToGalleryOrFile(imageBytes);
      if (!mounted) return;
      await showConfirmationPopup(
        context,
        message: 'Photo saved to device',
        label: 'Saved',
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is GalException
          ? _gallerySaveError(error)
          : 'Could not save post: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _showWatermarkForCapture = false);
    }
  }

  Future<String?> _saveToGalleryOrFile(Uint8List imageBytes) async {
    try {
      var hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess(toAlbum: true);
      }
      if (!hasAccess) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow photo access to save posts to your device.'),
          ),
        );
        return null;
      }
      await Gal.putImageBytes(
        imageBytes,
        album: 'SIVIQ',
        name: 'siviq-post-${widget.post.id}',
      );
      return null;
    } on MissingPluginException {
      return _saveImageFileToDevice(imageBytes);
    } on UnimplementedError {
      return _saveImageFileToDevice(imageBytes);
    }
  }

  Future<String> _saveImageFileToDevice(Uint8List imageBytes) async {
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}siviq-post-${widget.post.id}.png';
    await File(path).writeAsBytes(imageBytes, flush: true);
    return path;
  }

  String _gallerySaveError(GalException error) {
    return switch (error.type) {
      GalExceptionType.accessDenied =>
        'Allow photo access to save posts to your device.',
      GalExceptionType.notEnoughSpace =>
        'Not enough storage to save this post.',
      GalExceptionType.notSupportedFormat =>
        'This image format could not be saved.',
      GalExceptionType.unexpected =>
        'Could not save post to device. Please try again.',
    };
  }

  Future<void> _editPost() async {
    final controller = TextEditingController(text: widget.post.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Post'),
        ),
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
    await ref
        .read(socialPostRepositoryProvider)
        .updatePost(widget.post.id, body);
    ref.invalidate(socialHomeFeedProvider);
  }

  Future<void> _deletePost() async {
    await ref.read(socialPostRepositoryProvider).deletePost(widget.post.id);
    ref.invalidate(socialHomeFeedProvider);
  }
}

class SocialPostDetailScreen extends StatelessWidget {
  const SocialPostDetailScreen({super.key, required this.post});

  final SocialPost post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                _Avatar(url: post.authorAvatarUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (post.authorIsVerified) ...[
                            const SizedBox(width: 4),
                            const CiviqVerifiedBadge(size: 15),
                          ],
                        ],
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                post.body,
                style: const TextStyle(fontSize: 16, height: 1.42),
              ),
            ],
            if (post.imageUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WatermarkPill extends StatelessWidget {
  const _WatermarkPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'SIVIQ',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

Future<String?> _showCenteredPostActions({
  required BuildContext context,
  required bool isOwner,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Post actions',
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
                          'Post actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Save to device'),
                      onTap: () => Navigator.of(dialogContext).pop('save'),
                    ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit post'),
                        onTap: () => Navigator.of(dialogContext).pop('edit'),
                      ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppColors.dangerRed,
                        ),
                        title: const Text(
                          'Delete post',
                          style: TextStyle(color: AppColors.dangerRed),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop('delete'),
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

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.black,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

class _OpenCommentBox extends StatelessWidget {
  const _OpenCommentBox({required this.onTap});

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
                'Add a comment...',
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

class SocialCommentsSheet extends ConsumerStatefulWidget {
  const SocialCommentsSheet({super.key, required this.post});

  final SocialPost post;

  @override
  ConsumerState<SocialCommentsSheet> createState() =>
      _SocialCommentsSheetState();
}

class _SocialCommentsSheetState extends ConsumerState<SocialCommentsSheet> {
  final _controller = TextEditingController();
  String? _replyToCommentId;
  String? _replyToName;
  bool _loading = true;
  bool _sending = false;
  List<SocialComment> _comments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comments = await ref
        .read(socialPostRepositoryProvider)
        .fetchComments(widget.post.id);
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
                      'Comments',
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
                      children: _threadedComments()
                          .map(
                            (item) => _SocialCommentTile(
                              comment: item.comment,
                              indent: item.depth * 18,
                              onReply: () => _replyTo(item.comment),
                              onChanged: _load,
                            ),
                          )
                          .toList(),
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

  List<_ThreadedSocialComment> _threadedComments() {
    final byParent = <String?, List<SocialComment>>{};
    for (final comment in _comments) {
      byParent.putIfAbsent(comment.parentCommentId, () => []).add(comment);
    }
    final result = <_ThreadedSocialComment>[];
    void visit(String? parentId, int depth) {
      for (final comment in byParent[parentId] ?? const <SocialComment>[]) {
        result.add(_ThreadedSocialComment(comment, depth));
        visit(comment.id, depth + 1);
      }
    }

    visit(null, 0);
    return result;
  }

  void _replyTo(SocialComment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToName = comment.displayName;
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(socialPostRepositoryProvider)
          .addComment(widget.post.id, body, parentCommentId: _replyToCommentId);
      _controller.clear();
      _replyToCommentId = null;
      _replyToName = null;
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ThreadedSocialComment {
  const _ThreadedSocialComment(this.comment, this.depth);

  final SocialComment comment;
  final int depth;
}

class _SocialCommentTile extends ConsumerWidget {
  const _SocialCommentTile({
    required this.comment,
    required this.indent,
    required this.onReply,
    required this.onChanged,
  });

  final SocialComment comment;
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
          _Avatar(url: comment.authorAvatarUrl),
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
                              _timeAgo(comment.createdAt),
                              style: const TextStyle(
                                color: AppColors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(comment.body),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(socialPostRepositoryProvider)
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
                            .read(socialPostRepositoryProvider)
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
                                .read(socialPostRepositoryProvider)
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
    await ref
        .read(socialPostRepositoryProvider)
        .updateComment(comment.id, body);
  }

  Future<void> _showCommentActions(
    BuildContext context,
    WidgetRef ref,
    bool isOwner,
  ) async {
    final action = await _showCenteredCommentActions(context, isOwner: isOwner);
    if (action == null) return;
    if (!context.mounted) return;
    switch (action) {
      case 'reply':
        onReply();
        break;
      case 'report':
        await ref.read(socialPostRepositoryProvider).reportComment(comment.id);
        break;
      case 'edit':
        await _editComment(context, ref);
        break;
      case 'delete':
        await ref.read(socialPostRepositoryProvider).deleteComment(comment.id);
        break;
    }
    await onChanged();
  }
}

Future<String?> _showCenteredCommentActions(
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

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.border,
        child: Icon(Icons.person_outline),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _FollowingPlaceholder extends StatelessWidget {
  const _FollowingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Following feed will show posts from profiles you follow.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grey),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 110),
        Icon(
          Icons.dynamic_feed_outlined,
          size: 62,
          color: AppColors.primaryGreen,
        ),
        SizedBox(height: 12),
        Text(
          'No posts yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${value.day}/${value.month}/${value.year}';
}
