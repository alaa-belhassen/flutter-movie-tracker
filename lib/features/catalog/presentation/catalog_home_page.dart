import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../core/widgets/movie_poster_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/attribution_footer.dart';
import '../../../core/widgets/avatar_circle.dart';

class CatalogHomePage extends ConsumerWidget {
  const CatalogHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final movieRepo = ref.watch(movieRepositoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Semantics(
          label: 'Welcome back, ${user?.nickname ?? 'Guest'}',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.secondary, width: 1.5),
                ),
                child: AvatarCircle(
                  name: user?.nickname ?? 'Guest',
                  radius: 19,
                ),
              ),
              const SizedBox(width: 11),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WELCOME BACK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      user?.nickname ?? 'Guest',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 14),
        actions: [
          _TopBarAction(
            icon: Icons.search_rounded,
            tooltip: 'Search movies',
            onPressed: () => context.push('/discover/search'),
          ),
          const SizedBox(width: 8),
          _TopBarAction(
            icon: Icons.history_rounded,
            tooltip: 'Search history',
            onPressed: () => context.push('/discover/history'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait<dynamic>([
          movieRepo.getFeaturedMovies(),
          movieRepo.getTrendingMovies(),
          movieRepo.getMovies(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 40,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load movies right now.',
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.error is Exception
                          ? snapshot.error.toString()
                          : 'Please check your connection and try again.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.length != 3) {
            return const Center(child: Text('No movies to show yet.'));
          }

          final featured = snapshot.data![0] as List<Movie>;
          final trending = snapshot.data![1] as List<Movie>;
          final popularMovies = snapshot.data![2] as List<Movie>;

          final spotlightMovies = featured.isNotEmpty ? featured : trending;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (spotlightMovies.isNotEmpty) ...[
                    _SpotlightCarousel(
                      movies: spotlightMovies,
                      onMovieTap: (movie) => context.push('/movie/${movie.id}'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _buildShortcut(
                          context,
                          Icons.auto_awesome,
                          'Popular',
                          () => context.push('/people/for-you'),
                        ),
                      ),
                      Expanded(
                        child: _buildShortcut(
                          context,
                          Icons.nightlight_outlined,
                          'Tonight',
                          () => context.push('/lists/tonight'),
                        ),
                      ),
                      Expanded(
                        child: _buildShortcut(
                          context,
                          Icons.people_outline,
                          'Actors',
                          () => context.push('/people'),
                        ),
                      ),
                      Expanded(
                        child: _buildShortcut(
                          context,
                          Icons.bookmark_border_rounded,
                          'Watchlist',
                          () => context.go('/lists'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Trending now',
                    actionText: 'See all',
                    onActionTap: () => context.push('/discover/all'),
                  ),
                  const SizedBox(height: 4),
                  const _SwipeHint(),
                  const SizedBox(height: 10),
                  _MovieCarousel(
                    movies: trending,
                    storageKey: 'trending-movies',
                    onMovieTap: (movie) => context.push('/movie/${movie.id}'),
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Popular picks for you',
                    actionText: 'See all',
                    onActionTap: () => context.push('/people/for-you'),
                  ),
                  const SizedBox(height: 4),
                  const _SwipeHint(),
                  const SizedBox(height: 10),
                  _MovieCarousel(
                    movies: popularMovies,
                    storageKey: 'popular-movies',
                    onMovieTap: (movie) => context.push('/movie/${movie.id}'),
                  ),
                  const SizedBox(height: 32),
                  const AttributionFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShortcut(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Icon(icon, color: colorScheme.secondary, size: 23),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 21, color: colorScheme.secondary),
          ),
        ),
      ),
    );
  }
}

class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel({required this.movies, required this.onMovieTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: 0.94,
  );
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        SizedBox(
          height: 322,
          child: PageView.builder(
            key: const PageStorageKey('spotlight-movies'),
            controller: _controller,
            itemCount: widget.movies.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final movie = widget.movies[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => widget.onMovieTap(movie),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _SpotlightBackdrop(movie: movie),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.28),
                                Colors.black.withValues(alpha: 0.92),
                              ],
                              stops: const [0, 0.36, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _SpotlightBadge(
                            icon: Icons.auto_awesome_rounded,
                            label: 'IN THE SPOTLIGHT',
                          ),
                        ),
                        if (movie.rating > 0)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: _SpotlightBadge(
                              icon: Icons.star_rounded,
                              label: movie.rating.toStringAsFixed(1),
                            ),
                          ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 25,
                                  height: 1.12,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                [
                                  if (movie.year > 0) '${movie.year}',
                                  movie.genre,
                                ].join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (movie.synopsis.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  movie.synopsis,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: colorScheme.primary,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                onPressed: () => widget.onMovieTap(movie),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 21,
                                ),
                                label: const Text('Discover movie'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.movies.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.movies.length, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: isSelected ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _SpotlightBackdrop extends StatelessWidget {
  const _SpotlightBackdrop({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = movie.backdropPath;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.72),
            scheme.secondary.withValues(alpha: 0.68),
            scheme.surface,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 100,
          color: Colors.white24,
        ),
      ),
    );

    if (path == null || path.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: Uri.https(
        'image.tmdb.org',
        '/t/p/w1280${path.startsWith('/') ? path : '/$path'}',
      ).toString(),
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 350),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

class _SpotlightBadge extends StatelessWidget {
  const _SpotlightBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.swipe_rounded,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text('Swipe to explore', style: style),
        const SizedBox(width: 3),
        Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _MovieCarousel extends StatelessWidget {
  const _MovieCarousel({
    required this.movies,
    required this.storageKey,
    required this.onMovieTap,
  });

  final List<Movie> movies;
  final String storageKey;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: ListView.separated(
      key: PageStorageKey(storageKey),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 20, bottom: 4),
      itemCount: movies.length,
      separatorBuilder: (context, index) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final movie = movies[index];
        final duration = Duration(milliseconds: 300 + (index.clamp(0, 6) * 55));
        return TweenAnimationBuilder<double>(
          key: ValueKey(movie.id),
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          ),
          child: MoviePosterCard(
            title: movie.title,
            rating: movie.rating,
            posterPath: movie.posterPath,
            width: 148,
            onTap: () => onMovieTap(movie),
          ),
        );
      },
    ),
  );
}
