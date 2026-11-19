import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/review_service.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/spoiler_banner.dart';

class MovieDetailPage extends ConsumerWidget {
  final String movieId;
  const MovieDetailPage({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieRepo = ref.watch(movieRepositoryProvider);
    final watchlistService = ref.watch(watchlistServiceProvider);
    final reviewService = ref.watch(reviewServiceProvider);
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder(
      future: Future.wait<dynamic>([
        movieRepo.getMovieById(movieId),
        reviewService.getReviewsForMovie(movieId),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final movie = snapshot.data![0] as Movie?;
        final reviews = snapshot.data![1] as List<Review>;

        if (movie == null) {
          return const Scaffold(body: Center(child: Text('Movie not found')));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(movie.title),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      movie.backdropPath == null
                          ? Container(color: colorScheme.surface)
                          : CachedNetworkImage(
                              imageUrl: Uri.https(
                                'image.tmdb.org',
                                '/t/p/w1280${movie.backdropPath}',
                              ).toString(),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Container(color: colorScheme.surface),
                            ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share(
                      'Check out ${movie.title} on Movie Tracker!',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () async {
                      if (user == null) {
                        context.go('/login');
                        return;
                      }
                      try {
                        await watchlistService.addFavorite(user.id, movie.id);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${movie.year} · ${movie.genre} · ${movie.duration}',
                            style: textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          RatingStars(rating: movie.rating),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(movie.synopsis, style: textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      Text('Cast', style: textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 118,
                        child: FutureBuilder<List<CastMember>>(
                          future: movieRepo.getMovieCast(movie.id),
                          builder: (context, castSnapshot) {
                            if (castSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Could not load cast: ${castSnapshot.error}',
                                ),
                              );
                            }
                            if (!castSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final cast = castSnapshot.data!;
                            if (cast.isEmpty) {
                              return const Center(
                                child: Text('No cast information available.'),
                              );
                            }
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: cast.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                final person = cast[index];
                                return SizedBox(
                                  width: 82,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => context.push(
                                      '/people/actor/${person.id}',
                                    ),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 34,
                                          backgroundImage:
                                              person.profilePath == null
                                              ? null
                                              : NetworkImage(
                                                  Uri.https(
                                                    'image.tmdb.org',
                                                    '/t/p/w185${person.profilePath}',
                                                  ).toString(),
                                                ),
                                          child: person.profilePath == null
                                              ? Text(
                                                  person.name.isEmpty
                                                      ? '?'
                                                      : person.name[0],
                                                )
                                              : null,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          person.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.labelMedium,
                                        ),
                                        Text(
                                          person.character,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  context.push('/journal/log/${movie.id}'),
                              child: const Text('Log a viewing'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (user == null) {
                                  context.go('/login');
                                  return;
                                }
                                try {
                                  await watchlistService.toggleWatchlist(
                                    user.id,
                                    movie.id,
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                              child: const Text('To watch'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Reviews (${reviews.length})',
                        style: textTheme.headlineMedium,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              context.push('/journal/review/${movie.id}'),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Write a review'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...reviews.map(
                        (r) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      r.userNickname,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    RatingStars(rating: r.rating, size: 12),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                r.containsSpoiler
                                    ? SpoilerBanner(child: Text(r.content))
                                    : Text(r.content),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
