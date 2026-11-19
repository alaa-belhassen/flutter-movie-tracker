class Movie {
  final String id;
  final String title;
  final int year;
  final String genre;
  final String duration;
  final double rating;
  final String synopsis;
  final String? posterPath;
  final String? backdropPath;
  final List<String> castIds;
  final List<String> streamingProviders;
  final bool isTrending;
  final bool isFeatured;

  const Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.genre,
    required this.duration,
    required this.rating,
    required this.synopsis,
    this.posterPath,
    this.backdropPath,
    required this.castIds,
    required this.streamingProviders,
    this.isTrending = false,
    this.isFeatured = false,
  });
}

class SearchHistoryItem {
  final String id;
  final String query;
  final DateTime timestamp;

  const SearchHistoryItem({
    required this.id,
    required this.query,
    required this.timestamp,
  });
}

class MovieActorSuggestion {
  const MovieActorSuggestion({
    required this.id,
    required this.name,
    this.profilePath,
    this.knownForDepartment,
  });

  final String id;
  final String name;
  final String? profilePath;
  final String? knownForDepartment;
}

class MoviePerson {
  const MoviePerson({
    required this.id,
    required this.name,
    this.knownForDepartment,
    this.biography = '',
    this.placeOfBirth = '',
    this.profilePath,
  });

  final String id;
  final String name;
  final String? knownForDepartment;
  final String biography;
  final String placeOfBirth;
  final String? profilePath;
}

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  final String id;
  final String name;
  final String character;
  final String? profilePath;
}

abstract class MovieRepository {
  Future<List<Movie>> getMovies({int? maxRuntimeMinutes});
  Future<List<MovieActorSuggestion>> searchActors(String query);
  Future<List<MovieActorSuggestion>> getPopularActors();
  Future<MoviePerson?> getPersonById(String id);
  Future<List<Movie>> getActorMovies(String actorId);
  Future<List<CastMember>> getMovieCast(String movieId);
  Future<List<Movie>> discoverMovies({
    String? genre,
    String? actor,
    String? actorId,
    double? minRating,
    int? year,
  });
  Future<Movie?> getMovieById(String id);
  Future<List<Movie>> searchMovies(
    String query, {
    String? genre,
    int? year,
    double? minRating,
  });
  Future<List<Movie>> getTrendingMovies();
  Future<List<Movie>> getFeaturedMovies();
  Future<List<Movie>> getMoviesByGenre(String genre);
  Future<List<SearchHistoryItem>> getSearchHistory();
  Future<void> addSearchHistory(String query);
  Future<void> deleteSearchHistory(String id);
  Future<void> clearSearchHistory();
  Future<List<String>> getStreamingProviders(String country);
}
