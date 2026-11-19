import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/widgets/movie_poster_card.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import 'movie_filters_button.dart';

class ExploreMovieFilters {
  const ExploreMovieFilters({
    this.genre,
    this.actor,
    this.actorId,
    this.year,
    this.minRating = 0,
  });

  final String? genre;
  final String? actor;
  final String? actorId;
  final int? year;
  final double minRating;

  bool get isActive =>
      (genre?.isNotEmpty ?? false) ||
      (actor?.trim().isNotEmpty ?? false) ||
      year != null ||
      minRating > 0;

  int get activeCount => [
    if (genre?.isNotEmpty ?? false) true,
    if (actor?.trim().isNotEmpty ?? false) true,
    if (year != null) true,
    if (minRating > 0) true,
  ].length;
}

class ExploreMoviesPage extends ConsumerStatefulWidget {
  const ExploreMoviesPage({super.key});

  @override
  ConsumerState<ExploreMoviesPage> createState() => _ExploreMoviesPageState();
}

class _ExploreMoviesPageState extends ConsumerState<ExploreMoviesPage> {
  ExploreMovieFilters _filters = const ExploreMovieFilters();
  late Future<List<Movie>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = ref.read(movieRepositoryProvider).getTrendingMovies();
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
              genre: filters.genre,
              actor: filters.actor,
              actorId: filters.actorId,
              minRating: filters.minRating > 0 ? filters.minRating : null,
              year: filters.year,
            )
          : repository.getTrendingMovies();
    });
  }

  void _clearFilters() {
    setState(() {
      _filters = const ExploreMovieFilters();
      _moviesFuture = ref.read(movieRepositoryProvider).getTrendingMovies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending movies'),
        actions: [
          MovieFiltersButton(
            activeCount: _filters.activeCount,
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load movies',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _moviesFuture = _filters.isActive
                                    ? ref
                                          .read(movieRepositoryProvider)
                                          .discoverMovies(
                                            genre: _filters.genre,
                                            actor: _filters.actor,
                                            actorId: _filters.actorId,
                                            minRating: _filters.minRating > 0
                                                ? _filters.minRating
                                                : null,
                                            year: _filters.year,
                                          )
                                    : ref
                                          .read(movieRepositoryProvider)
                                          .getTrendingMovies();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final movies = snapshot.data ?? const <Movie>[];
                if (movies.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filters.isActive
                                ? Icons.filter_alt_off_rounded
                                : Icons.movie_filter_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filters.isActive
                                ? 'No movies match these filters'
                                : 'No trending movies right now',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _filters.isActive
                                ? 'Try changing or clearing your filters.'
                                : 'Please check back soon.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium,
                          ),
                          if (_filters.isActive) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return CustomScrollView(
                  key: const PageStorageKey('trending-movies-grid'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _filters.isActive
                                    ? 'Your filtered picks'
                                    : 'Popular with movie fans right now',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '${movies.length} movies',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_filters.isActive)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        sliver: SliverToBoxAdapter(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_filters.genre case final genre?)
                                _FilterPill(label: genre),
                              if (_filters.actor case final actor?)
                                _FilterPill(label: 'Actor: $actor'),
                              if (_filters.year case final year?)
                                _FilterPill(label: '$year'),
                              if (_filters.minRating > 0)
                                _FilterPill(
                                  label:
                                      '${_filters.minRating.toStringAsFixed(1)}+ ★',
                                ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                                label: const Text('Clear all'),
                                onPressed: _clearFilters,
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = switch (constraints.crossAxisExtent) {
                            >= 950 => 4,
                            >= 620 => 3,
                            _ => 2,
                          };
                          final cardWidth =
                              (constraints.crossAxisExtent -
                                  (columns - 1) * 12) /
                              columns;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 18,
                                  mainAxisExtent: cardWidth * 1.5 + 48,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final movie = movies[index];
                              return TweenAnimationBuilder<double>(
                                key: ValueKey(movie.id),
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                  milliseconds: 280 + (index.clamp(0, 8) * 35),
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) => Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 12 * (1 - value)),
                                    child: child,
                                  ),
                                ),
                                child: MoviePosterCard(
                                  title: movie.title,
                                  rating: movie.rating,
                                  posterPath: movie.posterPath,
                                  width: cardWidth,
                                  onTap: () =>
                                      context.push('/movie/${movie.id}'),
                                ),
                              );
                            }, childCount: movies.length),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(label),
    backgroundColor: Theme.of(context).colorScheme.primary
        .withValues(alpha: 0.1),
  );
}

class MovieFiltersSheet extends ConsumerStatefulWidget {
  const MovieFiltersSheet({super.key, required this.initialFilters});

  final ExploreMovieFilters initialFilters;

  @override
  ConsumerState<MovieFiltersSheet> createState() => _MovieFiltersSheetState();
}

class _MovieFiltersSheetState extends ConsumerState<MovieFiltersSheet> {
  static const _genres = [
    'Action',
    'Adventure',
    'Animation',
    'Comedy',
    'Crime',
    'Drama',
    'Fantasy',
    'Horror',
    'Mystery',
    'Romance',
    'Science Fiction',
    'Thriller',
  ];

