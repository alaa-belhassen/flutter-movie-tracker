import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/watchlist_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../core/widgets/movie_list_tile.dart';
import '../../catalog/presentation/explore_movies_page.dart'
    show ExploreMovieFilters, MovieFiltersSheet;
import '../../catalog/presentation/movie_filters_button.dart';

class ListsHomePage extends ConsumerStatefulWidget {
  const ListsHomePage({super.key});

  @override
  ConsumerState<ListsHomePage> createState() => _ListsHomePageState();
}

class _ListsHomePageState extends ConsumerState<ListsHomePage> {
  ExploreMovieFilters _filters = const ExploreMovieFilters();
  int _refreshKey = 0;

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<ExploreMovieFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieFiltersSheet(initialFilters: _filters),
    );
    if (filters != null && mounted) setState(() => _filters = filters);
  }

  Future<void> _createList() async {
    final titleController = TextEditingController();
    var isShared = false;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a list'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'List name'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shared list'),
                subtitle: const Text('Invite friends to collaborate.'),
                value: isShared,
                onChanged: (value) => setDialogState(() => isShared = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (shouldSave != true || !mounted) return;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for your list.')),
      );
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    try {
      await ref
          .read(watchlistServiceProvider)
          .saveCustomList(
            CustomList(
              id: 'local_${DateTime.now().microsecondsSinceEpoch}',
              title: title,
              userId: user.id,
              movieIds: const [],
              isShared: isShared,
            ),
          );
      if (mounted) setState(() => _refreshKey++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(currentUserProvider);
    final watchlistService = ref.watch(watchlistServiceProvider);
    final movieRepo = ref.watch(movieRepositoryProvider);
    final userId = user?.id ?? '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lists & Watchlist'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To Watch'),
              Tab(text: 'Favorites'),
              Tab(text: 'Shared Lists'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Create a list',
              icon: const Icon(Icons.add),
              onPressed: _createList,
            ),
            IconButton(
              tooltip: 'Pick something to watch',
              icon: const Icon(Icons.nightlight),
              onPressed: () => context.push('/lists/tonight'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildMovieTab(
              context,
              movieRepo,
              watchlistService.getWatchlist(userId),
              _filters,
              onRemove: (movieId) async {
                await watchlistService.toggleWatchlist(userId, movieId);
                if (mounted) setState(() => _refreshKey++);
              },
              refreshKey: _refreshKey,
            ),
            _buildMovieTab(
              context,
              movieRepo,
              watchlistService.getFavorites(userId),
              _filters,
              onRemove: (movieId) async {
                await watchlistService.toggleFavorite(userId, movieId);
                if (mounted) setState(() => _refreshKey++);
              },
              refreshKey: _refreshKey,
            ),
            FutureBuilder<List<CustomList>>(
              key: ValueKey(_refreshKey),
              future: watchlistService.getCustomLists(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load custom lists.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lists = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final cl = lists[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          cl.isShared ? Icons.group_outlined : Icons.list_alt,
                        ),
                        title: Text(cl.title),
                        subtitle: Text(
                          '${cl.movieIds.length} movies · '
                          '${cl.isShared ? '${cl.members.length} members' : 'Private'}'
                          '${cl.userId == userId ? ' · Yours' : ' · Shared with you'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push('/lists/${cl.id}');
                          if (mounted) setState(() => _refreshKey++);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieTab(
    BuildContext context,
    MovieRepository movieRepo,
    Future<List<String>> movieIdsFuture,
    ExploreMovieFilters filters, {
    required Future<void> Function(String movieId) onRemove,
    required int refreshKey,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MovieFiltersButton(
              activeCount: filters.activeCount,
              onPressed: _openFilters,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            key: ValueKey(refreshKey),
            future: movieIdsFuture,
            builder: (context, idsSnapshot) {
              if (idsSnapshot.hasError) {
                return const Center(child: Text('Could not load this list.'));
              }
              if (!idsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final ids = idsSnapshot.data!;
              if (ids.isEmpty) {
                return const Center(child: Text('No movies in this list yet.'));
              }

              return FutureBuilder<List<Movie?>>(
                future: Future.wait(ids.map(movieRepo.getMovieById)),
                builder: (context, moviesSnapshot) {
                  if (moviesSnapshot.hasError) {
                    return const Center(
                      child: Text('Could not load movies from TMDB.'),
                    );
                  }
                  if (!moviesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final movies = moviesSnapshot.data!
                      .whereType<Movie>()
                      .toList();
                  if (movies.isEmpty) {
                    return const Center(
                      child: Text('No valid TMDB movies in this list.'),
                    );
                  }
                  return FutureBuilder<List<Movie>>(
                    future: _filterListMovies(movieRepo, movies, filters),
                    builder: (context, filteredSnapshot) {
                      if (filteredSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not apply movie filters: ${filteredSnapshot.error}',
                          ),
                        );
                      }
                      if (!filteredSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final filteredMovies = filteredSnapshot.data!;
                      if (filteredMovies.isEmpty) {
                        return const Center(
                          child: Text('No movies match these filters.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredMovies.length,
                        itemBuilder: (context, index) {
                          final movie = filteredMovies[index];
                          return MovieListTile(
                            title: movie.title,
                            subtitle:
                                '${movie.year} · ${movie.genre} · ${movie.duration}',
                            rating: movie.rating,
                            posterPath: movie.posterPath,
                            onTap: () async {
                              await context.push('/movie/${movie.id}');
                              if (mounted) setState(() => _refreshKey++);
                            },
                            onBookmarkToggle: () => onRemove(movie.id),
                            isBookmarked: true,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Movie>> _filterListMovies(
    MovieRepository repository,
    List<Movie> movies,
    ExploreMovieFilters filters,
  ) async {
    var filteredMovies = movies;
    if ((filters.actorId?.isNotEmpty ?? false) ||
        (filters.actor?.trim().isNotEmpty ?? false)) {
      final actorMovies = await repository.discoverMovies(
        actor: filters.actor,
        actorId: filters.actorId,
        genre: filters.genre,
        year: filters.year,
        minRating: filters.minRating > 0 ? filters.minRating : null,
      );
      final actorMovieIds = actorMovies.map((movie) => movie.id).toSet();
      filteredMovies = filteredMovies
          .where((movie) => actorMovieIds.contains(movie.id))
          .toList(growable: false);
    }

    return filteredMovies
        .where(
          (movie) =>
              (filters.genre == null ||
                  movie.genre.toLowerCase().contains(
                    filters.genre!.toLowerCase(),
                  )) &&
              (filters.year == null || movie.year == filters.year) &&
              (filters.minRating == 0 || movie.rating >= filters.minRating),
        )
        .toList(growable: false);
  }
}
