import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/review_service.dart';

class YearRecapPage extends ConsumerStatefulWidget {
  const YearRecapPage({super.key, required this.year});

  final String year;

  @override
  ConsumerState<YearRecapPage> createState() => _YearRecapPageState();
}

class _YearRecapPageState extends ConsumerState<YearRecapPage> {
  late final PageController _pageController;
  late Future<_YearRecapData> _recap;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _recap = _loadRecap();
  }

  Future<_YearRecapData> _loadRecap() async {
    final year = int.tryParse(widget.year);
    if (year == null || year < 1900 || year > 2200) {
      throw FormatException('Invalid recap year: ${widget.year}');
    }
    final user = ref.read(currentUserProvider);
    if (user == null) throw StateError('Sign in to view your yearly recap.');
    final entries = await ref
        .read(reviewServiceProvider)
        .getViewingEntries(user.id);
    final yearEntries = entries
        .where((entry) => entry.watchedAt.year == year)
        .toList(growable: false);
    final ratedEntries = yearEntries
        .where((entry) => entry.rating != null)
        .toList(growable: false);
    ViewingEntry? topEntry;
    for (final entry in ratedEntries) {
      if (topEntry == null || entry.rating! > topEntry.rating!) {
        topEntry = entry;
      }
    }
    final topMovie = topEntry == null
        ? null
        : await ref
              .read(movieRepositoryProvider)
              .getMovieById(topEntry.movieId);
    final averageRating = ratedEntries.isEmpty
        ? 0.0
        : ratedEntries.map((entry) => entry.rating!).reduce((a, b) => a + b) /
              ratedEntries.length;
    return _YearRecapData(
      year: year,
      uniqueMovies: yearEntries.map((entry) => entry.movieId).toSet().length,
      viewingCount: yearEntries.length,
      averageRating: averageRating,
      ratedCount: ratedEntries.length,
      topMovieTitle:
          topMovie?.title ??
          (topEntry == null ? null : 'Movie #${topEntry.movieId}'),
      topRating: topEntry?.rating,
      favoriteGenres: user.favoriteGenres,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.58),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_YearRecapData>(
            future: _recap,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 44),
                              const SizedBox(height: 12),
                              const Text(
                                'Could not load your recap.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() => _recap = _loadRecap());
                                },
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final recap = snapshot.data!;
              final slides = _buildSlides(context, recap);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (_currentPage + 1) / slides.length,
                              color: colorScheme.secondary,
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      children: slides,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _currentPage == 0
                              ? null
                              : () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOut,
                                ),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                        const Spacer(),
                        if (_currentPage < slides.length - 1)
                          FilledButton.icon(
                            onPressed: () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlides(BuildContext context, _YearRecapData recap) => [
    _buildSlide(
      context,
      'Your ${recap.year} cinema journey',
      recap.uniqueMovies == 0
          ? 'No movies logged this year yet.'
          : '${recap.uniqueMovies} unique ${recap.uniqueMovies == 1 ? 'movie' : 'movies'} watched',
      Icons.movie_rounded,
    ),
    _buildSlide(
      context,
      'Every screening counts',
      '${recap.viewingCount} ${recap.viewingCount == 1 ? 'viewing' : 'viewings'} logged in your journal',
      Icons.local_movies_outlined,
    ),
    _buildSlide(
      context,
      'Your rating mood',
      recap.ratedCount == 0
          ? 'Add ratings to see your yearly average.'
          : 'Average ${recap.averageRating.toStringAsFixed(1)} / 5 from ${recap.ratedCount} ratings',
      Icons.star_rounded,
    ),
    _buildSlide(
      context,
      'Your highest-rated movie',
      recap.topMovieTitle == null
          ? 'No rated viewings logged this year.'
          : '${recap.topMovieTitle} · ${recap.topRating!.toStringAsFixed(1)} / 5',
      Icons.auto_awesome_rounded,
    ),
    _buildSlide(
      context,
      'Your movie taste',
      recap.favoriteGenres.isEmpty
          ? 'Choose favorite genres in your profile to personalize your picks.'
          : recap.favoriteGenres.join(' · '),
      Icons.local_movies_outlined,
    ),
    _buildShareSlide(context, recap),
  ];

  Widget _buildSlide(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: colorScheme.secondary),
          const SizedBox(height: 32),
          Text(
            title,
            style: textTheme.headlineLarge?.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShareSlide(BuildContext context, _YearRecapData recap) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ios_share_rounded, size: 72),
          const SizedBox(height: 28),
          Text(
            'Ready to share your ${recap.year} recap?',
            style: textTheme.headlineLarge?.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '${recap.uniqueMovies} movies · ${recap.viewingCount} viewings'
            '${recap.ratedCount > 0 ? ' · ${recap.averageRating.toStringAsFixed(1)} average rating' : ''}',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Share.share(
              'My ${recap.year} Movie Tracker recap: ${recap.uniqueMovies} movies watched across ${recap.viewingCount} viewings!',
            ),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share my recap'),
          ),
        ],
      ),
    );
  }
}

class _YearRecapData {
  const _YearRecapData({
    required this.year,
    required this.uniqueMovies,
    required this.viewingCount,
    required this.averageRating,
    required this.ratedCount,
    required this.topMovieTitle,
    required this.topRating,
    required this.favoriteGenres,
  });

  final int year;
  final int uniqueMovies;
  final int viewingCount;
  final double averageRating;
  final int ratedCount;
  final String? topMovieTitle;
  final double? topRating;
  final List<String> favoriteGenres;
}
