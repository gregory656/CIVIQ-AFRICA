import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../../features/auth/data/auth_repository.dart';
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
                              ? '@${profile.username}'
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
                const SizedBox(height: 12),
                _PublicStats(profile: profile),
                const SizedBox(height: 18),
                _FollowBackButton(profileId: profile.id),
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

class _FollowBackButton extends ConsumerStatefulWidget {
  const _FollowBackButton({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends ConsumerState<_FollowBackButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentAuthUserIdProvider);
    if (currentUserId == null || currentUserId == widget.profileId) {
      return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(isFollowingProvider(widget.profileId));
    return isFollowing.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Could not load follow state: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.dangerRed),
      ),
      data: (following) => FilledButton.icon(
        onPressed: _saving || following ? null : _follow,
        icon: Icon(following ? Icons.check : Icons.person_add_alt_1_outlined),
        label: Text(
          _saving
              ? 'Following...'
              : following
              ? 'Following'
              : 'Follow back',
        ),
      ),
    );
  }

  Future<void> _follow() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).followProfile(widget.profileId);
      ref.invalidate(isFollowingProvider(widget.profileId));
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
}

class _PublicStats extends StatelessWidget {
  const _PublicStats({required this.profile});

  final CiviqProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stat(label: 'Following', count: profile.followingCount),
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: AppColors.border,
        ),
        _Stat(label: 'Followers', count: profile.followersCount),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.grey)),
      ],
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
