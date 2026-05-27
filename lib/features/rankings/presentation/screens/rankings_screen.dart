import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/locations/data/location_repository.dart';
import '../../../../features/notifications/data/notification_repository.dart';
import '../../../../shared/models/kenya_location.dart';
import '../../data/rankings_repository.dart';

class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankings = ref.watch(rankingsProvider);
    final filter = ref.watch(rankingFilterProvider);
    final locations = ref.watch(governanceLocationsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(rankingsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _RankingsHeader(
                filter: filter,
                locations: locations.asData?.value ?? kenyaCounties,
              ),
            ),
            rankings.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _RankingsError(error: error),
              ),
              data: (items) => items.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyRankings(),
                    )
                  : SliverList.separated(
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) return _AnalyticsPanel(items: items);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            index == 1 ? 2 : 0,
                            16,
                            index == items.length ? 18 : 0,
                          ),
                          child: _LeaderRankingCard(leader: items[index - 1]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingsHeader extends ConsumerWidget {
  const _RankingsHeader({required this.filter, required this.locations});

  final RankingFilter filter;
  final List<KenyaCounty> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counties = locations;
    final selectedCounty = _selectedCounty(counties, filter.countyId);
    final subcounties = selectedCounty?.subcounties ?? const <KenyaSubcounty>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SIVIQ Rankings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(unreadNotificationCountProvider);
                      return unread.maybeWhen(
                        data: (count) => count > 0
                            ? Positioned(
                                top: 9,
                                right: 9,
                                child: IgnorePointer(
                                  child: _TinyBadge(count: count),
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Weekly SIVIQ score snapshots from projects and community signals.',
            style: TextStyle(color: AppColors.grey, height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search leader, county, or constituency',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(rankingFilterProvider.notifier).state = filter.copyWith(
                query: value,
              );
            },
          ),
          const SizedBox(height: 12),
          _ScopeSelector(filter: filter),
          const SizedBox(height: 10),
          _RoleSelector(filter: filter),
          if (filter.scope != RankingScope.national) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: filter.countyId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'County',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: counties
                  .map(
                    (county) => DropdownMenuItem<int>(
                      value: county.id,
                      child: Text(county.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                ref.read(rankingFilterProvider.notifier).state = filter
                    .copyWith(countyId: value, clearSubcounty: true);
              },
            ),
          ],
          if (filter.scope == RankingScope.subcounty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: filter.subcountyId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sub-county / Constituency',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: subcounties
                  .map(
                    (subcounty) => DropdownMenuItem<int>(
                      value: subcounty.id,
                      child: Text(subcounty.name),
                    ),
                  )
                  .toList(),
              onChanged: subcounties.isEmpty
                  ? null
                  : (value) {
                      ref.read(rankingFilterProvider.notifier).state = filter
                          .copyWith(subcountyId: value);
                    },
            ),
          ],
          const SizedBox(height: 12),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

class _ScopeSelector extends ConsumerWidget {
  const _ScopeSelector({required this.filter});

  final RankingFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<RankingScope>(
      segments: const [
        ButtonSegment(
          value: RankingScope.national,
          icon: Icon(Icons.public_outlined),
          label: Text('National'),
        ),
        ButtonSegment(
          value: RankingScope.county,
          icon: Icon(Icons.location_city_outlined),
          label: Text('County'),
        ),
        ButtonSegment(
          value: RankingScope.subcounty,
          icon: Icon(Icons.map_outlined),
          label: Text('Subcounty'),
        ),
      ],
      selected: {filter.scope},
      onSelectionChanged: (selection) {
        ref.read(rankingFilterProvider.notifier).state = filter.copyWith(
          scope: selection.first,
          clearCounty: selection.first == RankingScope.national,
          clearSubcounty: selection.first != RankingScope.subcounty,
        );
      },
    );
  }
}

class _RoleSelector extends ConsumerWidget {
  const _RoleSelector({required this.filter});

  final RankingFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<RankingRole>(
      segments: const [
        ButtonSegment(
          value: RankingRole.governors,
          icon: Icon(Icons.account_balance_outlined),
          label: Text('Governors'),
        ),
        ButtonSegment(
          value: RankingRole.mps,
          icon: Icon(Icons.how_to_vote_outlined),
          label: Text('MPs'),
        ),
      ],
      selected: {filter.role},
      onSelectionChanged: (selection) {
        ref.read(rankingFilterProvider.notifier).state = filter.copyWith(
          role: selection.first,
        );
      },
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.items});

  final List<LeaderRanking> items;

  @override
  Widget build(BuildContext context) {
    final scored = items.where((item) => item.hasSnapshot).toList();
    final topScore = scored.isEmpty
        ? 0.0
        : scored.map((item) => item.score).reduce((a, b) => a > b ? a : b);
    final averageScore = scored.isEmpty
        ? 0.0
        : scored.fold<double>(0, (sum, item) => sum + item.score) /
              scored.length;
    final totalProjects = items.fold<int>(
      0,
      (sum, item) => sum + item.totalProjects,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.emoji_events_outlined,
                  label: 'Top score',
                  value: topScore.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.analytics_outlined,
                  label: 'Average',
                  value: averageScore.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.work_outline,
                  label: 'Projects',
                  value: totalProjects.toString(),
                ),
              ),
            ],
          ),
          if (scored.isEmpty) ...[
            const SizedBox(height: 10),
            const _PendingSnapshotPanel(),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.grey)),
        ],
      ),
    );
  }
}

