import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/projects/data/project_repository.dart';
import '../../../../features/projects/presentation/screens/projects_screen.dart';

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
    final feed = ref.watch(localProjectFeedProvider);
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
              _FeedList(projects: feed),
              _FeedList(projects: feed, trending: true),
              const _FollowingPlaceholder(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.projects, this.trending = false});

  final AsyncValue<List<CiviqProject>> projects;
  final bool trending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return projects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load feed: $error')),
      data: (items) {
        final sorted = [...items];
        if (trending) {
          sorted.sort(
            (a, b) => (b.approvalCount - b.disapprovalCount).compareTo(
              a.approvalCount - a.disapprovalCount,
            ),
          );
        }
        if (sorted.isEmpty) return const _EmptyFeed();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(localProjectFeedProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return ProjectFeedCard(project: sorted[index]);
            },
          ),
        );
      },
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
          'Following feed will show civic reports from profiles you follow.',
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
          'No civic project reports yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}
