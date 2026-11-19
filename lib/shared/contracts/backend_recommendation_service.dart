import 'actor_repository.dart';
import 'api_client.dart';
import 'movie_repository.dart';
import 'recommendation_service.dart';
import 'review_service.dart';
import 'watchlist_service.dart';

class BackendRecommendationService implements RecommendationService {
  BackendRecommendationService({
    required this.movies,
    required this.actors,
    required this.watchlists,
    required this.reviewService,
    required this.apiClient,
  });

  final MovieRepository movies;
  final ActorRepository actors;
  final WatchlistService watchlists;
  final ReviewService reviewService;
  final ApiClient apiClient;

  @override
  Future<List<RecommendedMovie>> getRecommendations(String userId) async {
    final followedFuture = actors.getFollowedActors(userId);
    final favoritesFuture = watchlists.getFavorites(userId);
    final watchlistFuture = watchlists.getWatchlist(userId);
    final reviewsFuture = reviewService.getUserReviews(userId);
    final viewingsFuture = reviewService.getViewingEntries(userId);
    final exclusionsFuture = _getExcludedMovieIds();

    final followedActors = await followedFuture;
    final favorites = await favoritesFuture;
    final watchlist = await watchlistFuture;
    final reviews = await reviewsFuture;
    final viewings = await viewingsFuture;
    final excludedIds = await exclusionsFuture;

    final tasteMovieIds = <String>{
      ...favorites,
      for (final review in reviews)
        if (review.rating >= 3.5) review.movieId,
      for (final viewing in viewings)
        if ((viewing.rating ?? 0) >= 4) viewing.movieId,
    }.toList(growable: false);
    final tasteMovieFutures = tasteMovieIds.take(12).map(movies.getMovieById);
    final tasteMovies = (await Future.wait(tasteMovieFutures))
        .whereType<Movie>()
        .toList(growable: false);

    final genreCounts = <String, int>{};
    for (final movie in tasteMovies) {
      for (final genre in movie.genre.split(',').map((value) => value.trim())) {
        if (genre.isNotEmpty && genre != 'Movie') {
          genreCounts.update(genre, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    final topGenres = genreCounts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    final filmographyFutures = followedActors
        .take(10)
        .map((actor) => actors.getActorFilmography(actor.id));
    final filmographies = await Future.wait(filmographyFutures);
    final actorMovieMatches = <String, Set<String>>{};
    final candidates = <String, Movie>{};
    for (var index = 0; index < filmographies.length; index++) {
      final actor = followedActors[index];
      for (final movie in filmographies[index]) {
        candidates[movie.id] = movie;
        actorMovieMatches.putIfAbsent(movie.id, () => {}).add(actor.name);
      }
    }

    for (final genre in topGenres.take(2)) {
      final genreMovies = await movies.getMoviesByGenre(genre.key);
      for (final movie in genreMovies) {
        candidates.putIfAbsent(movie.id, () => movie);
      }
    }
    for (final movie in await movies.getTrendingMovies()) {
      candidates.putIfAbsent(movie.id, () => movie);
    }

    final alreadySaved = {
      ...favorites,
      ...watchlist,
      ...viewings.map((item) => item.movieId),
      ...reviews.map((review) => review.movieId),
    };
    final results = <RecommendedMovie>[];
    for (final movie in candidates.values) {
      if (alreadySaved.contains(movie.id) || excludedIds.contains(movie.id)) {
        continue;
      }
      final matchedActors = actorMovieMatches[movie.id] ?? const <String>{};
      final matchingGenres = topGenres
          .where(
            (genre) =>
                movie.genre.toLowerCase().contains(genre.key.toLowerCase()),
          )
          .length;
      final matchScore = matchedActors.isNotEmpty
          ? (82 + matchedActors.length * 5 + movie.rating.round()).clamp(0, 99)
          : matchingGenres > 0
          ? (65 + matchingGenres * 8 + movie.rating.round()).clamp(0, 90)
          : (50 + movie.rating.round()).clamp(0, 75);
      final reason = matchedActors.isNotEmpty
          ? 'Featuring ${matchedActors.take(2).join(' and ')}'
          : matchingGenres > 0
          ? 'Based on your favorite genres'
          : 'Popular this week';
      results.add(
        RecommendedMovie(movie: movie, matchScore: matchScore, reason: reason),
      );
    }
    results.sort((left, right) => right.matchScore.compareTo(left.matchScore));
    return results.take(30).toList(growable: false);
  }

  Future<Set<String>> _getExcludedMovieIds() async {
    final response = await apiClient.request(
      'GET',
      'users/me/recommendation-exclusions',
    );
    final movieIds = response['movieIds'];
    if (movieIds is! List) {
      throw const FormatException(
        'The API returned invalid recommendation exclusions.',
      );
    }
    return movieIds.whereType<String>().toSet();
  }

  @override
  Future<void> excludeRecommendation(String userId, String movieId) async {
    await apiClient.request(
      'PUT',
      'users/me/recommendation-exclusions/${Uri.encodeComponent(movieId)}',
    );
  }
}