  late String? _genre = widget.initialFilters.genre;
  late final TextEditingController _actorController = TextEditingController(
    text: widget.initialFilters.actor ?? '',
  );
  late final TextEditingController _yearController = TextEditingController(
    text: widget.initialFilters.year?.toString() ?? '',
  );
  late double _minRating = widget.initialFilters.minRating;
  Timer? _actorSearchDebounce;
  List<MovieActorSuggestion> _actorSuggestions = const [];
  late String? _selectedActorId = widget.initialFilters.actorId;
  String? _actorSearchError;
  bool _isSearchingActors = false;
  int _actorSearchGeneration = 0;

  void _searchActors(String query) {
    _actorSearchDebounce?.cancel();
    final generation = ++_actorSearchGeneration;
    final trimmedQuery = query.trim();
    setState(() {
      _selectedActorId = null;
      _actorSuggestions = const [];
      _actorSearchError = null;
      _isSearchingActors = trimmedQuery.length >= 2;
    });

    if (trimmedQuery.length < 2) {
      setState(() => _isSearchingActors = false);
      return;
    }

    _actorSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await ref
            .read(movieRepositoryProvider)
            .searchActors(trimmedQuery);
        if (!mounted || generation != _actorSearchGeneration) return;
        setState(() {
          _actorSuggestions = suggestions;
          _isSearchingActors = false;
        });
      } catch (error) {
        if (!mounted || generation != _actorSearchGeneration) return;
        setState(() {
          _actorSearchError = error.toString();
          _isSearchingActors = false;
        });
      }
    });
  }

  void _selectActor(MovieActorSuggestion actor) {
    _actorSearchDebounce?.cancel();
    _actorSearchGeneration++;
    setState(() {
      _actorController.value = TextEditingValue(
        text: actor.name,
        selection: TextSelection.collapsed(offset: actor.name.length),
      );
      _selectedActorId = actor.id;
      _actorSuggestions = const [];
      _actorSearchError = null;
      _isSearchingActors = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _actorSearchDebounce?.cancel();
    _actorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _apply() {
    final yearText = _yearController.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);
    if (yearText.isNotEmpty && (year == null || year < 1888 || year > 2100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid release year.')),
      );
      return;
    }

    Navigator.of(context).pop(
      ExploreMovieFilters(
        genre: _genre,
        actor: _actorController.text.trim().isEmpty
            ? null
            : _actorController.text.trim(),
        actorId: _selectedActorId,
        year: year,
        minRating: _minRating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find your kind of movie',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fine-tune the trending picks.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('GENRE', style: _sectionLabel(context)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: _genres.map((genre) {
                final selected = _genre == genre;
                return ChoiceChip(
                  label: Text(genre),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _genre = selected ? null : genre),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('ACTOR OR ACTRESS', style: _sectionLabel(context)),
            const SizedBox(height: 9),
            TextField(
              controller: _actorController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Start typing an actor name',
                prefixIcon: const Icon(Icons.person_search_rounded),
                suffixIcon: _isSearchingActors
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _actorController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear actor',
                        onPressed: () {
                          _actorController.clear();
                          _searchActors('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: _searchActors,
            ),
            if (_selectedActorId != null) ...[
              const SizedBox(height: 8),
              _SelectedActorChip(
                name: _actorController.text,
                onRemove: () {
                  _actorController.clear();
                  _searchActors('');
                },
              ),
            ],
            if (_actorSearchError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Could not load actor suggestions. ${_actorSearchError!}',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            if (!_isSearchingActors &&
                _actorSearchError == null &&
                _actorController.text.trim().length >= 2 &&
                _actorSuggestions.isEmpty &&
                _selectedActorId == null) ...[
              const SizedBox(height: 8),
              Text('No actors found.', style: textTheme.bodySmall),
            ],
            if (_actorSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < _actorSuggestions.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 64,
                          color: colorScheme.outlineVariant,
                        ),
                      _ActorSuggestionTile(
                        actor: _actorSuggestions[index],
                        onTap: () => _selectActor(_actorSuggestions[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('RELEASE YEAR', style: _sectionLabel(context)),
            const SizedBox(height: 9),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Any year',
                prefixIcon: Icon(Icons.calendar_today_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('MINIMUM RATING', style: _sectionLabel(context)),
                ),
                Text(
                  _minRating == 0
                      ? 'Any rating'
                      : '${_minRating.toStringAsFixed(1)}+',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: _minRating,
              min: 0,
              max: 5,
              divisions: 10,
              label: _minRating == 0 ? 'Any' : _minRating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _minRating = value),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _genre = null;
                      _actorController.clear();
                      _yearController.clear();
                      _minRating = 0;
                    });
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Show movies'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _sectionLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      );
}

class _ActorSuggestionTile extends StatelessWidget {
  const _ActorSuggestionTile({required this.actor, required this.onTap});

  final MovieActorSuggestion actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profilePath = actor.profilePath;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
        foregroundImage: profilePath == null || profilePath.isEmpty
            ? null
            : CachedNetworkImageProvider(
                Uri.https(
                  'image.tmdb.org',
                  '/t/p/w185${profilePath.startsWith('/') ? profilePath : '/$profilePath'}',
                ).toString(),
              ),
        child: Icon(Icons.person_rounded, color: colorScheme.secondary),
      ),
      title: Text(actor.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: actor.knownForDepartment == null
          ? null
          : Text(actor.knownForDepartment!),
      trailing: const Icon(Icons.north_west_rounded, size: 18),
    );
  }
}

class _SelectedActorChip extends StatelessWidget {
  const _SelectedActorChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InputChip(
      avatar: const Icon(Icons.person_rounded, size: 18),
      label: Text(name),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      visualDensity: VisualDensity.compact,
    ),
  );
}
