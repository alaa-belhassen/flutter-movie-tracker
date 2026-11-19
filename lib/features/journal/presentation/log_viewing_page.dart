import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../core/widgets/rating_bar.dart';
import 'journal_home_page.dart';
import '../../users/presentation/user_stats_provider.dart';

class LogViewingPage extends ConsumerStatefulWidget {
  const LogViewingPage({super.key, this.movieId});

  final String? movieId;

  @override
  ConsumerState<LogViewingPage> createState() => _LogViewingPageState();
}

class _LogViewingPageState extends ConsumerState<LogViewingPage> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  Movie? _selectedMovie;
  List<Movie> _results = const [];
  DateTime _watchedAt = DateTime.now();
  double _rating = 4;
  bool _includeRating = false;
  bool _isRewatch = false;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLoadingMovie = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final movieId = widget.movieId;
    if (movieId != null) {
      _isLoadingMovie = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMovie(movieId));
    }
  }

  Future<void> _loadMovie(String movieId) async {
    try {
      final movie = await ref
          .read(movieRepositoryProvider)
          .getMovieById(movieId);
      if (!mounted) return;
      setState(() {
        _selectedMovie = movie;
        if (movie == null) {
          _error = 'Movie not found. Search for it and choose it manually.';
        } else {
          _searchController.text = movie.title;
          _results = const [];
          _error = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingMovie = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(movieRepositoryProvider)
          .searchMovies(query);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _chooseDate() async {
    final chosenDate = await showDatePicker(
      context: context,
      initialDate: _watchedAt,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (chosenDate != null) setState(() => _watchedAt = chosenDate);
  }

  Future<void> _save() async {
    final movie = _selectedMovie;
    if (movie == null) {
      setState(() => _error = 'Choose a movie before saving.');
      return;
    }
    if (_notesController.text.trim().length > 1000) {
      setState(() => _error = 'Notes must be 1,000 characters or fewer.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewServiceProvider)
          .logViewing(
            movieId: movie.id,
            watchedAt: _watchedAt,
            rating: _includeRating ? _rating : null,
            isRewatch: _isRewatch,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(journalDataProvider(user.id));
      ref.invalidate(userStatsProvider(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viewing added to your journal.')),
      );
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Log a viewing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Which movie did you watch?', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  enabled: !_isLoadingMovie,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'Search movies',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSearching || _isLoadingMovie ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          if (_isLoadingMovie) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(
              'Loading the movie from your selection...',
              style: textTheme.bodySmall,
            ),
          ],
          if (_selectedMovie case final movie?) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(movie.title),
                subtitle: Text('${movie.year} · ${movie.genre}'),
                trailing: IconButton(
                  tooltip: 'Choose another movie',
                  onPressed: () => setState(() {
                    _selectedMovie = null;
                    _searchController.clear();
                    _error = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
          ..._results
              .where((movie) => movie.id != _selectedMovie?.id)
              .take(6)
              .map(
                (movie) => ListTile(
                  leading: const Icon(Icons.local_movies_outlined),
                  title: Text(movie.title),
                  subtitle: Text('${movie.year} · ${movie.genre}'),
                  onTap: () => setState(() {
                    _selectedMovie = movie;
                    _results = const [];
                    _searchController.text = movie.title;
                    _error = null;
                  }),
                ),
              ),
          const SizedBox(height: 20),
          Text('When did you watch it?', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This was a rewatch'),
            value: _isRewatch,
            onChanged: (value) => setState(() => _isRewatch = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add a rating'),
            value: _includeRating,
            onChanged: (value) => setState(() => _includeRating = value),
          ),
          if (_includeRating) ...[
            const SizedBox(height: 8),
            Center(
              child: RatingBar(
                rating: _rating,
                onRatingChanged: (value) => setState(() => _rating = value),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving || _isLoadingMovie || _selectedMovie == null
                ? null
                : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isLoadingMovie ? 'Loading movie...' : 'Save to journal',
                  ),
          ),
        ],
      ),
    );
  }
}
