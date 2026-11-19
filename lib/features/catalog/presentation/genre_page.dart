import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/movie_list_tile.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import 'explore_movies_page.dart' show ExploreMovieFilters, MovieFiltersSheet;
import 'movie_filters_button.dart';

class GenrePage extends ConsumerStatefulWidget {
  const GenrePage({super.key, required this.genreId});

  final String genreId;

  @override
  ConsumerState<GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends ConsumerState<GenrePage> {
  ExploreMovieFilters _filters = const ExploreMovieFilters();
  late Future<List<Movie>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = ref
        .read(movieRepositoryProvider)
        .getMoviesByGenre(widget.genreId);
  }

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<ExploreMovieFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieFiltersSheet(initialFilters: _filters),
    );
    if (filters == null || !mounted) return;

    final repository = ref.read(movieRepositoryProvider);
    setState(() {
      _filters = filters;
      _moviesFuture = filters.isActive
          ? repository.discoverMovies(
              genre: filters.genre ?? widget.genreId,
              actor: filters.actor,
              actorId: filters.actorId,
              year: filters.year,
              minRating: filters.minRating > 0 ? filters.minRating : null,
            )
          : repository.getMoviesByGenre(widget.genreId);
    });
  }

  void _clearFilters() {
    setState(() {
      _filters = const ExploreMovieFilters();
      _moviesFuture = ref
          .read(movieRepositoryProvider)
          .getMoviesByGenre(widget.genreId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Genre: ${widget.genreId}'),
        actions: [
          MovieFiltersButton(
            activeCount: _filters.activeCount,
            onPressed: _openFilters,
          ),
        ],
      ),
      body: FutureBuilder<List<Movie>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final movies = snapshot.data!;
          if (movies.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No movies found for these filters.'),
                  if (_filters.isActive)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (_filters.isActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filters applied (${_filters.activeCount})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return MovieListTile(
                      title: movie.title,
                      subtitle:
                          '${movie.year} · ${movie.genre} · ${movie.duration}',
                      rating: movie.rating,
                      posterPath: movie.posterPath,
                      onTap: () => context.push('/movie/${movie.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
