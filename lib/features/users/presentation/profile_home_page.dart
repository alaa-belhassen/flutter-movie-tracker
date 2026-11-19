import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import 'user_stats_provider.dart';

class ProfileHomePage extends ConsumerWidget {
  const ProfileHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My account')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in to your account'),
          ),
        ),
      );
    }
    final statsAsync = ref.watch(userStatsProvider(user.id));
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My account'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/profile/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.68),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: theme.colorScheme.onPrimary.withValues(
                    alpha: 0.18,
                  ),
                  child: Text(
                    user.nickname.isEmpty
                        ? '?'
                        : user.nickname[0].toUpperCase(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      Text(
                        user.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => context.push('/profile/me'),
                  color: theme.colorScheme.onPrimary,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          statsAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: LinearProgressIndicator()),
              ),
            ),
            error: (error, stackTrace) => Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Could not load your activity'),
                subtitle: Text(error.toString()),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: () => ref.invalidate(userStatsProvider(user.id)),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
            data: (stats) => _ActivitySummary(stats: stats),
          ),
          const SizedBox(height: 24),
          Text('Your space', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _ProfileActionTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile & preferences',
            subtitle: 'Update your nickname, region and favorite genres',
            onTap: () => context.push('/profile/me'),
          ),
          _ProfileActionTile(
            icon: Icons.query_stats_rounded,
            title: 'Statistics dashboard',
            subtitle: 'Explore your viewing activity and movie taste',
            onTap: () => context.push('/profile/stats'),
          ),
          _ProfileActionTile(
            icon: Icons.auto_awesome_rounded,
            title: '$currentYear cinema recap',
            subtitle: 'A snapshot of your year in movies',
            onTap: () => context.push('/profile/recap/$currentYear'),
          ),
          _ProfileActionTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Appearance and app preferences',
            onTap: () => context.push('/profile/settings'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      ('${(stats['moviesWatched'] as num?)?.toInt() ?? 0}', 'Watched'),
      ('${(stats['favorites'] as num?)?.toInt() ?? 0}', 'Favorites'),
      ('${(stats['publishedReviews'] as num?)?.toInt() ?? 0}', 'Reviews'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    values[index].$1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    values[index].$2,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 2),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
