import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../chats/data/repositories/chat_repository.dart';
import '../../data/profile_repository.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(profileId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found.'));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(child: _PublicAvatar(url: profile.avatarUrl)),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          profile.username?.isNotEmpty == true
                              ? profile.primaryName
                              : 'SIVIQ Member',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 5),
                        CiviqVerifiedBadge(size: 17, role: profile.role),
                      ],
                    ],
                  ),
                ),
                if (profile.roleLabel?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.roleLabel!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  profile.handle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _PublicStats(profile: profile),
                const SizedBox(height: 18),
                _ProfileActions(profileId: profile.id),
                const SizedBox(height: 18),
                Text(
                  profile.bio?.isNotEmpty == true
                      ? profile.bio!
                      : 'No bio added yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileActions extends ConsumerStatefulWidget {
  const _ProfileActions({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends ConsumerState<_ProfileActions> {
  bool _saving = false;
  bool _openingChat = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    if (currentUserId == null || currentUserId == widget.profileId) {
      return const SizedBox.shrink();
    }

    final relationship = ref.watch(
      profileRelationshipProvider(widget.profileId),
    );
    return relationship.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Could not load follow state: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.dangerRed),
      ),
      data: (state) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          SizedBox(
            width: state.isFollowing ? 126 : 132,
            height: 40,
            child: state.isFollowing
                ? OutlinedButton.icon(
                    onPressed: _saving ? null : _unfollow,
                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_saving ? 'Saving...' : 'Unfollow'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _saving ? null : _follow,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : state.followsBack
                            ? 'Follow back'
                            : 'Follow',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
          ),
          SizedBox(
            width: 118,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _openingChat ? null : _openChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_openingChat ? 'Opening...' : 'Message'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _follow() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).followProfile(widget.profileId);
      ref.invalidate(profileRelationshipProvider(widget.profileId));
      ref.invalidate(publicProfileProvider(widget.profileId));
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not follow account: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unfollow() async {
    final currentUserId = ref.read(currentAuthUserIdProvider);
    if (currentUserId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .unfollowProfile(currentUserId, widget.profileId);
      ref.invalidate(profileRelationshipProvider(widget.profileId));
      ref.invalidate(publicProfileProvider(widget.profileId));
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unfollow account: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    try {
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .createDirectConversation(widget.profileId);
      if (mounted) context.push('/chats/$conversationId');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }
}

class _PublicStats extends StatelessWidget {
  const _PublicStats({required this.profile});

  final CiviqProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stat(
          label: 'Following',
          count: profile.followingCount,
          route: '/profile/${profile.id}/following',
        ),
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: AppColors.border,
        ),
        _Stat(
          label: 'Followers',
          count: profile.followersCount,
          route: '/profile/${profile.id}/followers',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.count, required this.route});

  final String label;
  final int count;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.border,
        child: Icon(Icons.person_outline, size: 42),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.border,
          child: Icon(Icons.person_outline, size: 42),
        ),
      ),
    );
  }
}
