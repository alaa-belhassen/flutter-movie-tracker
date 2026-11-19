import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/review_service.dart';

class JournalData {
  const JournalData({required this.stats, required this.entries});

  final Map<String, dynamic> stats;
  final List<ViewingEntry> entries;
}

final journalDataProvider = FutureProvider.autoDispose
    .family<JournalData, String>((ref, userId) async {
      final service = ref.watch(reviewServiceProvider);
      final result = await Future.wait<dynamic>([
        service.getUserStats(userId),
        service.getViewingEntries(userId),
      ]);
      return JournalData(
        stats: result[0] as Map<String, dynamic>,
        entries: result[1] as List<ViewingEntry>,
      );
    });

class JournalHomePage extends ConsumerWidget {
  const JournalHomePage({super.key});

  Future<void> _openLogForm(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    await context.push('/journal/log');
    ref.invalidate(journalDataProvider(userId));
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    String userId,
    ViewingEntry entry,
  ) async {
    try {
      await ref.read(reviewServiceProvider).deleteViewingEntry(entry.id);
      ref.invalidate(journalDataProvider(userId));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your journal.')),
      );
    }

    final journal = ref.watch(journalDataProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text('My journal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLogForm(context, ref, user.id),
        icon: const Icon(Icons.add),
        label: const Text('Log a viewing'),
      ),
      body: journal.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(journalDataProvider(user.id)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final averageRating =
              (data.stats['avgRating'] as num?)?.toDouble() ?? 0;
          final metricStyle = textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          );
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(journalDataProvider(user.id));
              await ref.read(journalDataProvider(user.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Text(
                  'Your movie nights, all in one place.',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _JournalMetric(
                      value: '${data.stats['moviesWatched'] ?? 0}',
                      label: 'Movies',
                      style: metricStyle,
                    ),
                    _JournalMetric(
                      value: averageRating == 0
                          ? '—'
                          : averageRating.toStringAsFixed(1),
                      label: 'Avg rating',
                      style: metricStyle,
                    ),
                    _JournalMetric(
                      value: '${data.stats['publishedReviews'] ?? 0}',
                      label: 'Reviews',
                      style: metricStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent viewings',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    Text('${data.entries.length}', style: textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 10),
                if (data.entries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_movies_outlined,
                            size: 42,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your journal is waiting for its first movie.',
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                _openLogForm(context, ref, user.id),
                            child: const Text('Add your first viewing'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...data.entries.map(
                    (entry) => _ViewingCard(
                      entry: entry,
                      onDelete: () =>
                          _deleteEntry(context, ref, user.id, entry),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JournalMetric extends StatelessWidget {
  const _JournalMetric({
    required this.value,
    required this.label,
    required this.style,
  });

  final String value;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: style),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ViewingCard extends ConsumerWidget {
  const _ViewingCard({required this.entry, required this.onDelete});

  final ViewingEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieFuture = ref
        .watch(movieRepositoryProvider)
        .getMovieById(entry.movieId);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: FutureBuilder<Movie?>(
        future: movieFuture,
        builder: (context, snapshot) {
          final movie = snapshot.data;
          return ListTile(
            leading: CircleAvatar(
              child: Icon(
                entry.isRewatch ? Icons.replay : Icons.movie_outlined,
              ),
            ),
            title: Text(
              movie?.title ?? 'Movie ${entry.movieId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.watchedAt.day}/${entry.watchedAt.month}/${entry.watchedAt.year}'
                  '${entry.isRewatch ? ' · Rewatch' : ''}',
                ),
                if (entry.notes.isNotEmpty)
                  Text(
                    entry.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            isThreeLine: entry.notes.isNotEmpty,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.rating != null)
                  Text('★ ${entry.rating!.toStringAsFixed(1)}'),
                IconButton(
                  tooltip: 'Delete viewing',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
