import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/profile_repository.dart';

enum SocialListType { followers, following }

final socialListProvider =
    FutureProvider.family<List<ProfileConnection>, SocialListRequest>((
      ref,
      request,
    ) async {
      final repository = ref.watch(profileRepositoryProvider);
      return switch (request.type) {
        SocialListType.followers => repository.followers(request.profileId),
        SocialListType.following => repository.following(request.profileId),
      };
    });

final followingScreenDataProvider =
    FutureProvider.family<FollowingScreenData, String>((ref, profileId) async {
      final repository = ref.watch(profileRepositoryProvider);
      final currentUserId = ref.watch(currentAuthUserIdProvider);
      final following = await repository.following(profileId).catchError((_) {
        return <ProfileConnection>[];
      });
      final discover = currentUserId == null
          ? <ProfileConnection>[]
          : await repository.discoverCiviqUsers(currentUserId);
      return FollowingScreenData(following: following, discover: discover);
    });

class SocialListRequest {
  const SocialListRequest({required this.profileId, required this.type});

  final String profileId;
  final SocialListType type;

  @override
  bool operator ==(Object other) {
    return other is SocialListRequest &&
        other.profileId == profileId &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(profileId, type);
}

class FollowingScreenData {
  const FollowingScreenData({required this.following, required this.discover});

  final List<ProfileConnection> following;
  final List<ProfileConnection> discover;
}

class SocialListScreen extends ConsumerWidget {
  const SocialListScreen({
    super.key,
    required this.profileId,
    required this.type,
  });

  final String profileId;
  final SocialListType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == SocialListType.following) {
      return _FollowingScreen(profileId: profileId);
    }
    return _FollowersScreen(profileId: profileId);
  }
}

class _FollowersScreen extends ConsumerWidget {
  const _FollowersScreen({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = SocialListRequest(
      profileId: profileId,
      type: SocialListType.followers,
    );
    final accounts = ref.watch(socialListProvider(request));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Followers')),
      body: SafeArea(
        child: accounts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _SocialListError(error: error),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const Center(child: Text('No followers yet.'));
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(socialListProvider(request)),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _ProfileConnectionTile(account: accounts[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FollowingScreen extends ConsumerWidget {
  const _FollowingScreen({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(followingScreenDataProvider(profileId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Following')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(followingScreenDataProvider(profileId)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const _LoadedMarker(title: 'Following'),
              data.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => _InlineError(error: error),
                data: (data) =>
                    _FollowingContent(data: data, profileId: profileId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowingContent extends StatelessWidget {
  const _FollowingContent({required this.data, required this.profileId});

  final FollowingScreenData data;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Following: ${data.following.length}  |  CIVIQ users: ${data.discover.length}',
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ...data.following.map(
          (account) => _ProfileConnectionTile(account: account),
        ),
        const _DiscoverHeader(),
        if (data.discover.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No other CIVIQ accounts are available yet.',
              style: TextStyle(color: AppColors.grey),
            ),
          )
        else
          ...data.discover.map(
            (account) => _ProfileConnectionTile(
              account: account,
              showFollowButton: true,
              refreshProfileId: profileId,
            ),
          ),
      ],
    );
  }
}

class _LoadedMarker extends StatelessWidget {
  const _LoadedMarker({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$title screen loaded',
        style: const TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Could not load accounts: $error',
        style: const TextStyle(color: AppColors.dangerRed),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Follow your fellow CIVIQ users',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 3),
          Text(
            'Browse all available CIVIQ profiles and follow the accounts you want to keep up with.',
            style: TextStyle(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _ProfileConnectionTile extends ConsumerStatefulWidget {
  const _ProfileConnectionTile({
    required this.account,
    this.showFollowButton = false,
    this.refreshProfileId,
  });

  final ProfileConnection account;
  final bool showFollowButton;
  final String? refreshProfileId;

  @override
  ConsumerState<_ProfileConnectionTile> createState() =>
      _ProfileConnectionTileState();
}

class _ProfileConnectionTileState
    extends ConsumerState<_ProfileConnectionTile> {
  bool _following = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final username = account.username?.isNotEmpty == true
        ? '@${account.username}'
        : 'CIVIQ Member';

    return ListTile(
      leading: _ConnectionAvatar(url: account.avatarUrl),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (account.isVerified) ...[
            const SizedBox(width: 5),
            const CiviqVerifiedBadge(size: 15),
          ],
        ],
      ),
      subtitle: Text(_subtitleFor(account)),
      trailing: widget.showFollowButton
          ? SizedBox(
              width: 98,
              height: 40,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A66C2),
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _saving || _following ? null : _follow,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _saving
                        ? 'Following...'
                        : _following
                        ? 'Following'
                        : 'Follow',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _subtitleFor(ProfileConnection account) {
    final code = account.civiqCode?.isNotEmpty == true
        ? account.civiqCode!
        : 'No CIVIQ code';
    final role = account.roleLabel;
    if (role == null || role.isEmpty) return code;
    return '$role | $code';
  }

  Future<void> _follow() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .followProfile(widget.account.id);
      if (!mounted) return;
      setState(() {
        _following = true;
        _saving = false;
      });
      ref.invalidate(currentProfileProvider);
      final refreshProfileId = widget.refreshProfileId;
      if (refreshProfileId != null) {
        ref.invalidate(followingScreenDataProvider(refreshProfileId));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not follow account: $error')),
      );
    }
  }
}

class _ConnectionAvatar extends StatelessWidget {
  const _ConnectionAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.border,
        child: Icon(Icons.person_outline),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.border,
          child: Icon(Icons.person_outline),
        ),
      ),
    );
  }
}

class _SocialListError extends StatelessWidget {
  const _SocialListError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load accounts: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
