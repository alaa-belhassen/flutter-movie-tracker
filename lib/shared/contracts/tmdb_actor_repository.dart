import 'movie_repository.dart';
import 'actor_repository.dart';
import 'api_client.dart';

class TmdbActorRepository implements ActorRepository {
  TmdbActorRepository(this._movies, this._apiClient);

  final MovieRepository _movies;
  final ApiClient _apiClient;
  final Map<String, Future<Actor?>> _actorCache = {};

  @override
  Future<List<Actor>> getActors() async =>
      (await _movies.getPopularActors()).map(_fromSuggestion).toList();

  @override
  Future<List<Actor>> searchActors(String query) async =>
      (await _movies.searchActors(query)).map(_fromSuggestion).toList();

  Actor _fromSuggestion(MovieActorSuggestion suggestion) => Actor(
    id: suggestion.id,
    name: suggestion.name,
    role: suggestion.knownForDepartment ?? 'Actor',
    birthplace: '',
    bio: '',
    photoUrl: _profileUrl(suggestion.profilePath),
    movieIds: const [],
  );

  String _profileUrl(String? path) => path == null || path.isEmpty
      ? ''
      : Uri.https('image.tmdb.org', '/t/p/w500$path').toString();

  Future<Actor?> _loadActor(String id) {
    return _actorCache.putIfAbsent(id, () async {
      try {
        final person = await _movies.getPersonById(id);
        if (person == null) return null;
        return Actor(
          id: person.id,
          name: person.name,
          role: person.knownForDepartment ?? 'Actor',
          birthplace: person.placeOfBirth,
          bio: person.biography,
          photoUrl: _profileUrl(person.profilePath),
          movieIds: const [],
        );
      } catch (_) {
        _actorCache.remove(id);
        rethrow;
      }
    });
  }

  @override
  Future<Actor?> getActorById(String id) => _loadActor(id);

  @override
  Future<List<String>> getFollowedActorIds(String userId) async {
    final response = await _apiClient.request('GET', 'users/me/actors');
    final actorIds = response['actorIds'];
    if (actorIds is! List) {
      throw const FormatException('The API returned invalid followed actors.');
    }
    return actorIds.whereType<String>().toList(growable: false);
  }

  @override
  Future<List<Actor>> getFollowedActors(String userId) async {
    final ids = await getFollowedActorIds(userId);
    final actors = await Future.wait(ids.map(_loadActor));
    return actors.whereType<Actor>().toList(growable: false);
  }

  @override
  Future<void> toggleFollowActor(String userId, String actorId) async {
    final followedIds = await getFollowedActorIds(userId);
    final isFollowing = followedIds.contains(actorId);
    await _apiClient.request(
      isFollowing ? 'DELETE' : 'PUT',
      'users/me/actors/${Uri.encodeComponent(actorId)}',
    );
  }

  @override
  Future<List<Movie>> getActorFilmography(String actorId) =>
      _movies.getActorMovies(actorId);
}
