import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/poster_placeholder.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/recommendation_service.dart';

class RecommendationsPage extends ConsumerStatefulWidget {
  const RecommendationsPage({super.key});

  @override
  ConsumerState<RecommendationsPage> createState() =>
      _RecommendationsPageState();
}

class _RecommendationsPageState extends ConsumerState<RecommendationsPage> {
  late Future<List<RecommendedMovie>> _recommendations;

  @override
  void initState() {
    super.initState();
    _recommendations = _loadRecommendations();
  }

  Future<List<RecommendedMovie>> _loadRecommendations() {
    final user = ref.read(currentUserProvider);
    if (user == null) return Future.value(const []);
    return ref.read(recommendationServiceProvider).getRecommendations(user.id);
  }

  void _reload() => setState(() => _recommendations = _loadRecommendations());

  Future<void> _exclude(RecommendedMovie recommendation) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(recommendationServiceProvider)
          .excludeRecommendation(user.id, recommendation.movie.id);
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('For you')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in for personalized recommendations'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('For you'),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<RecommendedMovie>>(
        future: _recommendations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Could not build recommendations.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recommendations = snapshot.data!;
          if (recommendations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Your next favorite is waiting',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Follow actors or rate movies to improve your picks.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => context.go('/people'),
                      child: const Text('Discover actors'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _recommendations;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                  child: Text(
                    'Picked from actors you follow and movies you enjoy.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                for (final recommendation in recommendations)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          context.push('/movie/${recommendation.movie.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 78,
                              height: 112,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: PosterPlaceholder(
                                  title: recommendation.movie.title,
                                  imagePath: recommendation.movie.posterPath,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recommendation.movie.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (recommendation.movie.year > 0)
                                        '${recommendation.movie.year}',
                                      recommendation.movie.genre,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    recommendation.reason,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${recommendation.matchScore}% match',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Show me less like this',
                                        onPressed: () =>
                                            _exclude(recommendation),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