class _LeaderRankingCard extends StatelessWidget {
  const _LeaderRankingCard({required this.leader});

  final LeaderRanking leader;

  @override
  Widget build(BuildContext context) {
    final movementColor = leader.movement > 0
        ? AppColors.success
        : leader.movement < 0
        ? AppColors.dangerRed
        : AppColors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LeaderRankingDetailScreen(leader: leader),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RankPill(rank: leader.rank),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              leader.leaderName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (leader.isTopTwenty)
                            const Tooltip(
                              message: 'Top 20 this week',
                              child: Icon(
                                Icons.emoji_events,
                                color: AppColors.warning,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${leader.role} | ${leader.regionLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ScoreBlock(
                    label: leader.hasSnapshot ? 'SIVIQ score' : 'SIVIQ score',
                    value: leader.hasSnapshot
                        ? leader.score.toStringAsFixed(1)
                        : 'Pending',
                  ),
                ),
                Expanded(
                  child: _ScoreBlock(
                    label: 'Movement',
                    value: leader.hasSnapshot
                        ? '${leader.movement >= 0 ? '+' : ''}${leader.movement.toStringAsFixed(1)}'
                        : 'Sunday',
                    color: movementColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: leader.hasSnapshot ? leader.completionRatio : 0,
                backgroundColor: AppColors.border,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipStat(
                  icon: Icons.check_circle_outline,
                  label: 'Completed ${leader.completedProjects}',
                ),
                _ChipStat(
                  icon: Icons.pause_circle_outline,
                  label: 'Stalled ${leader.stalledProjects}',
                ),
                _ChipStat(
                  icon: Icons.thumb_up_alt_outlined,
                  label: '${leader.approvalCount} approvals',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LeaderRankingDetailScreen extends ConsumerWidget {
  const LeaderRankingDetailScreen({super.key, required this.leader});

  final LeaderRanking leader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(leaderProjectsProvider(leader.leaderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Leader detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.border,
                      child: Icon(Icons.account_balance_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leader.leaderName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${leader.role} | ${leader.partyName}',
                            style: const TextStyle(color: AppColors.grey),
                          ),
                          Text(
                            leader.regionLabel,
                            style: const TextStyle(color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        label: 'Score',
                        value: leader.hasSnapshot
                            ? leader.score.toStringAsFixed(1)
                            : 'Pending',
                      ),
                    ),
                    Expanded(
                      child: _DetailMetric(
                        label: 'Approval ratio',
                        value:
                            '${(leader.approvalRatio * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                    Expanded(
                      child: _DetailMetric(
                        label: 'Completion',
                        value:
                            '${(leader.completionRatio * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TransparencyPanel(leader: leader),
          const SizedBox(height: 16),
          Text(
            'Associated projects',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          projects.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Text('Could not load projects: $error'),
            data: (items) => items.isEmpty
                ? const _PendingSnapshotPanel()
                : Column(
                    children: items
                        .map((project) => _LinkedProjectTile(project: project))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

class _TransparencyPanel extends StatelessWidget {
  const _TransparencyPanel({required this.leader});

  final LeaderRanking leader;

  @override
  Widget build(BuildContext context) {
    final localUsers = leader.demographicMetadata['eligible_local_users'];
    final weight = leader.demographicMetadata['log_dampened_weight'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transparency data',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Eligible local users', value: '${localUsers ?? 0}'),
          _InfoRow(label: 'Log-dampened weight', value: '${weight ?? 'N/A'}'),
          _InfoRow(
            label: 'Snapshot week',
            value: leader.snapshotWeek == null
                ? 'Pending first Sunday run'
                : _shortDate(leader.snapshotWeek!),
          ),
          const _InfoRow(label: 'Formula', value: 'rankings_v1'),
        ],
      ),
    );
  }
}

class _LinkedProjectTile extends StatelessWidget {
  const _LinkedProjectTile({required this.project});

  final RankedLeaderProject project;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${project.projectType} | ${project.verificationStatus}',
                  style: const TextStyle(color: AppColors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            project.score.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});

  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rank == null ? '--' : '#$rank',
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.grey),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: AppColors.grey)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.grey)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rankings are generated from user-submitted SIVIQ reports and community engagement data. SIVIQ Africa is not affiliated with any government institution.',
              style: TextStyle(color: AppColors.grey, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSnapshotPanel extends StatelessWidget {
  const _PendingSnapshotPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_outlined, color: AppColors.primaryGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Weekly scores will appear after linked projects and the Sunday snapshot run.',
              style: TextStyle(color: AppColors.grey, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRankings extends StatelessWidget {
  const _EmptyRankings();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'No leaders found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different region, role, or search term.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _RankingsError extends ConsumerWidget {
  const _RankingsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.dangerRed),
          const SizedBox(height: 10),
          Text(
            'Could not load rankings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref.invalidate(rankingsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.dangerRed,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

KenyaCounty? _selectedCounty(List<KenyaCounty> counties, int? countyId) {
  if (countyId == null) return null;
  for (final county in counties) {
    if (county.id == countyId) return county;
  }
  return null;
}

String _shortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
