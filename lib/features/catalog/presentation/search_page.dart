import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../core/widgets/movie_list_tile.dart';
import 'explore_movies_page.dart' show ExploreMovieFilters, MovieFiltersSheet;
import 'movie_filters_button.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  List<Movie> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _searchGeneration = 0;
  ExploreMovieFilters _filters = const ExploreMovieFilters();

  void _onSearchChanged(String query) async {
    if (query.isEmpty && !_filters.isActive) {
      _searchGeneration++;
      setState(() {
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || generation != _searchGeneration) return;
    try {
      final repo = ref.read(movieRepositoryProvider);
      final results = await _loadMovies(repo, query, _filters);
      if (!mounted || generation != _searchGeneration) return;
      if (query.trim().isNotEmpty) await repo.addSearchHistory(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      debugPrint('TMDB movie search failed: $error');
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Movie>> _loadMovies(
    MovieRepository repository,
    String query,
    ExploreMovieFilters filters,
  ) async {
    if (!filters.isActive) return repository.searchMovies(query);

    final filteredMovies = await repository.discoverMovies(
      genre: filters.genre,
      actor: filters.actor,
      actorId: filters.actorId,
      year: filters.year,
      minRating: filters.minRating > 0 ? filters.minRating : null,
    );
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return filteredMovies;
    return filteredMovies
        .where((movie) => movie.title.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
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

    final query = _searchController.text.trim();
    final generation = ++_searchGeneration;
    setState(() {
      _filters = filters;
      _isLoading = filters.isActive || query.isNotEmpty;
      _errorMessage = null;
    });

    if (!filters.isActive && query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final results = await _loadMovies(
        ref.read(movieRepositoryProvider),
        query,
        filters,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search movies...',
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
        actions: [
          MovieFiltersButton(
            activeCount: _filters.activeCount,
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filters.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters applied (${_filters.activeCount})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final query = _searchController.text.trim();
                      setState(() {
                        _filters = const ExploreMovieFilters();
                        _isLoading = query.isNotEmpty;
                      });
                      if (query.isEmpty) {
                        setState(() => _results = []);
                      } else {
                        _onSearchChanged(query);
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : _results.isEmpty && _filters.isActive
                ? const Center(child: Text('No movies match these filters.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final movie = _results[index];
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
      ),
    );
  }
}
