import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import 'user_stats_provider.dart';

class StatsDashboardPage extends ConsumerWidget {
  const StatsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My statistics')),
        body: const Center(child: Text('Sign in to view your statistics.')),
      );
    }

    final statsAsync = ref.watch(userStatsProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh statistics',
            onPressed: () => ref.invalidate(userStatsProvider(user.id)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your dashboard is taking a break.',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(userStatsProvider(user.id)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          final moviesWatched = _intValue(stats, 'moviesWatched');
          final viewings = _intValue(stats, 'viewingCount');
          final reviews = _intValue(stats, 'publishedReviews');
          final favorites = _intValue(stats, 'favorites');
          final watchlist = _intValue(stats, 'watchlist');
          final followedActors = _intValue(stats, 'followedActors');
          final averageRating = _doubleValue(stats, 'avgRating');
          final monthly = _monthlyValues(stats['monthlyViewings']);
          final genres =
              (stats['favoriteGenres'] as List?)?.whereType<String>().toList(
                growable: false,
              ) ??
              user.favoriteGenres;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userStatsProvider(user.id));
              await ref.read(userStatsProvider(user.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                _DashboardHero(
                  nickname: user.nickname,
                  moviesWatched: moviesWatched,
                  viewings: viewings,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your cinema, at a glance',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      'ALL TIME',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 600 ? 3 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: columns == 3 ? 1.45 : 1.28,
                      children: [
                        _MetricCard(
                          label: 'Movies watched',
                          value: '$moviesWatched',
                          icon: Icons.movie_outlined,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'Total viewings',
                          value: '$viewings',
                          icon: Icons.visibility_outlined,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'Average rating',
                          value: averageRating == 0
                              ? '—'
                              : averageRating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'Reviews',
                          value: '$reviews',
                          icon: Icons.rate_review_outlined,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'Favorites',
                          value: '$favorites',
                          icon: Icons.favorite_border_rounded,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'To watch',
                          value: '$watchlist',
                          icon: Icons.bookmark_border_rounded,
                          accent: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          label: 'Actors followed',
                          value: '$followedActors',
                          icon: Icons.people_outline_rounded,
                          accent: theme.colorScheme.secondary,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                _ActivityCard(monthlyValues: monthly),
                const SizedBox(height: 24),
                _GenresCard(genres: genres),
                const SizedBox(height: 24),
                Text('Keep exploring', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.menu_book_outlined,
                        title: 'Open journal',
                        onTap: () => context.push('/journal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.auto_awesome_outlined,
                        title: 'For you',
                        onTap: () => context.push('/people/for-you'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _intValue(Map<String, dynamic> values, String key) =>
      (values[key] as num?)?.toInt() ?? 0;

  static double _doubleValue(Map<String, dynamic> values, String key) =>
      (values[key] as num?)?.toDouble() ?? 0;

  static List<_MonthValue> _monthlyValues(Object? value) {
    final rows = value is List ? value : const [];
    final counts = <String, int>{};
    for (final row in rows.whereType<Map>()) {
      final month = row['month'];
      final count = row['count'];
      if (month is String && count is num) counts[month] = count.toInt();
    }
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      return _MonthValue(
        label: _monthLabels[month.month - 1],
        count: counts[key] ?? 0,
      );
    }, growable: false);
  }

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _MonthValue {
  const _MonthValue({required this.label, required this.count});

  final String label;
  final int count;
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.nickname,
    required this.moviesWatched,
    required this.viewings,
  });

  final String nickname;
  final int moviesWatched;
  final int viewings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            Color.alphaBlend(
              colors.secondary.withValues(alpha: 0.2),
              colors.surface,
            ),
          ],
        ),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR CINEMA JOURNEY',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.secondary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hello, $nickname',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  moviesWatched == 0
                      ? 'Start logging films to build your personal cinema story.'
                      : '$moviesWatched unique films across $viewings viewings.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.local_movies_rounded, size: 54, color: colors.secondary),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const Spacer(),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.monthlyValues});

  final List<_MonthValue> monthlyValues;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final maxCount = monthlyValues.fold<int>(
      0,
      (maximum, month) => month.count > maximum ? month.count : maximum,
    );
    final total = monthlyValues.fold<int>(0, (sum, month) => sum + month.count);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Watching activity',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(
                '$total this period',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your viewings over the last six months',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlyValues
                  .map((month) {
                    final height = maxCount == 0
                        ? 5.0
                        : 12.0 + 78.0 * month.count / maxCount;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${month.count}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              height: height,
                              decoration: BoxDecoration(
                                color: month.count == 0
                                    ? colors.surfaceContainerHighest
                                    : colors.secondary.withValues(
                                        alpha:
                                            maxCount > 0 &&
                                                month.count == maxCount
                                            ? 1
                                            : 0.56,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              month.label,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          if (total == 0) ...[
            const SizedBox(height: 8),
            Text(
              'Log a viewing and your activity will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GenresCard extends StatelessWidget {
  const _GenresCard({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your favorite genres', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Your selected profile preferences',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (genres.isEmpty)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Choose genres in your profile to tune recommendations.',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => context.push('/profile/me'),
                  child: const Text('Edit profile'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres
                  .map(
                    (genre) => Chip(
                      avatar: Icon(
                        Icons.local_movies_outlined,
                        size: 16,
                        color: colors.secondary,
                      ),
                      label: Text(genre),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: colors.secondary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, maxLines: 1)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
