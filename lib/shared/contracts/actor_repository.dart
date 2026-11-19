import 'movie_repository.dart';

class Actor {
  final String id;
  final String name;
  final String role;
  final String birthplace;
  final String bio;
  final String photoUrl;
  final List<String> movieIds;
  final bool isFollowing;

  const Actor({
    required this.id,
    required this.name,
    required this.role,
    required this.birthplace,
    required this.bio,
    this.photoUrl = '',
    required this.movieIds,
    this.isFollowing = false,
  });
}

abstract class ActorRepository {
  Future<List<Actor>> getActors();
  Future<List<Actor>> searchActors(String query);
  Future<Actor?> getActorById(String id);
  Future<List<String>> getFollowedActorIds(String userId);
  Future<List<Actor>> getFollowedActors(String userId);
  Future<void> toggleFollowActor(String userId, String actorId);
  Future<List<Movie>> getActorFilmography(String actorId);
}
