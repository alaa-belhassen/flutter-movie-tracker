import 'dart:convert';

import 'package:http/http.dart' as http;

import 'movie_repository.dart';

class TmdbMovieRepository implements MovieRepository {
  TmdbMovieRepository({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;
  final List<SearchHistoryItem> _searchHistory = [];
  final Map<String, Future<Movie?>> _movieDetails = {};
  final Map<String, Future<MoviePerson?>> _people = {};
  final Map<String, Future<List<CastMember>>> _movieCasts = {};

  static const _baseUrl = 'https://api.themoviedb.org/3';
  static const _genreNames = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };
  static const _genreAliases = <String, int>{
    'sci-fi': 878,
    'science fiction': 878,
  };

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> parameters = const {},
  ]) async {
    if (apiKey.isEmpty) {
      throw const TmdbApiException(
        'TMDB_API_KEY is missing. Add it to assets/.env and restart the app.',
      );
    }
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'api_key': apiKey, 'language': 'en-US', ...parameters},
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TmdbApiException(
        'TMDB request failed (${response.statusCode}). Check your API key and connection.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected TMDB response format.');
    }
    return decoded;
  }

  List<Movie> _moviesFrom(Map<String, dynamic> response) {
    final results = response['results'];
    if (results is! List) {
      throw const FormatException('TMDB response has no movie results.');
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(_movieFromJson)
        .toList();
  }

  Movie _movieFromJson(Map<String, dynamic> json) {
    final genreIds =
        (json['genre_ids'] as List<dynamic>?) ??
        ((json['genres'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((genre) => genre['id'])
                .toList() ??
            const []);
    final genreNames = genreIds
        .whereType<num>()
        .map((id) => _genreNames[id.toInt()])
        .whereType<String>()
        .toList();
    final releaseDate = json['release_date'] as String? ?? '';
    final rating = (json['vote_average'] as num?)?.toDouble() ?? 0;
    final runtime = (json['runtime'] as num?)?.toInt();
    final title = json['title'] as String? ?? 'Untitled';

    return Movie(
      id: '${json['id']}',
      title: title,
      year: releaseDate.length >= 4
          ? int.tryParse(releaseDate.substring(0, 4)) ?? 0
          : 0,
      genre: genreNames.isEmpty ? 'Movie' : genreNames.join(', '),
      duration: runtime == null
          ? 'Runtime unavailable'
          : '${runtime ~/ 60}h ${runtime % 60}m',
      rating: (rating / 2).clamp(0, 5).toDouble(),
      synopsis: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      castIds: const [],
      streamingProviders: const [],
      isTrending: false,
      isFeatured: false,
    );
  }

  @override
  Future<List<Movie>> getMovies({int? maxRuntimeMinutes}) async {
    if (maxRuntimeMinutes != null) {
      return _moviesFrom(
        await _get('/discover/movie', {
          'with_runtime.lte': '$maxRuntimeMinutes',
          'sort_by': 'popularity.desc',
        }),
      );
    }
    return _moviesFrom(await _get('/movie/popular'));
  }

  @override
  Future<List<MovieActorSuggestion>> searchActors(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return const [];

    final response = await _get('/search/person', {'query': trimmedQuery});
    final results = response['results'];
    if (results is! List) {
      throw const FormatException('TMDB response has no people results.');
    }

    return results
        .whereType<Map<String, dynamic>>()
        .where((person) => person['id'] is num && person['name'] is String)
        .take(8)
        .map(
          (person) => MovieActorSuggestion(
            id: '${person['id']}',
            name: person['name'] as String,
            profilePath: person['profile_path'] as String?,
            knownForDepartment: person['known_for_department'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MovieActorSuggestion>> getPopularActors() async {
    final response = await _get('/person/popular');
    final results = response['results'];
    if (results is! List) {
      throw const FormatException('TMDB response has no popular people.');
    }
    return results
        .whereType<Map<String, dynamic>>()
        .where((person) => person['id'] is num && person['name'] is String)
        .take(20)
        .map(
          (person) => MovieActorSuggestion(
            id: '${person['id']}',
            name: person['name'] as String,
            profilePath: person['profile_path'] as String?,
            knownForDepartment: person['known_for_department'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MoviePerson?> getPersonById(String id) {
    final personId = int.tryParse(id);
    if (personId == null) return Future.value(null);
    return _people.putIfAbsent(id, () async {
      try {
        final response = await _get('/person/$personId');
        return MoviePerson(
          id: '$personId',
          name: response['name'] as String? ?? 'Unknown actor',
          knownForDepartment: response['known_for_department'] as String?,
          biography: response['biography'] as String? ?? '',
          placeOfBirth: response['place_of_birth'] as String? ?? '',
          profilePath: response['profile_path'] as String?,
        );
      } catch (_) {
        _people.remove(id);
        rethrow;
      }
    });
  }

  @override
  Future<List<Movie>> getActorMovies(String actorId) async {
    final personId = int.tryParse(actorId);
    if (personId == null) return const [];
    final response = await _get('/person/$personId/movie_credits');
    final cast = response['cast'];
    if (cast is! List) {
      throw const FormatException('TMDB response has no actor filmography.');
    }
    final movies = cast.whereType<Map<String, dynamic>>().toList()
      ..sort((left, right) {
        final leftPopularity = (left['popularity'] as num?)?.toDouble() ?? 0;
        final rightPopularity = (right['popularity'] as num?)?.toDouble() ?? 0;
        return rightPopularity.compareTo(leftPopularity);
      });
    return movies.map(_movieFromJson).toList(growable: false);
  }

  @override
  Future<List<CastMember>> getMovieCast(String movieId) {
    final id = int.tryParse(movieId);
    if (id == null) return Future.value(const []);
    return _movieCasts.putIfAbsent(movieId, () async {
      try {
        final response = await _get('/movie/$id/credits');
        final cast = response['cast'];
        if (cast is! List) {
          throw const FormatException('TMDB response has no movie cast.');
        }
        return cast
            .whereType<Map<String, dynamic>>()
            .where((person) => person['id'] is num && person['name'] is String)
            .take(20)
            .map(
              (person) => CastMember(
                id: '${person['id']}',
                name: person['name'] as String,
                character: person['character'] as String? ?? '',
                profilePath: person['profile_path'] as String?,
              ),
            )
            .toList(growable: false);
      } catch (_) {
        _movieCasts.remove(movieId);
        rethrow;
      }
    });
  }

  @override
  Future<List<Movie>> discoverMovies({
    String? genre,
    String? actor,
    String? actorId,
    double? minRating,
    int? year,
  }) async {
    final parameters = <String, String>{'sort_by': 'popularity.desc'};
    if (genre != null && genre.isNotEmpty) {
      final genreId = _genreIdFor(genre);
      if (genreId == null) return const [];
      parameters['with_genres'] = '$genreId';
    }
    if (actorId != null && actorId.isNotEmpty) {
      parameters['with_cast'] = actorId;
    } else if (actor != null && actor.trim().isNotEmpty) {
      final response = await _get('/search/person', {'query': actor.trim()});
      final results = response['results'];
      final firstPerson = results is List && results.isNotEmpty
          ? results.first
          : null;
      if (firstPerson is! Map<String, dynamic> || firstPerson['id'] == null) {
        return const [];
      }
      parameters['with_cast'] = firstPerson['id'].toString();
    }
    if (minRating != null && minRating > 0) {
      parameters['vote_average.gte'] = '${(minRating * 2).toStringAsFixed(1)}';
    }
    if (year != null) {
      parameters['primary_release_year'] = '$year';
    }
    return _moviesFrom(await _get('/discover/movie', parameters));
  }

  @override
  Future<Movie?> getMovieById(String id) {
    final movieId = int.tryParse(id);
    if (movieId == null) return Future.value(null);
    return _movieDetails.putIfAbsent(id, () async {
      try {
        return _movieFromJson(await _get('/movie/$movieId'));
      } catch (_) {
        _movieDetails.remove(id);
        rethrow;
      }
    });
  }

  @override
  Future<List<Movie>> searchMovies(
    String query, {
    String? genre,
    int? year,
    double? minRating,
  }) async {
    final response = await _get('/search/movie', {
      'query': query,
      if (year != null) 'year': '$year',
    });
    return _moviesFrom(response).where((movie) {
      final matchesGenre =
          genre == null ||
          genre.isEmpty ||
          movie.genre.toLowerCase().contains(genre.toLowerCase());
      final matchesRating = minRating == null || movie.rating >= minRating;
      return matchesGenre && matchesRating;
    }).toList();
  }

  @override
  Future<List<Movie>> getTrendingMovies() async =>
      _moviesFrom(await _get('/trending/movie/week'));

  @override
  Future<List<Movie>> getFeaturedMovies() async =>
      _moviesFrom(await _get('/movie/now_playing'));

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) async {
    final genreId = _genreIdFor(genre);
    if (genreId == null) return const [];
    return _moviesFrom(
      await _get('/discover/movie', {'with_genres': '$genreId'}),
    );
  }

  int? _genreIdFor(String genre) =>
      int.tryParse(genre) ??
      _genreAliases[genre.toLowerCase()] ??
      _genreNames.entries
          .where((entry) => entry.value.toLowerCase() == genre.toLowerCase())
          .map((entry) => entry.key)
          .firstOrNull;

  @override
  Future<List<SearchHistoryItem>> getSearchHistory() async =>
      List.unmodifiable(_searchHistory);

  @override
  Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    _searchHistory.insert(
      0,
      SearchHistoryItem(
        id: 'tmdb_${DateTime.now().microsecondsSinceEpoch}',
        query: query.trim(),
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteSearchHistory(String id) async {
    _searchHistory.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
  }

  @override
  Future<List<String>> getStreamingProviders(String country) async {
    final response = await _get('/watch/providers/movie', {
      'watch_region': country,
    });
    final results = response['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((provider) => provider['provider_name'])
        .whereType<String>()
        .toList();
  }

  void close() => _client.close();
}

class TmdbApiException implements Exception {
  const TmdbApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
