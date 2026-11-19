import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';
import 'package:movietracker/shared/contracts/tmdb_movie_repository.dart';

void main() {
  test('the app movie provider never falls back to sample movies', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(movieRepositoryProvider), isA<TmdbMovieRepository>());
  });

  test('maps TMDB movie data and image paths into the app model', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.host, 'api.themoviedb.org');
        expect(request.url.queryParameters['api_key'], 'test-key');
        expect(request.url.path, '/3/trending/movie/week');
        return http.Response('''
          {
            "results": [{
              "id": 603,
              "title": "The Matrix",
              "release_date": "1999-03-31",
              "vote_average": 8.7,
              "overview": "A computer hacker learns the truth.",
              "poster_path": "/matrix-poster.jpg",
              "backdrop_path": "/matrix-backdrop.jpg",
              "genre_ids": [28, 878]
            }]
          }
          ''', 200);
      }),
    );

    final movies = await repository.getTrendingMovies();
    expect(movies, hasLength(1));
    expect(movies.single.id, '603');
    expect(movies.single.year, 1999);
    expect(movies.single.rating, 4.35);
    expect(movies.single.posterPath, '/matrix-poster.jpg');
    expect(movies.single.backdropPath, '/matrix-backdrop.jpg');
    expect(movies.single.genre, 'Action, Science Fiction');
    repository.close();
  });

  test('reuses movie details when opening a favorite list', () async {
    var requestCount = 0;
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestCount++;
        expect(request.url.path, '/3/movie/603');
        return http.Response('''
          {
            "id": 603,
            "title": "The Matrix",
            "release_date": "1999-03-31",
            "vote_average": 8.7,
            "runtime": 136,
            "overview": "A computer hacker learns the truth.",
            "poster_path": "/matrix-poster.jpg",
            "genre_ids": [28, 878]
          }
          ''', 200);
      }),
    );

    final first = await repository.getMovieById('603');
    final second = await repository.getMovieById('603');

    expect(first?.title, 'The Matrix');
    expect(second?.title, 'The Matrix');
    expect(requestCount, 1);
    repository.close();
  });

  test('reports TMDB HTTP failures instead of returning empty data', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('Invalid API key', 401)),
    );

    await expectLater(
      repository.getTrendingMovies(),
      throwsA(isA<TmdbApiException>()),
    );
    repository.close();
  });

  test('requests movies filtered by the selected runtime', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/3/discover/movie');
        expect(request.url.queryParameters['with_runtime.lte'], '150');
        expect(request.url.queryParameters['sort_by'], 'popularity.desc');
        return http.Response('{"results": []}', 200);
      }),
    );

    expect(await repository.getMovies(maxRuntimeMinutes: 150), isEmpty);
    repository.close();
  });

  test(
    'discovers movies using genre, release year, and minimum rating',
    () async {
      final repository = TmdbMovieRepository(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.url.path, '/3/discover/movie');
          expect(request.url.queryParameters['with_genres'], '28');
          expect(request.url.queryParameters['primary_release_year'], '2024');
          expect(request.url.queryParameters['vote_average.gte'], '8.0');
          expect(request.url.queryParameters['sort_by'], 'popularity.desc');
          return http.Response('{"results": []}', 200);
        }),
      );

      expect(
        await repository.discoverMovies(
          genre: 'Action',
          year: 2024,
          minRating: 4,
        ),
        isEmpty,
      );
      repository.close();
    },
  );

  test('resolves actor names before discovering their movies', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        if (request.url.path == '/3/search/person') {
          expect(request.url.queryParameters['query'], 'Zendaya');
          return http.Response('{"results": [{"id": 12345}]}', 200);
        }
        expect(request.url.path, '/3/discover/movie');
        expect(request.url.queryParameters['with_cast'], '12345');
        return http.Response('{"results": []}', 200);
      }),
    );

    expect(await repository.discoverMovies(actor: 'Zendaya'), isEmpty);
    repository.close();
  });

  test('returns TMDB actor suggestions for autocomplete', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/3/search/person');
        expect(request.url.queryParameters['query'], 'Zendaya');
        return http.Response('''
          {
            "results": [{
              "id": 12345,
              "name": "Zendaya",
              "profile_path": "/zendaya.jpg",
              "known_for_department": "Acting"
            }]
          }
          ''', 200);
      }),
    );

    final actors = await repository.searchActors('  Zendaya  ');
    expect(actors, hasLength(1));
    expect(actors.single.id, '12345');
    expect(actors.single.name, 'Zendaya');
    expect(actors.single.profilePath, '/zendaya.jpg');
    expect(actors.single.knownForDepartment, 'Acting');
    repository.close();
  });

  test('loads popular people and actor profile details from TMDB', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        if (request.url.path == '/3/person/popular') {
          return http.Response('''
            {
              "results": [{
                "id": 42,
                "name": "Sample Actor",
                "profile_path": "/actor.jpg",
                "known_for_department": "Acting"
              }]
            }
            ''', 200);
        }
        expect(request.url.path, '/3/person/42');
        return http.Response('''
          {
            "id": 42,
            "name": "Sample Actor",
            "profile_path": "/actor.jpg",
            "known_for_department": "Acting",
            "biography": "An award-winning performer.",
            "place_of_birth": "Paris, France"
          }
          ''', 200);
      }),
    );

    final popular = await repository.getPopularActors();
    final actor = await repository.getPersonById('42');
    expect(popular.single.name, 'Sample Actor');
    expect(popular.single.profilePath, '/actor.jpg');
    expect(actor?.biography, 'An award-winning performer.');
    expect(actor?.placeOfBirth, 'Paris, France');
    repository.close();
  });

  test('loads movie cast and actor filmography from TMDB credits', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        if (request.url.path == '/3/movie/603/credits') {
          return http.Response('''
            {
              "cast": [{
                "id": 42,
                "name": "Sample Actor",
                "character": "The One",
                "profile_path": "/actor.jpg"
              }]
            }
            ''', 200);
        }
        expect(request.url.path, '/3/person/42/movie_credits');
        return http.Response('''
          {
            "cast": [{
              "id": 603,
              "title": "The Matrix",
              "release_date": "1999-03-31",
              "vote_average": 8.7,
              "poster_path": "/matrix.jpg",
              "genre_ids": [28],
              "popularity": 42
            }]
          }
          ''', 200);
      }),
    );

    final cast = await repository.getMovieCast('603');
    final filmography = await repository.getActorMovies('42');
    expect(cast.single.name, 'Sample Actor');
    expect(cast.single.character, 'The One');
    expect(filmography.single.title, 'The Matrix');
    repository.close();
  });

  test('uses the selected actor id when filtering movies', () async {
    final repository = TmdbMovieRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/3/discover/movie');
        expect(request.url.queryParameters['with_cast'], '12345');
        return http.Response('{"results": []}', 200);
      }),
    );

    await repository.discoverMovies(actor: 'Zendaya', actorId: '12345');
    repository.close();
  });

  test(
    'does not make requests or return sample movies without an API key',
    () async {
      final repository = TmdbMovieRepository(
        apiKey: '',
        client: MockClient((_) async {
          fail('A request must not be sent without an API key.');
        }),
      );

      await expectLater(
        repository.getMovies(),
        throwsA(
          isA<TmdbApiException>().having(
            (error) => error.message,
            'message',
            contains('TMDB_API_KEY is missing'),
          ),
        ),
      );
      repository.close();
    },
  );
}
